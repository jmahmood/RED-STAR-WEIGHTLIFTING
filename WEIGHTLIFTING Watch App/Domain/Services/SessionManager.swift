//
//  SessionManager.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-28.
//

import Combine
import Foundation

enum SessionState {
    case idle
    case active(SessionContext)
    case error(Error)
}

struct SessionContext {
    let deck: [DeckItem]
    let sessionID: String
    let plan: PlanV03
    let day: PlanV03.Day
}

protocol SessionManaging {
    var sessionPublisher: AnyPublisher<SessionState, Never> { get }
    func loadInitialSession()
    func recordMutation(
        originalCode: String,
        newCode: String,
        scope: ExerciseSwitchScope,
        startSequence: Int,
        affectedSequences: [Int]
    )
    func save(set item: DeckItem, weight: Double, reps: Int, effort: DeckItem.Effort)
    func undoLast()
    func switchDay(to newDayLabel: String)
}

final class SessionManager: SessionManaging {
    private let fileSystem: FileSystem
    private let planRepository: PlanRepository
    private let deckBuilder: DeckBuilding
    private let walLog: WalLogging
    private let globalCsv: GlobalCsvWriting
    private let indexRepository: IndexRepositorying

    private let subject = CurrentValueSubject<SessionState, Never>(.idle)
    private let queue = DispatchQueue(label: "SessionManager.queue", qos: .userInitiated)

    private var activeSessionID: String?
    private var activePlan: PlanV03?
    private var activeDay: PlanV03.Day?
    private var baseDeck: [DeckItem] = []
    private var activeDeck: [DeckItem] = []
    private var activeMeta: SessionMeta?
    private var activeContext: SessionContext?

    private struct PendingSave {
        let sequence: UInt64
        var row: CsvRow
        let savedAt: Date
        let deadline: Date
    }

    private var pendingSaves: [UInt64: PendingSave] = [:]
    private var pendingOrder: [UInt64] = []
    private var timers: [UInt64: DispatchSourceTimer] = [:]

    init(
        fileSystem: FileSystem,
        planRepository: PlanRepository,
        deckBuilder: DeckBuilding,
        walLog: WalLogging,
        globalCsv: GlobalCsvWriting,
        indexRepository: IndexRepositorying
    ) {
        self.fileSystem = fileSystem
        self.planRepository = planRepository
        self.deckBuilder = deckBuilder
        self.walLog = walLog
        self.globalCsv = globalCsv
        self.indexRepository = indexRepository
    }

    var sessionPublisher: AnyPublisher<SessionState, Never> {
        subject.eraseToAnyPublisher()
    }

    func loadInitialSession() {
        queue.async {
            do {
                let plan = try self.planRepository.loadActivePlan()
                let sessionID = SessionManager.makeSessionID(date: Date())
                let existingMeta = self.loadMeta(sessionID: sessionID)

                guard let fallbackDayLabel = plan.scheduleOrder.first else {
                    self.subject.send(.error(SessionError.noPlanDay))
                    return
                }

                let resolvedDayLabel = existingMeta
                    .flatMap { meta in plan.day(named: meta.dayLabel)?.label }
                    ?? fallbackDayLabel

                guard let day = plan.day(named: resolvedDayLabel) else {
                    self.subject.send(.error(SessionError.noPlanDay))
                    return
                }

                let baseDeck = self.deckBuilder.buildDeck(for: day, plan: plan)
                let deckHash = SessionManager.computeDeckHash(for: baseDeck)

                var meta: SessionMeta
                if var persisted = existingMeta {
                    if persisted.deckHash != deckHash {
                        persisted.mutationMap.removeAll()
                        persisted.sequenceOverrides.removeAll()
                        persisted.deckHash = deckHash
                    } else {
                        persisted.deckHash = deckHash
                    }
                    persisted.sessionId = sessionID
                    persisted.planName = plan.planName
                    persisted.dayLabel = day.label
                    meta = persisted
                } else {
                    meta = SessionMeta(
                        sessionId: sessionID,
                        planName: plan.planName,
                        dayLabel: day.label,
                        deckHash: deckHash
                    )
                }

                self.baseDeck = baseDeck
                self.activePlan = plan
                self.activeDay = day
                self.activeSessionID = sessionID

                let mutatedDeck = self.mutateDeck(baseDeck, with: meta, plan: plan)
                self.activeDeck = mutatedDeck

                self.handlePendingEntries(meta: &meta, sessionID: sessionID)
                try self.saveMeta(meta, sessionID: sessionID)

                self.activeMeta = meta

                let context = SessionContext(deck: mutatedDeck, sessionID: sessionID, plan: plan, day: day)
                self.activeContext = context
                self.subject.send(.active(context))
            } catch {
                self.subject.send(.error(error))
            }
        }
    }

