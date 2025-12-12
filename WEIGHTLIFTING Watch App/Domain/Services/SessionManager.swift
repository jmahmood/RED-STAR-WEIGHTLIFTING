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
    let completedSequences: [UInt64]
}

protocol SessionManaging {
    var sessionPublisher: AnyPublisher<SessionState, Never> { get }
    func loadInitialSession()
    func recordMutation(
        originalCode: String,
        newCode: String,
        scope: ExerciseSwitchScope,
        startSequence: UInt64,
        affectedSequences: [UInt64]
    )
    func save(`set` item: DeckItem, weight: Double, reps: Int, effort: DeckItem.Effort)
    func undoLast()
    func switchDay(to newDayLabel: String)
    func startNewSession(dayLabel: String)
    func markSessionCompleted()
}

final class SessionManager: SessionManaging {
    private let fileSystem: FileSystem
    private let planRepository: PlanRepository
    private let deckBuilder: DeckBuilding
    private let cycleManager: CycleManaging
    private let walLog: WalLogging
    private let globalCsv: GlobalCsvWriting
    private let indexRepository: IndexRepositorying
    private let complicationService: ComplicationService

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

    init(
        fileSystem: FileSystem,
        planRepository: PlanRepository,
        deckBuilder: DeckBuilding,
        cycleManager: CycleManaging = CycleManager(),
        walLog: WalLogging,
        globalCsv: GlobalCsvWriting,
        indexRepository: IndexRepositorying,
        complicationService: ComplicationService
    ) {
        self.fileSystem = fileSystem
        self.planRepository = planRepository
        self.deckBuilder = deckBuilder
        self.cycleManager = cycleManager
        self.walLog = walLog
        self.globalCsv = globalCsv
        self.indexRepository = indexRepository
        self.complicationService = complicationService
    }

    var sessionPublisher: AnyPublisher<SessionState, Never> {
        subject.eraseToAnyPublisher()
    }

    func loadInitialSession() {
        queue.async(group: nil, execute: {
            do {
                let plan = try self.planRepository.loadActivePlan()
                let restoredSession = self.restoreLatestSessionMeta()
                let sessionID: String
                let existingMeta: SessionMeta?

                if let restored = restoredSession, restored.meta.planName == plan.planName {
                    sessionID = restored.sessionID
                    existingMeta = restored.meta
                } else {
                    sessionID = SessionManager.makeSessionID(date: Date())
                    existingMeta = nil
                }

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

                // V0.4: Check for week advancement and initialize cycleId
                var meta: SessionMeta
                if var persisted = existingMeta {
                    // Check if we should advance week
                    if self.cycleManager.shouldAdvanceWeek(meta: persisted, plan: plan) {
                        let (newWeek, newCycleId) = self.cycleManager.advanceWeek(meta: persisted, plan: plan)
                        persisted.cycleWeek = newWeek
                        persisted.cycleId = newCycleId
                        persisted.switchHistory.removeAll() // Reset for new cycle
                    }

                    // Build deck with current week
                    let baseDeck = self.deckBuilder.buildDeck(for: day, plan: plan, currentWeek: persisted.cycleWeek)
                    let deckHash = SessionManager.computeDeckHash(for: baseDeck)

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

                    self.baseDeck = baseDeck
                } else {
                    // CRITICAL: Initialize cycleId on first session (not empty string)
                    let cycleId = self.cycleManager.computeCycleId(week: 1, startDate: Date())

                    let baseDeck = self.deckBuilder.buildDeck(for: day, plan: plan, currentWeek: 1)
                    let deckHash = SessionManager.computeDeckHash(for: baseDeck)

                    meta = SessionMeta(
                        sessionId: sessionID,
                        planName: plan.planName,
                        dayLabel: day.label,
                        deckHash: deckHash,
                        cycleWeek: 1,
                        cycleId: cycleId
                    )

                    self.baseDeck = baseDeck
                }

                self.activePlan = plan
                self.activeDay = day
                self.activeSessionID = sessionID

                let mutatedDeck = self.mutateDeck(self.baseDeck, with: meta, plan: plan)
                self.activeDeck = mutatedDeck

                self.handlePendingEntries(meta: &meta, sessionID: sessionID)
                try self.saveMeta(meta, sessionID: sessionID)

                self.activeMeta = meta

                let context = SessionContext(deck: mutatedDeck, sessionID: sessionID, plan: plan, day: day, completedSequences: meta.completedSequences)
                self.activeContext = context

                self.complicationService.updateNextUp(context: context, meta: meta)

                // Check for auto-advance
                if meta.sessionCompleted,
                   let lastSave = meta.lastSaveAt,
                   Date().timeIntervalSince1970 - lastSave.timeIntervalSince1970 > 3600, // more than 1 hour
                   let sessionDate = self.parseSessionDate(sessionID),
                   Calendar.current.isDateInYesterday(sessionDate) {
                    // Auto-advance to next day
                    let nextDayLabel = self.nextDayLabel(after: day.label, in: plan)
                    self.switchDay(to: nextDayLabel)
                } else {
                    self.subject.send(.active(context))
                }
            } catch {
                self.subject.send(.error(error))
            }
        })
    }

