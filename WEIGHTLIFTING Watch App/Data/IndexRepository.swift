//
//  IndexRepository.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

protocol IndexDataStore {
    func readIndex() throws -> [String: Last2]
    func writeIndex(_ index: [String: Last2]) throws
}

struct IndexRepository: IndexDataStore {
    private let fileSystem: FileSystem

    init(fileSystem: FileSystem) {
        self.fileSystem = fileSystem
    }

    func readIndex() throws -> [String: Last2] {
        let url = try fileSystem.indexURL()
        if !fileSystem.fileExists(at: url) {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return [:] }
        let decoder = JSONDecoder()
        return try decoder.decode([String: Last2].self, from: data)
    }

    func writeIndex(_ index: [String: Last2]) throws {
        let url = try fileSystem.indexURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        try fileSystem.writeAtomic(data, to: url)
    }
}
