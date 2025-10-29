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

    var deckHash: String
    var mutationMap: [String: Mutation]
    var sequenceOverrides: [Int: Override]
    var nextSequence: UInt64
    var pending: [Pending]

    init(
        deckHash: String,
        mutationMap: [String: Mutation] = [:],
        sequenceOverrides: [Int: Override] = [:],
        nextSequence: UInt64 = 1,
        pending: [Pending] = []
    ) {
        self.deckHash = deckHash
        self.mutationMap = mutationMap
        self.sequenceOverrides = sequenceOverrides
        self.nextSequence = nextSequence
        self.pending = pending
    }
}

