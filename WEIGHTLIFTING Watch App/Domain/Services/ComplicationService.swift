//
//  ComplicationService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import ClockKit
import Foundation

struct ComplicationSnapshot: Equatable {
    let exerciseName: String
    let detail: String
    let footer: String
    let sessionID: String
    let deckIndex: Int
}

enum ComplicationDefaultsKey {
    static let exercise = "complication_next_exercise"
    static let detail = "complication_next_detail"
    static let footer = "complication_next_footer"
    static let sessionID = "complication_next_sessionID"
    static let deckIndex = "complication_next_deckIndex"
}

extension ComplicationSnapshot {
    init?(userDefaults: UserDefaults) {
        guard let exerciseName = userDefaults.string(forKey: ComplicationDefaultsKey.exercise),
              let detail = userDefaults.string(forKey: ComplicationDefaultsKey.detail),
              let footer = userDefaults.string(forKey: ComplicationDefaultsKey.footer),
              let sessionID = userDefaults.string(forKey: ComplicationDefaultsKey.sessionID) else {
            return nil
        }
        let deckIndex = userDefaults.integer(forKey: ComplicationDefaultsKey.deckIndex)
        self.init(
            exerciseName: exerciseName,
            detail: detail,
            footer: footer,
            sessionID: sessionID,
            deckIndex: deckIndex
        )
    }
}

final class ComplicationService {
    private let userDefaults: UserDefaults
    private var lastSnapshot: ComplicationSnapshot?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func reloadComplications() {
        let server = CLKComplicationServer.sharedInstance()
        guard let complications = server.activeComplications,
              !complications.isEmpty else {
            return
        }

        let work = {
            complications.forEach { server.reloadTimeline(for: $0) }
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    func updateNextUp(context: SessionContext, meta: SessionMeta) {
        guard let nextItem = findNextItem(in: context.deck, after: meta.nextSequence) else {
            clearNextUp()
            return
        }

        let snapshot = ComplicationSnapshot(
            exerciseName: nextItem.exerciseName,
            detail: formatDetail(for: nextItem),
            footer: formatFooter(for: nextItem, in: context.deck, after: meta.nextSequence),
            sessionID: context.sessionID,
            deckIndex: context.deck.firstIndex(where: { $0.id == nextItem.id }) ?? 0
        )

        guard snapshot != lastSnapshot else {
            return
        }

        userDefaults.set(snapshot.exerciseName, forKey: ComplicationDefaultsKey.exercise)
        userDefaults.set(snapshot.detail, forKey: ComplicationDefaultsKey.detail)
        userDefaults.set(snapshot.footer, forKey: ComplicationDefaultsKey.footer)
        userDefaults.set(snapshot.sessionID, forKey: ComplicationDefaultsKey.sessionID)
        userDefaults.set(snapshot.deckIndex, forKey: ComplicationDefaultsKey.deckIndex)

        lastSnapshot = snapshot
        reloadComplications()
    }

    func clearNextUp() {
        guard lastSnapshot != nil ||
                userDefaults.string(forKey: ComplicationDefaultsKey.exercise) != nil else {
            return
        }

        lastSnapshot = nil
        userDefaults.removeObject(forKey: ComplicationDefaultsKey.exercise)
        userDefaults.removeObject(forKey: ComplicationDefaultsKey.detail)
        userDefaults.removeObject(forKey: ComplicationDefaultsKey.footer)
        userDefaults.removeObject(forKey: ComplicationDefaultsKey.sessionID)
        userDefaults.removeObject(forKey: ComplicationDefaultsKey.deckIndex)
        reloadComplications()
    }

    private func findNextItem(in deck: [DeckItem], after sequence: UInt64) -> DeckItem? {
        return deck.first { $0.sequence >= Int(sequence) }
    }

    private func formatDetail(for item: DeckItem) -> String {
        let reps = item.targetReps
        let weight = item.prevCompletions.last?.weight ?? 0
        if weight == 0 {
            return reps
        } else {
            let weightStr = formatWeight(weight)
            return "\(weightStr)\(item.unit.displaySymbol) × \(reps)"
        }
    }

    private func formatFooter(for item: DeckItem, in deck: [DeckItem], after sequence: UInt64) -> String {
        let remaining = deck.filter { $0.sequence > item.sequence && $0.exerciseCode == item.exerciseCode }.count
        if remaining > 0 {
            return "••• +\(remaining)"
        } else {
            return ""
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if abs(weight) < 0.0001 {
            return "0"
        }
        if abs(weight - round(weight)) < 0.0001 {
            return String(Int(round(weight)))
        }
        var string = String(format: "%.1f", weight)
        if string.last == "0" {
            string.removeLast()
        }
        if string.last == "." {
            string.removeLast()
        }
        return string
    }
}