    func recordMutation(
        originalCode: String,
        newCode: String,
        scope: ExerciseSwitchScope,
        startSequence: UInt64,
        affectedSequences: [UInt64]
    ) {
        queue.async(group: nil, execute: {
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
            self.activeMeta = meta

            do {
                try self.saveMeta(meta, sessionID: sessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to persist meta during switch \(error)")
                #endif
            }

            let context = SessionContext(deck: self.activeDeck, sessionID: sessionID, plan: plan, day: day, completedSequences: meta.completedSequences)
            self.activeContext = context
            self.complicationService.updateNextUp(context: context, meta: meta)
            self.subject.send(.active(context))
        })
    }

    func markSessionCompleted() {
        queue.async(group: nil, execute: {
            guard var meta = self.activeMeta,
                  let sessionID = self.activeSessionID else {
                return
            }

            meta.sessionCompleted = true
            self.activeMeta = meta

            do {
                try self.saveMeta(meta, sessionID: sessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to mark session completed \(error)")
                #endif
            }
        })
    }

    func save(`set` item: DeckItem, weight: Double, reps: Int, effort: DeckItem.Effort) {
        queue.async(group: nil, execute: {
            guard var meta = self.activeMeta,
                  let plan = self.activePlan,
                  let day = self.activeDay,
                  let sessionID = self.activeSessionID else {
                return
            }

            let sequence = item.sequence
            let savedAt = Date()
            // V0.4: Pass cycle info to buildRow for tag generation
            let row = self.buildRow(
                for: item,
                weight: weight,
                reps: reps,
                effort: effort,
                sequence: sequence,
                savedAt: savedAt,
                plan: plan,
                dayLabel: day.label,
                sessionID: sessionID,
                cycleWeek: meta.cycleWeek,
                cycleId: meta.cycleId
            )

            let deadline = savedAt.addingTimeInterval(5)
            let pendingSave = PendingSave(
                sequence: sequence,
                row: row,
                savedAt: savedAt,
                deadline: deadline
            )

            self.pendingSaves[sequence] = pendingSave
            self.pendingOrder.append(sequence)

            let metaPending = SessionMeta.Pending(
                sequence: sequence,
                savedAt: savedAt,
                row: row
            )
            meta.pending.append(metaPending)
            meta.sessionWeights[sequence] = weight
            meta.lastSaveAt = savedAt
            self.activeMeta = meta

            do {
                try self.saveMeta(meta, sessionID: sessionID)
                try self.walLog.append(sequence: sequence, savedAt: savedAt, row: row, sessionID: sessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to save set \(error)")
                #endif
            }

            CommitWheel.shared.arm(seq: Int(sequence), deadline: deadline) { [weak self] in
                self?.commit(sequence: sequence, sessionID: sessionID)
            }

            if let context = self.activeContext {
                self.complicationService.updateNextUp(context: context, meta: meta)
            }
        })
    }

    func undoLast() {
        queue.async(group: nil, execute: {
            guard let lastSequence = self.pendingOrder.last,
                  var meta = self.activeMeta,
                  let sessionID = self.activeSessionID else {
                return
            }

            self.pendingSaves.removeValue(forKey: lastSequence)
            self.pendingOrder.removeLast()

            meta.pending.removeAll { $0.sequence == lastSequence }
            meta.sessionWeights.removeValue(forKey: lastSequence)
            self.activeMeta = meta

            do {
                try self.saveMeta(meta, sessionID: sessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to save meta after undo \(error)")
                #endif
            }

            if let context = self.activeContext {
                self.complicationService.updateNextUp(context: context, meta: meta)
            }
        })
    }

    func switchDay(to newDayLabel: String) {
        queue.async(group: nil, execute: {
            guard var meta = self.activeMeta,
                  let plan = self.activePlan,
                  let sessionID = self.activeSessionID else {
                return
            }

            guard meta.dayLabel != newDayLabel,
                  let targetDay = plan.day(named: newDayLabel) else {
                return
            }

            // V0.4: Pass currentWeek for per_week resolution
            let newBaseDeck = self.deckBuilder.buildDeck(for: targetDay, plan: plan, currentWeek: meta.cycleWeek)
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
            meta.completedSequences = []

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

            let context = SessionContext(deck: mutatedDeck, sessionID: sessionID, plan: plan, day: targetDay, completedSequences: meta.completedSequences)
            self.activeContext = context
            self.complicationService.updateNextUp(context: context, meta: meta)
            self.subject.send(.active(context))
        })
    }

    func startNewSession(dayLabel: String) {
        queue.async(group: nil, execute: {
            guard let plan = self.activePlan else {
                return
            }

            guard let targetDay = plan.day(named: dayLabel) else {
                return
            }

            // Generate a new session ID based on current date
            let newSessionID = SessionManager.makeSessionID(date: Date())

            // V0.4: Use cycleWeek from previous session if available
            let currentWeek = self.activeMeta?.cycleWeek ?? 1
            let newBaseDeck = self.deckBuilder.buildDeck(for: targetDay, plan: plan, currentWeek: currentWeek)
            let newDeckHash = SessionManager.computeDeckHash(for: newBaseDeck)

            // Create fresh meta with the new session ID
            var meta = SessionMeta(
                sessionId: newSessionID,
                planName: plan.planName,
                dayLabel: targetDay.label,
                deckHash: newDeckHash
            )

            // Add current day to switch history if we have an active session
            if let oldMeta = self.activeMeta, !oldMeta.dayLabel.isEmpty {
                meta.switchHistory.append(oldMeta.dayLabel)
            } else if let activeDay = self.activeDay {
                meta.switchHistory.append(activeDay.label)
            }

            // Clear any pending saves from the old session
            self.pendingSaves.removeAll()
            self.pendingOrder.removeAll()

            self.baseDeck = newBaseDeck
            self.activeDay = targetDay
            self.activeSessionID = newSessionID

            let mutatedDeck = self.mutateDeck(newBaseDeck, with: meta, plan: plan)
            self.activeDeck = mutatedDeck
            self.activeMeta = meta

            do {
                try self.saveMeta(meta, sessionID: newSessionID)
            } catch {
                #if DEBUG
                print("SessionManager: failed to persist meta during startNewSession \(error)")
                #endif
            }

            let context = SessionContext(deck: mutatedDeck, sessionID: newSessionID, plan: plan, day: targetDay, completedSequences: meta.completedSequences)
            self.activeContext = context
            self.complicationService.updateNextUp(context: context, meta: meta)
            self.subject.send(.active(context))
        })
    }
}

// MARK: - Helpers

private extension SessionManager {
    func restoreLatestSessionMeta() -> (sessionID: String, meta: SessionMeta)? {
        guard let metaFiles = try? fileSystem.listSessionMetaFiles(), !metaFiles.isEmpty else {
            return nil
        }

        var latest: (date: Date, id: String, meta: SessionMeta)?

        for url in metaFiles {
            guard let sessionID = SessionManager.sessionID(fromMetaURL: url),
                  let meta = self.loadMeta(sessionID: sessionID) else {
                continue
            }

            let modifiedDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let candidateDate = modifiedDate ?? meta.lastSaveAt ?? Date.distantPast

            if latest == nil || candidateDate > latest!.date {
                latest = (candidateDate, sessionID, meta)
            }
        }

        guard let latest else { return nil }
        return (latest.id, latest.meta)
    }

    static func sessionID(fromMetaURL url: URL) -> String? {
        let base = url.deletingPathExtension().deletingPathExtension().lastPathComponent
        return base.isEmpty ? nil : base
    }

    struct PendingTimerContext {
        let sequence: UInt64
        let sessionID: String
    }



    private func commit(sequence: UInt64, sessionID: String) {
        guard let pending = pendingSaves.removeValue(forKey: sequence) else {
            return
        }

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
            meta.completedSequences.append(sequence)
            activeMeta = meta
            try? saveMeta(meta, sessionID: sessionID)

            // Update complication after commit completes
            if let context = activeContext {
                complicationService.updateNextUp(context: context, meta: meta)
            }
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
        sessionID: String,
        cycleWeek: Int,
        cycleId: String
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

        // V0.4: Build tags with cycle info and load axes
        var tags: [String] = item.badges.map { $0.lowercased() }
        tags.append("cycle_week=\(cycleWeek)")
        tags.append("cycle_id=\(cycleId)")

        // Add load axis tag if selected
        if let target = item.loadAxisTarget,
           let value = item.selectedAxisValue {
            tags.append("axis.\(target.axis)=\(value)")
        }

        row.tags = tags.joined(separator: ";")
        return row
    }

    func handlePendingEntries(meta: inout SessionMeta, sessionID: String) {
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
                    meta.completedSequences.append(pending.sequence)
                } catch {
                    #if DEBUG
                    print("SessionManager: replay commit failed \(error)")
                    #endif
                }
             } else {
                 pendingSaves[pending.sequence] = adjusted
                 pendingOrder.append(pending.sequence)
                 CommitWheel.shared.arm(seq: Int(pending.sequence), deadline: adjusted.deadline) { [weak self] in
                     self?.commit(sequence: pending.sequence, sessionID: sessionID)
                 }
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
        let base = sessionIDFormatter.string(from: date)
        let milliseconds = Int((date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1000)
        return "\(base)-\(String(format: "%03d", abs(milliseconds)))"
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

    private func parseSessionDate(_ sessionID: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: String(sessionID.prefix(10))) // YYYY-MM-DD
    }

    private func nextDayLabel(after currentLabel: String, in plan: PlanV03) -> String {
        guard let currentIndex = plan.scheduleOrder.firstIndex(of: currentLabel) else {
            return plan.scheduleOrder.first ?? currentLabel
        }
        let nextIndex = (currentIndex + 1) % plan.scheduleOrder.count
        return plan.scheduleOrder[nextIndex]
    }

    private static let sessionIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        return formatter
    }()
}
