//
//  CsvRow.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

struct CsvRow: Codable, Equatable {
    static let header = "session_id,date,time,plan_name,day_label,segment_id,superset_id,ex_code,adlib,set_num,reps,time_sec,weight,unit,is_warmup,rpe,rir,tempo,rest_sec,effort_1to5,tags,notes,pr_types"

    var sessionID: String
    var dateString: String
    var timeString: String
    var planName: String
    var dayLabel: String
    var segmentID: Int
    var supersetID: String?
    var exerciseCode: String
    var isAdlib: Bool
    var setNumber: Int
    var reps: String
    var timeSec: String
    var weight: String
    var unit: String
    var isWarmup: Bool
    var rpe: String
    var rir: String
    var tempo: String
    var restSec: String
    var effort: Int
    var tags: String
    var notes: String
    var prTypes: String

    init(
        sessionID: String,
        date: Date,
        planName: String,
        dayLabel: String,
        segmentID: Int,
        supersetID: String?,
        exerciseCode: String,
        isAdlib: Bool,
        setNumber: Int,
        reps: String,
        weight: String,
        unit: String,
        isWarmup: Bool,
        effort: Int,
        tags: String = "",
        notes: String = "",
        prTypes: String = ""
    ) {
        self.sessionID = sessionID
        self.dateString = CsvDateFormatter.string(from: date, format: .date)
        self.timeString = CsvDateFormatter.string(from: date, format: .time)
        self.planName = planName
        self.dayLabel = dayLabel
        self.segmentID = segmentID
        self.supersetID = supersetID
        self.exerciseCode = exerciseCode
        self.isAdlib = isAdlib
        self.setNumber = setNumber
        self.reps = reps
        self.timeSec = ""
        self.weight = weight
        self.unit = unit
        self.isWarmup = isWarmup
        self.rpe = ""
        self.rir = ""
        self.tempo = ""
        self.restSec = ""
        self.effort = effort
        self.tags = tags
        self.notes = notes
        self.prTypes = prTypes
    }

    func serialize() -> String {
        let supersetValue = supersetID ?? ""
        let columns: [String] = [
            sessionID,
            dateString,
            timeString,
            planName,
            dayLabel,
            "\(segmentID)",
            supersetValue,
            exerciseCode,
            isAdlib ? "1" : "0",
            "\(setNumber)",
            reps,
            timeSec,
            weight,
            unit,
            isWarmup ? "1" : "0",
            rpe,
            rir,
            tempo,
            restSec,
            "\(effort)",
            tags,
            notes,
            prTypes
        ]
        return columns
            .map { CsvRow.escape($0) }
            .joined(separator: ",")
    }

    static func tombstone(sessionID: String, rowIdentifier: UUID) -> CsvRow {
        var row = CsvRow(
            sessionID: sessionID,
            date: Date(),
            planName: "",
            dayLabel: "",
            segmentID: 0,
            supersetID: nil,
            exerciseCode: "",
            isAdlib: false,
            setNumber: 0,
            reps: "",
            weight: "",
            unit: "",
            isWarmup: false,
            effort: 0
        )
        row.tags = "undo_for:\(rowIdentifier.uuidString.lowercased())"
        return row
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") else {
            return value
        }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

enum CsvTimestampFormat {
    case date
    case time
}

enum CsvDateFormatter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func string(from date: Date, format: CsvTimestampFormat) -> String {
        switch format {
        case .date:
            return dateFormatter.string(from: date)
        case .time:
            return timeFormatter.string(from: date)
        }
    }

    static func date(from dateString: String, timeString: String) -> Date? {
        dateTimeFormatter.date(from: "\(dateString) \(timeString)")
    }
}
