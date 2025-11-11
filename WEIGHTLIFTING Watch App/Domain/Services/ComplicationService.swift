//
//  ComplicationService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import WidgetKit
import Foundation

struct ComplicationSnapshot: Equatable {
    let exerciseName: String
    let detail: String
    let footer: String
    let sessionID: String
    let deckIndex: Int
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

    init(userDefaults: UserDefaults = SharedDefaults.shared) {
        self.userDefaults = userDefaults
    }

    func reloadComplications() {
        // Reload all WidgetKit timelines for complications
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateNextUp(context: SessionContext, meta: SessionMeta) {
        // Collect all sequences that are done or in progress (pending + completed)
        let doneSequences = Set(meta.completedSequences + meta.pending.map { $0.sequence })

        guard let nextItem = findNextItem(in: context.deck, doneSequences: doneSequences) else {
            clearNextUp()
            return
        }

        let snapshot = ComplicationSnapshot(
            exerciseName: nextItem.exerciseName,
            detail: formatDetail(for: nextItem, context: context, meta: meta),
            footer: formatFooter(for: nextItem, in: context.deck, doneSequences: doneSequences),
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

    private func findNextItem(in deck: [DeckItem], doneSequences: Set<UInt64>) -> DeckItem? {
        // Find all incomplete items, sort by sequence, and return the first
        return deck
            .filter { !doneSequences.contains($0.sequence) }
            .sorted { $0.sequence < $1.sequence }
            .first
    }

    private func formatDetail(for item: DeckItem, context: SessionContext, meta: SessionMeta) -> String {
        let reps = item.targetReps

        // For set 2+, try to use the weight from set 1 of this exercise in the current session
        let weight: Double
        if item.setIndex > 1, let sessionWeight = findSet1Weight(for: item, in: context.deck, meta: meta) {
            weight = sessionWeight
        } else {
            // For set 1 or if no session weight found, use historical data
            weight = item.prevCompletions.last?.weight ?? 0
        }

        if weight == 0 {
            return reps
        } else {
            let weightStr = formatWeight(weight)
            return "\(weightStr)\(item.unit.displaySymbol) × \(reps)"
        }
    }

    private func findSet1Weight(for item: DeckItem, in deck: [DeckItem], meta: SessionMeta) -> Double? {
        // Find set 1 of the same exercise
        guard let set1 = deck.first(where: { $0.exerciseCode == item.exerciseCode && $0.setIndex == 1 }) else {
            return nil
        }

        // Return the weight if set 1 has been completed
        return meta.sessionWeights[set1.sequence]
    }

    private func formatFooter(for item: DeckItem, in deck: [DeckItem], doneSequences: Set<UInt64>) -> String {
        let remaining = deck.filter {
            $0.sequence > item.sequence &&
            $0.exerciseCode == item.exerciseCode &&
            !doneSequences.contains($0.sequence)
        }.count
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