    func recordMutation(
        originalCode: String,
        newCode: String,
        scope: ExerciseSwitchScope,
        startSequence: Int,
        affectedSequences: [Int]
    ) {
        queue.async {
            guard var meta = self.activeMeta,
                  let plan = self.activePlan,
                  let day = self.activeDay,
                  let sessionID = self.activeSessionID else {
                return
            }

            switch scope {
            case .remaining:
                meta.mutationMap[originalCode] = SessionMeta.Mutation(newCode: newCode, startSequence: startSequence)
                meta.sequenceOverrides = meta.sequenceOverrides.filter { key, _ in key < startSequence }
            case .thisSet:
                for sequence in affectedSequences {
                    meta.sequenceOverrides[sequence] = SessionMeta.Override(newCode: newCode)
                }
            }

            self.activeMeta = meta
           self.activeDeck = self.mutateDeck(self.baseDeck, with: meta, plan: plan)
           self.activeContext = SessionContext(deck: self.activeDeck, sessionID: sessionID, plan: plan, day: day)

            do {
                try self.saveMeta(meta, sessionID: sessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to persist mutation meta \(error)")
                #endif
            }

            if let context = self.activeContext {
                self.subject.send(.active(context))
            }
        }
    }

    func save(set item: DeckItem, weight: Double, reps: Int, effort: DeckItem.Effort) {
        queue.async {
            guard var meta = self.activeMeta,
                  let plan = self.activePlan,
                  let sessionID = self.activeSessionID else {
                return
            }

            let sequence = meta.nextSequence
            meta.nextSequence += 1
            let savedAt = Date()
            let deadline = savedAt.addingTimeInterval(5)
            meta.lastSaveAt = savedAt
            meta.planName = plan.planName

            let row = self.buildRow(
                for: item,
                weight: weight,
                reps: reps,
                effort: effort,
                sequence: sequence,
                savedAt: savedAt,
                plan: plan,
                dayLabel: meta.dayLabel,
                sessionID: sessionID
            )

            let pending = PendingSave(sequence: sequence, row: row, savedAt: savedAt, deadline: deadline)
            self.pendingSaves[sequence] = pending
            self.pendingOrder.append(sequence)
            meta.pending.append(SessionMeta.Pending(sequence: sequence, savedAt: savedAt, row: row))
            self.activeMeta = meta

            do {
                try self.saveMeta(meta, sessionID: sessionID)
                try self.walLog.append(sequence: sequence, savedAt: savedAt, row: row, sessionID: sessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to persist WAL/meta \(error)")
                #endif
            }

            self.scheduleCommit(for: pending, sessionID: sessionID)
        }
    }

    func undoLast() {
        queue.async {
            guard let sequence = self.pendingOrder.last,
                  var pending = self.pendingSaves.removeValue(forKey: sequence),
                  var meta = self.activeMeta,
                  let sessionID = self.activeSessionID else {
                return
            }

            self.pendingOrder.removeLast()
            if let timer = self.timers.removeValue(forKey: sequence) {
                timer.cancel()
            }

            meta.pending.removeAll { $0.sequence == sequence }
            self.activeMeta = meta

            do {
                try self.saveMeta(meta, sessionID: sessionID)
                try self.walLog.appendTombstone(sequence: sequence, sessionID: sessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to append tombstone \(error)")
                #endif
            }

            // Restore UI state for the pending row if needed.
        }
    }

    func switchDay(to newDayLabel: String) {
        queue.async {
            guard var meta = self.activeMeta,
                  let plan = self.activePlan,
                  let sessionID = self.activeSessionID else {
                return
            }

            guard meta.dayLabel != newDayLabel,
                  let targetDay = plan.day(named: newDayLabel) else {
                return
            }

            let newBaseDeck = self.deckBuilder.buildDeck(for: targetDay, plan: plan)
            let newDeckHash = SessionManager.computeDeckHash(for: newBaseDeck)

            if !meta.dayLabel.isEmpty {
                meta.switchHistory.append(meta.dayLabel)
            } else if let activeDay = self.activeDay {
                meta.switchHistory.append(activeDay.label)
            }

            meta.dayLabel = targetDay.label
            meta.planName = plan.planName
            meta.sessionId = sessionID
            meta.deckHash = newDeckHash
            meta.mutationMap.removeAll()
            meta.sequenceOverrides.removeAll()

            if newBaseDeck.contains(where: { $0.canSkip }) {
                meta.timedSetsSkipped = false
            }

            self.baseDeck = newBaseDeck
            self.activeDay = targetDay

            let mutatedDeck = self.mutateDeck(newBaseDeck, with: meta, plan: plan)
            self.activeDeck = mutatedDeck
            self.activeMeta = meta

            do {
                try self.saveMeta(meta, sessionID: sessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to persist meta during switch \(error)")
                #endif
            }

            let context = SessionContext(deck: mutatedDeck, sessionID: sessionID, plan: plan, day: targetDay)
            self.activeContext = context
            self.subject.send(.active(context))
        }
    }
}

// MARK: - Helpers

private extension SessionManager {
    struct PendingTimerContext {
        let sequence: UInt64
        let sessionID: String
    }

    private func scheduleCommit(for pending: PendingSave, sessionID: String) {
        let deadline = pending.deadline
        let timeInterval = max(0, deadline.timeIntervalSinceNow)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + timeInterval)
        timer.setEventHandler { [weak self] in
            self?.commit(sequence: pending.sequence, sessionID: sessionID)
        }
        timers[pending.sequence] = timer
        timer.resume()
    }

    private func commit(sequence: UInt64, sessionID: String) {
        guard let pending = pendingSaves.removeValue(forKey: sequence) else {
            timers[sequence]?.cancel()
            timers.removeValue(forKey: sequence)
            return
        }

        timers[sequence]?.cancel()
        timers.removeValue(forKey: sequence)
        pendingOrder.removeAll { $0 == sequence }

        do {
            try globalCsv.appendCommitting(pending.row)
            try indexRepository.applyCommit(pending.row)
        } catch {
            #if DEBUG
            print("SessionManager: failed to commit row \(error)")
            #endif
        }

        if var meta = activeMeta {
            meta.pending.removeAll { $0.sequence == sequence }
            activeMeta = meta
            try? saveMeta(meta, sessionID: sessionID)
        }
    }

    func buildRow(
        for item: DeckItem,
        weight: Double,
        reps: Int,
        effort: DeckItem.Effort,
        sequence: UInt64,
        savedAt: Date,
        plan: PlanV03,
        dayLabel: String,
        sessionID: String
    ) -> CsvRow {
        let weightString = formatWeight(weight)
        let repsString = max(reps, 0)
        var row = CsvRow(
            sessionID: sessionID,
            date: savedAt,
            planName: plan.planName,
            dayLabel: dayLabel,
            segmentID: item.segmentID,
            supersetID: item.supersetID,
            exerciseCode: item.exerciseCode,
            isAdlib: item.adlib,
            setNumber: item.setIndex,
            reps: "\(repsString)",
            weight: weightString,
            unit: item.unit.csvValue,
            isWarmup: item.isWarmup,
            effort: effort.rawValue
        )

        let metadata = [
            "seq=\(sequence)",
            "saved_at=\(Int(savedAt.timeIntervalSince1970))"
        ].joined(separator: ";")
        row.notes = metadata
        row.tags = item.badges.map { $0.lowercased() }.joined(separator: ";")
        return row
    }

    func handlePendingEntries(meta: inout SessionMeta, sessionID: String) {
        timers.values.forEach { $0.cancel() }
        timers.removeAll()
        pendingSaves.removeAll()
        pendingOrder.removeAll()

        var retained: [SessionMeta.Pending] = []
        let now = Date()

        for pending in meta.pending {
            let deadline = pending.savedAt.addingTimeInterval(5)
            let adjusted = PendingSave(
                sequence: pending.sequence,
                row: pending.row,
                savedAt: pending.savedAt,
                deadline: deadline
            )

            if now >= deadline {
                do {
                    try globalCsv.appendCommitting(pending.row)
                    try indexRepository.applyCommit(pending.row)
                } catch {
                    #if DEBUG
                    print("SessionManager: replay commit failed \(error)")
                    #endif
                }
            } else {
                pendingSaves[pending.sequence] = adjusted
                pendingOrder.append(pending.sequence)
                scheduleCommit(for: adjusted, sessionID: sessionID)
                retained.append(pending)
            }
        }

        meta.pending = retained
    }

    func mutateDeck(_ baseDeck: [DeckItem], with meta: SessionMeta, plan: PlanV03) -> [DeckItem] {
        baseDeck.map { baseItem in
            var item = baseItem
            if let override = meta.sequenceOverrides[baseItem.sequence] {
                applyMutation(newCode: override.newCode, to: &item, plan: plan)
            } else if let mutation = meta.mutationMap[baseItem.exerciseCode],
                      baseItem.sequence >= mutation.startSequence {
                applyMutation(newCode: mutation.newCode, to: &item, plan: plan)
            } else {
                tryAssignPrev(for: &item)
            }
            return item
        }
    }

    func applyMutation(newCode: String, to item: inout DeckItem, plan: PlanV03) {
        item.exerciseCode = newCode
        item.exerciseName = plan.exerciseNames[newCode] ?? newCode
        tryAssignPrev(for: &item)
    }

    func tryAssignPrev(for item: inout DeckItem) {
        if let prev = try? indexRepository.fetchLastTwo(for: item.exerciseCode) {
            item.prevCompletions = prev
        }
    }

    func saveMeta(_ meta: SessionMeta, sessionID: String) throws {
        let url = try fileSystem.metaURL(for: sessionID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        var mutableMeta = meta
        mutableMeta.sessionId = sessionID
        let data = try encoder.encode(mutableMeta)
        try fileSystem.writeAtomic(data, to: url)
    }

    func loadMeta(sessionID: String) -> SessionMeta? {
        do {
            let url = try fileSystem.metaURL(for: sessionID)
            guard fileSystem.fileExists(at: url) else { return nil }
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SessionMeta.self, from: data)
        } catch {
            return nil
        }
    }

    func formatWeight(_ weight: Double) -> String {
        if abs(weight) < 0.0001 {
            return "0"
        }
        if abs(weight - round(weight)) < 0.0001 {
            return String(Int(round(weight)))
        }
        var string = String(format: "%.2f", weight)
        while string.last == "0" {
            string.removeLast()
        }
        if string.last == "." {
            string.removeLast()
        }
        return string
    }
}

extension SessionManager {
    enum SessionError: Error {
        case noPlanDay
    }

    static func makeSessionID(date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime]
        return formatter.string(from: date)
    }

    static func computeDeckHash(for deck: [DeckItem]) -> String {
        let signature = deck
            .sorted(by: { $0.sequence < $1.sequence })
            .map { "\($0.sequence)|\($0.segmentID)|\($0.exerciseCode)" }
            .joined(separator: ";")
        return signature.data(using: .utf8).map { data in
            data.base64EncodedString()
        } ?? UUID().uuidString
    }
}
