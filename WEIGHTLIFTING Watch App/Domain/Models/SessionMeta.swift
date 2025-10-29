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
        let startSequence: Int
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
    var sequenceOverrides: [Int: Override]
    var nextSequence: UInt64
    var pending: [Pending]
    var lastSaveAt: Date?
    var timedSetsSkipped: Bool
    var switchHistory: [String]

    init(
        sessionId: String,
        planName: String,
        dayLabel: String,
        deckHash: String,
        mutationMap: [String: Mutation] = [:],
        sequenceOverrides: [Int: Override] = [:],
        nextSequence: UInt64 = 1,
        pending: [Pending] = [],
        lastSaveAt: Date? = nil,
        timedSetsSkipped: Bool = false,
        switchHistory: [String] = []
    ) {
        self.sessionId = sessionId
        self.planName = planName
        self.dayLabel = dayLabel
        self.deckHash = deckHash
        self.mutationMap = mutationMap
        self.sequenceOverrides = sequenceOverrides
        self.nextSequence = nextSequence
        self.pending = pending
        self.lastSaveAt = lastSaveAt
        self.timedSetsSkipped = timedSetsSkipped
        self.switchHistory = switchHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        planName = try container.decodeIfPresent(String.self, forKey: .planName) ?? ""
        dayLabel = try container.decodeIfPresent(String.self, forKey: .dayLabel) ?? ""
        deckHash = try container.decode(String.self, forKey: .deckHash)
        mutationMap = try container.decodeIfPresent([String: Mutation].self, forKey: .mutationMap) ?? [:]
        sequenceOverrides = try container.decodeIfPresent([Int: Override].self, forKey: .sequenceOverrides) ?? [:]
        nextSequence = try container.decodeIfPresent(UInt64.self, forKey: .nextSequence) ?? 1
        pending = try container.decodeIfPresent([Pending].self, forKey: .pending) ?? []
        lastSaveAt = try container.decodeIfPresent(Date.self, forKey: .lastSaveAt)
        timedSetsSkipped = try container.decodeIfPresent(Bool.self, forKey: .timedSetsSkipped) ?? false
        switchHistory = try container.decodeIfPresent([String].self, forKey: .switchHistory) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case planName
        case dayLabel
        case deckHash
        case mutationMap
        case sequenceOverrides
        case nextSequence
        case pending
        case lastSaveAt
        case timedSetsSkipped
        case switchHistory
    }
}
