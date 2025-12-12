//
//  CSVIndexBuilder.swift
//  Shared
//
//  Shared CSV indexing utilities used by both the iOS and watchOS apps.
//  Builds a per-exercise map of the last two completions from all_time.csv.
//

import Foundation

public struct CSVIndexRow: Equatable {
    public let dateString: String
    public let timeString: String
    public let weight: Double
    public let unit: String
    public let reps: Int?
    public let effort: Int?

    public var signature: String { "\(dateString)|\(timeString)|\(weight)" }
}

public enum CSVIndexBuilderError: Error {
    case fileMissing
    case invalidHeader
}

public enum CSVIndexBuilder {
    /// Build a per-exercise index of the last two completions from a CSV file.
    /// - Parameter csvURL: Location of `all_time.csv`.
    /// - Returns: Map of exercise code → up to the two most recent rows.
    public static func buildLastTwoByExercise(from csvURL: URL) throws -> [String: [CSVIndexRow]] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: csvURL.path) else {
            throw CSVIndexBuilderError.fileMissing
        }

        let (_, rows) = try CSVReader.readRows(from: csvURL, fileManager: fileManager)

        var scratch: [String: [(row: CSVIndexRow, sortDate: Date?)]] = [:]

        for row in rows {
            let exCode = row.exerciseCode.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !exCode.isEmpty else { continue }
            guard let weight = row.weight else { continue }

            let reps = Int(row.repsString)
            let effort = row.effort.flatMap { $0 > 0 ? $0 : nil }
            let sortDate = row.timestamp

            let indexRow = CSVIndexRow(
                dateString: row.dateString,
                timeString: row.timeString,
                weight: weight,
                unit: row.unitString,
                reps: reps,
                effort: effort
            )

            var bucket = scratch[exCode] ?? []
            bucket.append((indexRow, sortDate))
            scratch[exCode] = bucket
        }

        var result: [String: [CSVIndexRow]] = [:]
        for (code, entries) in scratch {
            let sorted = entries.sorted { lhs, rhs in
                switch (lhs.sortDate, rhs.sortDate) {
                case let (l?, r?):
                    return l > r
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    return false
                }
            }
            let trimmed = sorted.prefix(2).map { $0.row }
            if !trimmed.isEmpty {
                result[code] = Array(trimmed)
            }
        }

        return result
    }
}

public enum CSVTimestampParser {
    public static func parse(dateString: String?, timeString: String?) -> Date? {
        guard let dateString, !dateString.isEmpty else { return nil }

        if let timeString, !timeString.isEmpty {
            let full = "\(dateString)T\(timeString)"
            if let combined = isoDateTimeFormatter.date(from: full) {
                return combined
            }
        }

        if let dateOnly = isoDateFormatter.date(from: dateString) {
            return dateOnly
        }

        return dashDateFormatter.date(from: dateString)
    }

    private static let isoDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return formatter
    }()

    private static let dashDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

