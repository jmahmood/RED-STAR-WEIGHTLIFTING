//
//  IndexRepository.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

protocol IndexDataStore {
    func readIndex() throws -> [String: [DeckItem.PrevCompletion]]
    func writeIndex(_ index: [String: [DeckItem.PrevCompletion]]) throws
}

struct IndexRepository: IndexDataStore {
    private let fileSystem: FileSystem

    init(fileSystem: FileSystem) {
        self.fileSystem = fileSystem
    }

    func readIndex() throws -> [String: [DeckItem.PrevCompletion]] {
        let url = try fileSystem.indexURL()
        if !fileSystem.fileExists(at: url) {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([String: [DeckItem.PrevCompletion]].self, from: data)
    }

    func writeIndex(_ index: [String: [DeckItem.PrevCompletion]]) throws {
        let url = try fileSystem.indexURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(index)
        try fileSystem.writeAtomic(data, to: url)
    }
}
