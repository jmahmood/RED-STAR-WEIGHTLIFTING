//
//  DeckItem.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

// Shared plan model typealiases for clarity
typealias PlanLoadAxisTarget = PlanV03.LoadAxisTarget

struct DeckItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case straight
        case scheme
        case supersetA
        case supersetB
    }

    struct PrevCompletion: Hashable, Codable {
        let date: Date
        let weight: Double?
        let reps: Int?
        let effortRaw: Int?

        var effort: Effort? {
            effortRaw.flatMap(Effort.init(rawValue:))
        }

        init(date: Date, weight: Double?, reps: Int?, effort: Effort?) {
            self.date = date
            self.weight = weight
            self.reps = reps
            self.effortRaw = effort?.rawValue
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(Date.self, forKey: .date)
            weight = try container.decodeIfPresent(Double.self, forKey: .weight)
            reps = try container.decodeIfPresent(Int.self, forKey: .reps)
            effortRaw = try container.decodeIfPresent(Int.self, forKey: .effort)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(date, forKey: .date)
            try container.encodeIfPresent(weight, forKey: .weight)
            try container.encodeIfPresent(reps, forKey: .reps)
            try container.encodeIfPresent(effortRaw, forKey: .effort)
        }

        private enum CodingKeys: String, CodingKey {
            case date
            case weight
            case reps
            case effort
        }
    }

    enum Effort: Int, CaseIterable {
        case easy = 1
        case expected = 3
        case hard = 5

        var displayTitle: String {
            switch self {
            case .easy: return "💤"
            case .expected: return "🎯"
            case .hard: return "🔥"
            }
        }
    }

    struct WeightPrescription: Hashable {
        let scheme: String
        let percentage: Double?
        let baseSetIndex: Int

        static let flat = WeightPrescription(
            scheme: "flat",
            percentage: nil,
            baseSetIndex: 1
        )
    }

    let id: UUID
    let kind: Kind
    let supersetID: String?
    let segmentID: Int
    let sequence: UInt64
    let setIndex: Int
    let round: Int?
    var exerciseCode: String
    var exerciseName: String
    let altGroup: String?
    let targetReps: String
    let unit: WeightUnit
    let isWarmup: Bool
    let badges: [String]
    let canSkip: Bool
    let restSeconds: Int?
    let weightPrescription: WeightPrescription
    // V0.4: Load axis support for non-weight tracking (band colors, machine settings)
    let loadAxisTarget: PlanLoadAxisTarget?
    var selectedAxisValue: String?

    var adlib: Bool = false
    var prevCompletions: [PrevCompletion] = []
}
