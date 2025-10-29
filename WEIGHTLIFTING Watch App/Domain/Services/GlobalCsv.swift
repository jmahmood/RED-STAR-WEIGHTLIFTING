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
        try fileSystem.append(data, to: csvURL, performFsync: true)
        fileSystem.fsyncDirectory(containing: csvURL)
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
}
