//
//  CSVSchemaV03.swift
//  Shared
//
//  Canonical CSV v0.3 schema and column resolution.
//

import Foundation

public enum CSVSchemaV03 {
    public static let header: [String] = [
        "session_id",
        "date",
        "time",
        "plan_name",
        "day_label",
        "segment_id",
        "superset_id",
        "ex_code",
        "adlib",
        "set_num",
        "reps",
        "time_sec",
        "weight",
        "unit",
        "is_warmup",
        "rpe",
        "rir",
        "tempo",
        "rest_sec",
        "effort_1to5",
        "tags",
        "notes",
        "pr_types"
    ]

    public struct Columns: Sendable {
        public let sessionID: Int?
        public let date: Int?
        public let time: Int?
        public let planName: Int?
        public let dayLabel: Int?
        public let segmentID: Int?
        public let supersetID: Int?
        public let exerciseCode: Int?
        public let adlib: Int?
        public let setNumber: Int?
        public let reps: Int?
        public let timeSec: Int?
        public let weight: Int?
        public let unit: Int?
        public let isWarmup: Int?
        public let rpe: Int?
        public let rir: Int?
        public let effort: Int?
        public let tags: Int?
        public let notes: Int?

        public init?(headers: [String]) {
            func index(of name: String) -> Int? {
                headers.firstIndex { $0.lowercased() == name.lowercased() }
            }

            sessionID = index(of: "session_id")
            date = index(of: "date")
            time = index(of: "time")
            planName = index(of: "plan_name")
            dayLabel = index(of: "day_label")
            segmentID = index(of: "segment_id")
            supersetID = index(of: "superset_id")
            exerciseCode = index(of: "ex_code")
            adlib = index(of: "adlib")
            setNumber = index(of: "set_num")
            reps = index(of: "reps")
            timeSec = index(of: "time_sec")
            weight = index(of: "weight")
            unit = index(of: "unit")
            isWarmup = index(of: "is_warmup")
            rpe = index(of: "rpe")
            rir = index(of: "rir")
            effort = index(of: "effort_1to5")
            tags = index(of: "tags")
            notes = index(of: "notes")

            guard sessionID != nil,
                  date != nil,
                  time != nil,
                  exerciseCode != nil,
                  unit != nil
            else {
                return nil
            }
        }
    }
}

