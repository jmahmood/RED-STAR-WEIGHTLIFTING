//
//  WeightSuggestionService.swift
//  WEIGHTLIFTING Watch App
//
//  Weight suggestion service for calculating suggested weights based on
//  progression schemes (flat, percentage-based, etc.)
//

import Foundation

/// Protocol for weight suggestion strategies
protocol WeightSuggesting {
    func suggestWeight(
        for item: DeckItem,
        sessionWeights: [UInt64: Double],
        deck: [DeckItem]
    ) -> Double
}

/// Service that calculates weight suggestions based on progression schemes
final class WeightSuggestionService: WeightSuggesting {
    private let flatStrategy: FlatWeightStrategy

    init() {
        self.flatStrategy = FlatWeightStrategy()
    }

    func suggestWeight(
        for item: DeckItem,
        sessionWeights: [UInt64: Double],
        deck: [DeckItem]
    ) -> Double {
        // For now, only support flat strategy
        // In the future, route to different strategies based on item.weightPrescription.scheme
        return flatStrategy.calculate(for: item, sessionWeights: sessionWeights, deck: deck)
    }
}

/// Strategy for "flat" weight prescription (all sets use same weight)
struct FlatWeightStrategy {
    func calculate(
        for item: DeckItem,
        sessionWeights: [UInt64: Double],
        deck: [DeckItem]
    ) -> Double {
        // For set 2+, use set 1 weight from current session
        if item.setIndex > 1, let set1Weight = findSet1Weight(for: item, sessionWeights: sessionWeights, deck: deck) {
            return set1Weight
        }

        // For set 1 or no session weight found, use historical data
        return item.prevCompletions.first?.weight ?? 0
    }

    private func findSet1Weight(
        for item: DeckItem,
        sessionWeights: [UInt64: Double],
        deck: [DeckItem]
    ) -> Double? {
        // Find set 1 of the same exercise
        guard let set1 = deck.first(where: { $0.exerciseCode == item.exerciseCode && $0.setIndex == 1 }) else {
            return nil
        }

        // Return the weight if set 1 has been completed
        return sessionWeights[set1.sequence]
    }
}
