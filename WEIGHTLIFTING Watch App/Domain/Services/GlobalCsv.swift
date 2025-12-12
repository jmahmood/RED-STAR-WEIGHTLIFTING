//
//  GlobalCsv.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

protocol GlobalCsvWriting {
    func appendCommitting(_ row: CsvRow) throws
}

final class GlobalCsv: GlobalCsvWriting {
    private let fileSystem: FileSystem
    private static let guardQueue = DispatchQueue(label: "GlobalCsv.guardQueue")
    private static var lastCommit: (sessionID: String, timestamp: Date)?
    private let syncQueue = DispatchQueue(label: "GlobalCsv.syncQueue")
    private var pendingSync: DispatchWorkItem?

    init(fileSystem: FileSystem) {
        self.fileSystem = fileSystem
    }

    func appendCommitting(_ row: CsvRow) throws {
        var mutableRow = row
        GlobalCsv.guardQueue.sync {
            GlobalCsv.enforceUniqueTimestamp(for: &mutableRow)
        }

        let csvURL = try prepareGlobalCsv()
        let line = mutableRow.serialize() + "\n"
        let data = Data(line.utf8)
        try fileSystem.append(data, to: csvURL, performFsync: false)
        scheduleSync(for: csvURL)
    }

    func sync() throws {
        let csvURL = try prepareGlobalCsv()
        try syncQueue.sync {
            pendingSync?.cancel()
            pendingSync = nil
            try flush(csvURL)
        }
    }

    private static func enforceUniqueTimestamp(for row: inout CsvRow) {
        guard let candidate = CsvDateFormatter.date(from: row.dateString, timeString: row.timeString) else {
            lastCommit = (row.sessionID, Date())
            return
        }

        var finalDate = candidate
        if let last = lastCommit, last.sessionID == row.sessionID, finalDate <= last.timestamp {
            finalDate = last.timestamp.addingTimeInterval(1)
        }

        row.dateString = CsvDateFormatter.string(from: finalDate, format: .date)
        row.timeString = CsvDateFormatter.string(from: finalDate, format: .time)
        lastCommit = (row.sessionID, finalDate)
    }

    private func prepareGlobalCsv() throws -> URL {
        let csvURL = try fileSystem.globalCsvURL()
        let headerData = "\(CsvRow.header)\n".data(using: .utf8)
        try fileSystem.ensureFile(at: csvURL, contents: headerData)
        return csvURL
    }

    private func scheduleSync(for url: URL) {
        syncQueue.async {
            self.pendingSync?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                do {
                    try self.flush(url)
                } catch {
                    #if DEBUG
                    print("GlobalCsv: sync flush failed \(error)")
                    #endif
                }
            }
            self.pendingSync = workItem
            self.syncQueue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        }
    }

    private func flush(_ url: URL) throws {
        guard let handle = FileHandle(forUpdatingAtPath: url.path) else {
            throw FileSystem.FileError.fileHandleUnavailable(url)
        }
        defer { try? handle.close() }
        try handle.synchronize()
        fileSystem.fsyncDirectory(containing: url)
    }
}
