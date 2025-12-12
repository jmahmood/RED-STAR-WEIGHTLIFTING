//
//  SessionMeta.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-28.
//

import Foundation

struct SessionMeta: Codable, Equatable {
    struct Mutation: Codable, Equatable {
        let newCode: String
        let startSequence: UInt64
    }

    struct Override: Codable, Equatable {
        let newCode: String
    }

    struct Pending: Codable, Equatable {
        let sequence: UInt64
        let savedAt: Date
        let row: CsvRow
    }

    var sessionId: String
    var planName: String
    var dayLabel: String
    var deckHash: String
    var mutationMap: [String: Mutation]
    var sequenceOverrides: [UInt64: Override]
    var pending: [Pending]
    var lastSaveAt: Date?
    var timedSetsSkipped: Bool
    var switchHistory: [String]
    var sessionCompleted: Bool
    var completedSequences: [UInt64]
    var sessionWeights: [UInt64: Double]
    // V0.4: Cycle tracking for multi-week programs (5-3-1, etc.)
    var cycleWeek: Int
    var cycleId: String

    init(
        sessionId: String,
        planName: String,
        dayLabel: String,
        deckHash: String,
        mutationMap: [String: Mutation] = [:],
        sequenceOverrides: [UInt64: Override] = [:],
        pending: [Pending] = [],
        lastSaveAt: Date? = nil,
        timedSetsSkipped: Bool = false,
        switchHistory: [String] = [],
        sessionCompleted: Bool = false,
        completedSequences: [UInt64] = [],
        sessionWeights: [UInt64: Double] = [:],
        cycleWeek: Int = 1,
        cycleId: String = ""
    ) {
        self.sessionId = sessionId
        self.planName = planName
        self.dayLabel = dayLabel
        self.deckHash = deckHash
        self.mutationMap = mutationMap
        self.sequenceOverrides = sequenceOverrides
        self.pending = pending
        self.lastSaveAt = lastSaveAt
        self.timedSetsSkipped = timedSetsSkipped
        self.switchHistory = switchHistory
        self.sessionCompleted = sessionCompleted
        self.completedSequences = completedSequences
        self.sessionWeights = sessionWeights
        self.cycleWeek = cycleWeek
        self.cycleId = cycleId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        planName = try container.decodeIfPresent(String.self, forKey: .planName) ?? ""
        dayLabel = try container.decodeIfPresent(String.self, forKey: .dayLabel) ?? ""
        deckHash = try container.decode(String.self, forKey: .deckHash)
        mutationMap = try container.decodeIfPresent([String: Mutation].self, forKey: .mutationMap) ?? [:]
        sequenceOverrides = try container.decodeIfPresent([UInt64: Override].self, forKey: .sequenceOverrides) ?? [:]
        pending = try container.decodeIfPresent([Pending].self, forKey: .pending) ?? []
        lastSaveAt = try container.decodeIfPresent(Date.self, forKey: .lastSaveAt)
        timedSetsSkipped = try container.decodeIfPresent(Bool.self, forKey: .timedSetsSkipped) ?? false
        switchHistory = try container.decodeIfPresent([String].self, forKey: .switchHistory) ?? []
        sessionCompleted = try container.decodeIfPresent(Bool.self, forKey: .sessionCompleted) ?? false
        completedSequences = try container.decodeIfPresent([UInt64].self, forKey: .completedSequences) ?? []
        sessionWeights = try container.decodeIfPresent([UInt64: Double].self, forKey: .sessionWeights) ?? [:]
        cycleWeek = try container.decodeIfPresent(Int.self, forKey: .cycleWeek) ?? 1
        cycleId = try container.decodeIfPresent(String.self, forKey: .cycleId) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case planName
        case dayLabel
        case deckHash
        case mutationMap
        case sequenceOverrides
        case pending
        case lastSaveAt
        case timedSetsSkipped
        case switchHistory
        case sessionCompleted
        case completedSequences
        case sessionWeights
        case cycleWeek
        case cycleId
    }
}
