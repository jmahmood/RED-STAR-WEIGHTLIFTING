//
//  WalLog.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

struct WalEntry: Codable, Equatable {
    enum Kind: String, Codable {
        case row
        case tombstone
    }

    let kind: Kind
    let sequence: UInt64
    let savedAt: Date?
    let row: CsvRow?
}

protocol WalLogging {
    func append(sequence: UInt64, savedAt: Date, row: CsvRow, sessionID: String) throws
    func appendTombstone(sequence: UInt64, sessionID: String) throws
    func readEntries(for sessionID: String) throws -> [WalEntry]
}

final class WalLog: WalLogging {
    private let fileSystem: FileSystem
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let syncQueue = DispatchQueue(label: "WalLog.syncQueue")
    private var pendingSync: [URL: DispatchWorkItem] = [:]

    init(fileSystem: FileSystem) {
        self.fileSystem = fileSystem
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func append(sequence: UInt64, savedAt: Date, row: CsvRow, sessionID: String) throws {
        let walURL = try prepareWal(for: sessionID)
        let entry = WalEntry(kind: .row, sequence: sequence, savedAt: savedAt, row: row)
        let data = try encoder.encode(entry) + Data([0x0A])
        try fileSystem.append(data, to: walURL, performFsync: false)
        scheduleSync(for: walURL)
    }

    func appendTombstone(sequence: UInt64, sessionID: String) throws {
        let walURL = try prepareWal(for: sessionID)
        let entry = WalEntry(kind: .tombstone, sequence: sequence, savedAt: nil, row: nil)
        let data = try encoder.encode(entry) + Data([0x0A])
        try fileSystem.append(data, to: walURL, performFsync: false)
        scheduleSync(for: walURL)
    }

    func readEntries(for sessionID: String) throws -> [WalEntry] {
        let walURL = try prepareWal(for: sessionID)
        guard fileSystem.fileExists(at: walURL) else { return [] }
        let content = try String(contentsOf: walURL, encoding: .utf8)
        var entries: [WalEntry] = []
        for line in content.split(whereSeparator: \.isNewline) {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            if let data = line.data(using: .utf8) {
                if let entry = try? decoder.decode(WalEntry.self, from: data) {
                    entries.append(entry)
                }
            }
        }
        return entries
    }

    private func prepareWal(for sessionID: String) throws -> URL {
        let walURL = try fileSystem.walURL(for: sessionID)
        try fileSystem.ensureFile(at: walURL, contents: nil)
        return walURL
    }

    private func scheduleSync(for url: URL) {
        syncQueue.async {
            if let workItem = self.pendingSync[url] {
                workItem.cancel()
            }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingSync[url] = nil
                self.flush(url: url)
            }
            self.pendingSync[url] = workItem
            self.syncQueue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        }
    }

    private func flush(url: URL) {
        guard let handle = FileHandle(forUpdatingAtPath: url.path) else {
            return
        }
        defer { try? handle.close() }
        try? handle.synchronize()
        fileSystem.fsyncDirectory(containing: url)
    }
}
