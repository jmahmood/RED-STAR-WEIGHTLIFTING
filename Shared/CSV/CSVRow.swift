//
//  CSVRow.swift
//  Shared
//
//  Typed representation of a CSV v0.3 row.
//

import Foundation

public struct CSVRow: Sendable {
    public let sessionID: String
    public let dateString: String
    public let timeString: String
    public let planName: String
    public let dayLabel: String
    public let segmentID: Int?
    public let supersetID: String?
    public let exerciseCode: String
    public let adlib: Bool
    public let setNumber: Int?
    public let repsString: String
    public let timeSec: Int?
    public let weight: Double?
    public let unitString: String
    public let isWarmup: Bool
    public let rpeString: String
    public let rirString: String
    public let effort: Int?
    public let tagsString: String?
    public let notesString: String?

    public var timestamp: Date? {
        CSVTimestampParser.parse(dateString: dateString, timeString: timeString)
    }

    public init?(values: [String], columns: CSVSchemaV03.Columns) {
        guard
            let sessionID = values[safe: columns.sessionID],
            let dateString = values[safe: columns.date],
            let timeString = values[safe: columns.time],
            let exerciseCode = values[safe: columns.exerciseCode],
            let unitString = values[safe: columns.unit]
        else {
            return nil
        }

        self.sessionID = sessionID
        self.dateString = dateString
        self.timeString = timeString
        self.planName = values[safe: columns.planName] ?? ""
        self.dayLabel = values[safe: columns.dayLabel] ?? ""
        self.segmentID = values[safe: columns.segmentID].flatMap { Int($0) }
        self.supersetID = values[safe: columns.supersetID].flatMap { $0.isEmpty ? nil : $0 }
        self.exerciseCode = exerciseCode
        self.adlib = values[safe: columns.adlib].map { $0 == "1" || $0.lowercased() == "true" } ?? false
        self.setNumber = values[safe: columns.setNumber].flatMap { Int($0) }
        self.repsString = values[safe: columns.reps] ?? ""
        self.timeSec = values[safe: columns.timeSec].flatMap { Int($0) }
        self.weight = values[safe: columns.weight].flatMap { Double($0) }
        self.unitString = unitString
        self.isWarmup = values[safe: columns.isWarmup].map { $0 == "1" || $0.lowercased() == "true" } ?? false
        self.rpeString = values[safe: columns.rpe] ?? ""
        self.rirString = values[safe: columns.rir] ?? ""
        self.effort = values[safe: columns.effort].flatMap { Int($0) }
        self.tagsString = values[safe: columns.tags]
        self.notesString = values[safe: columns.notes]
    }
}

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
    }
}

