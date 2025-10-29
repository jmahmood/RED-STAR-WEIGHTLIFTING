//
//  SessionViewModel.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-28.
//

import Foundation
import Combine

/// Represents a single deck item that is currently active on the watch.
struct SessionSet: Equatable {
    var exerciseName: String
    var exCode: String
    var weight: Double?
    var unit: String
    var reps: Int?
}

/// View model that owns the state for the active session card. The real app
/// will eventually manage a full deck; for sprint two we focus on prefilling
/// the weight from the global index.
@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var previousEntries: [LatestWeight] = []
    @Published var currentSet: SessionSet

    private let indexService: IndexService

    init(currentSet: SessionSet, indexService: IndexService = .shared) {
        self.currentSet = currentSet
        self.indexService = indexService
    }

    /// Prefills the active set with the most recent weight and stores the last
    /// two rows for UI rendering.
    func prefillWeight() {
        let entries = indexService.lastTwo(exCode: currentSet.exCode)
        previousEntries = entries

        guard let latest = entries.first else {
            return
        }

        currentSet.weight = latest.weight
        currentSet.unit = latest.unit
        currentSet.reps = latest.reps
    }

    /// Returns a short textual representation of the most recent logged weight.
    var latestWeightLabel: String? {
        guard let latest = previousEntries.first else {
            return nil
        }
        return "\(SessionViewModel.format(weight: latest.weight)) \(latest.unit)"
    }

    static func format(weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        } else {
            return String(format: "%.1f", weight)
        }
    }
}

extension LatestWeight {
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var displayString: String {
        let dateString = LatestWeight.displayDateFormatter.string(from: date)
        return "Prev: \(trimmedWeightString()) × \(reps) (\(dateString))"
    }

    private func trimmedWeightString() -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) \(unit)"
        } else {
            return "\(String(format: "%.1f", weight)) \(unit)"
        }
    }
}
