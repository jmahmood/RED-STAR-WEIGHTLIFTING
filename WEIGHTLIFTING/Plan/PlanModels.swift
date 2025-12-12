//
//  PlanModels.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-31.
//

import Foundation

public enum WeightUnit: String, Codable, Hashable {
    case pounds = "lb"
    case kilograms = "kg"

    init(planString: String) {
        switch planString.lowercased() {
        case "kg", "kgs", "kilogram", "kilograms":
            self = .kilograms
        default:
            self = .pounds
        }
    }

    var csvValue: String { rawValue }
    var displaySymbol: String {
        switch self {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        }
    }
}

public struct PlanV03: Codable {
    public enum Segment: Codable, Equatable {
        case straight(StraightSegment)
        case scheme(SchemeSegment)
        case superset(SupersetSegment)
        case percentage(PercentageSegment)  // V0.4: CRITICAL for 5-3-1
        case unsupported(String)

        private enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawType = try container.decode(String.self, forKey: .type)

            switch rawType {
            case "straight":
                let segment = try StraightSegment(from: decoder)
                self = .straight(segment)
            case "scheme":
                let segment = try SchemeSegment(from: decoder)
                self = .scheme(segment)
            case "superset":
                let segment = try SupersetSegment(from: decoder)
                self = .superset(segment)
            case "percentage":
                let segment = try PercentageSegment(from: decoder)
                self = .percentage(segment)
            default:
                self = .unsupported(rawType)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .straight(let segment):
                try container.encode("straight", forKey: .type)
                try segment.encode(to: encoder)
            case .scheme(let segment):
                try container.encode("scheme", forKey: .type)
                try segment.encode(to: encoder)
            case .superset(let segment):
                try container.encode("superset", forKey: .type)
                try segment.encode(to: encoder)
            case .percentage(let segment):
                try container.encode("percentage", forKey: .type)
                try segment.encode(to: encoder)
            case .unsupported(let type):
                try container.encode(type, forKey: .type)
            }
        }
    }

    public struct Day: Codable, Equatable {
        public let label: String
        public let segments: [Segment]
        public let dayNumber: Int?

        private enum CodingKeys: String, CodingKey {
            case label
            case segments
            case day
        }

        public init(label: String, segments: [Segment], dayNumber: Int? = nil) {
            self.label = label
            self.segments = segments
            self.dayNumber = dayNumber
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = try container.decode(String.self, forKey: .label)
            segments = try container.decode([Segment].self, forKey: .segments)
            dayNumber = try container.decodeIfPresent(Int.self, forKey: .day)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(label, forKey: .label)
            try container.encode(segments, forKey: .segments)
            if let dayNumber {
                try container.encode(dayNumber, forKey: .day)
            }
        }
    }

    public struct StraightSegment: Codable, Equatable {
        public let exerciseCode: String
        public let altGroup: String?
        public let sets: Int
        public let reps: RepetitionRange?
        public let restSec: Int?
        public let rpe: Double?
        public let intensifier: Intensifier?
        public let timeSec: Int?
        public let tags: [String]?
        // V0.4 additions
        public let perWeek: [String: PartialSegment]?
        public let groupRole: String?
        public let loadAxisTarget: LoadAxisTarget?

        private enum CodingKeys: String, CodingKey {
            case exerciseCode = "ex"
            case exerciseCodeAlt = "exercise_code"
            case altGroup = "alt_group"
            case sets
            case reps
            case restSec = "rest_sec"
            case rpe
            case intensifier
            case timeSec = "time_sec"
            case tags
            // V0.4 keys
            case perWeek = "per_week"
            case groupRole = "group_role"
            case loadAxisTarget = "load_axis_target"
        }

        public init(
            exerciseCode: String,
            altGroup: String?,
            sets: Int,
            reps: RepetitionRange?,
            restSec: Int?,
            rpe: Double?,
            intensifier: Intensifier?,
            timeSec: Int?,
            tags: [String]?,
            perWeek: [String: PartialSegment]? = nil,
            groupRole: String? = nil,
            loadAxisTarget: LoadAxisTarget? = nil
        ) {
            self.exerciseCode = exerciseCode
            self.altGroup = altGroup
            self.sets = sets
            self.reps = reps
            self.restSec = restSec
            self.rpe = rpe
            self.intensifier = intensifier
            self.timeSec = timeSec
            self.tags = tags
            self.perWeek = perWeek
            self.groupRole = groupRole
            self.loadAxisTarget = loadAxisTarget
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exerciseCode = (try? container.decodeIfPresent(String.self, forKey: .exerciseCode))
                ?? (try? container.decodeIfPresent(String.self, forKey: .exerciseCodeAlt))
                ?? ""
            altGroup = try container.decodeIfPresent(String.self, forKey: .altGroup)
            sets = try container.decodeIfPresent(Int.self, forKey: .sets) ?? 1
            reps = try container.decodeIfPresent(RepetitionRange.self, forKey: .reps)
            restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
            rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
            intensifier = try container.decodeIfPresent(Intensifier.self, forKey: .intensifier)
            timeSec = try container.decodeIfPresent(Int.self, forKey: .timeSec)
            tags = try container.decodeIfPresent([String].self, forKey: .tags)
            // V0.4 fields (backwards compatible)
            perWeek = try container.decodeIfPresent([String: PartialSegment].self, forKey: .perWeek)
            groupRole = try container.decodeIfPresent(String.self, forKey: .groupRole)
            loadAxisTarget = try container.decodeIfPresent(LoadAxisTarget.self, forKey: .loadAxisTarget)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(exerciseCode, forKey: .exerciseCode)
            if let altGroup { try container.encode(altGroup, forKey: .altGroup) }
            try container.encode(sets, forKey: .sets)
            if let reps { try container.encode(reps, forKey: .reps) }
            if let restSec { try container.encode(restSec, forKey: .restSec) }
            if let rpe { try container.encode(rpe, forKey: .rpe) }
            if let intensifier { try container.encode(intensifier, forKey: .intensifier) }
            if let timeSec { try container.encode(timeSec, forKey: .timeSec) }
            if let tags { try container.encode(tags, forKey: .tags) }
            // V0.4 fields
            if let perWeek { try container.encode(perWeek, forKey: .perWeek) }
            if let groupRole { try container.encode(groupRole, forKey: .groupRole) }
            if let loadAxisTarget { try container.encode(loadAxisTarget, forKey: .loadAxisTarget) }
        }
    }

    public struct SchemeSegment: Codable, Equatable {
        public struct Entry: Codable, Equatable {
            public let label: String?
            public let sets: Int
            public let reps: RepetitionRange?
            public let restSec: Int?
            public let intensifier: Intensifier?

        private enum CodingKeys: String, CodingKey {
            case label
            case sets
            case reps
            case restSec
            case intensifier
        }

        public init(
            label: String?,
            sets: Int,
            reps: RepetitionRange?,
            restSec: Int?,
            intensifier: Intensifier?
        ) {
            self.label = label
            self.sets = sets
            self.reps = reps
            self.restSec = restSec
            self.intensifier = intensifier
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            sets = try container.decodeIfPresent(Int.self, forKey: .sets) ?? 1
            reps = try container.decodeIfPresent(RepetitionRange.self, forKey: .reps)
            restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
            intensifier = try container.decodeIfPresent(Intensifier.self, forKey: .intensifier)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let label { try container.encode(label, forKey: .label) }
            try container.encode(sets, forKey: .sets)
            if let reps { try container.encode(reps, forKey: .reps) }
            if let restSec { try container.encode(restSec, forKey: .restSec) }
            if let intensifier { try container.encode(intensifier, forKey: .intensifier) }
        }
    }

        public let exerciseCode: String
        public let altGroup: String?
        public let entries: [Entry]
        public let restSec: Int?
        public let intensifier: Intensifier?
        // V0.4 additions
        public let perWeek: [String: PartialSegment]?
        public let groupRole: String?
        public let loadAxisTarget: LoadAxisTarget?

        private enum CodingKeys: String, CodingKey {
            case exerciseCode = "ex"
            case exerciseCodeAlt = "exercise_code"
            case altGroup = "alt_group"
            case entries = "entries"
            case entriesAlt = "sets"
            case restSec = "rest_sec"
            case intensifier
            // V0.4 keys
            case perWeek = "per_week"
            case groupRole = "group_role"
            case loadAxisTarget = "load_axis_target"
        }

        public init(
            exerciseCode: String,
            altGroup: String?,
            entries: [Entry],
            restSec: Int?,
            intensifier: Intensifier?,
            perWeek: [String: PartialSegment]? = nil,
            groupRole: String? = nil,
            loadAxisTarget: LoadAxisTarget? = nil
        ) {
            self.exerciseCode = exerciseCode
            self.altGroup = altGroup
            self.entries = entries
            self.restSec = restSec
            self.intensifier = intensifier
            self.perWeek = perWeek
            self.groupRole = groupRole
            self.loadAxisTarget = loadAxisTarget
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exerciseCode = (try? container.decodeIfPresent(String.self, forKey: .exerciseCode))
                ?? (try? container.decodeIfPresent(String.self, forKey: .exerciseCodeAlt))
                ?? ""
            altGroup = try container.decodeIfPresent(String.self, forKey: .altGroup)
            let decodedEntries = (try? container.decodeIfPresent([Entry].self, forKey: .entries))
                ?? (try? container.decodeIfPresent([Entry].self, forKey: .entriesAlt))
                ?? []
            entries = decodedEntries
            restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
            intensifier = try container.decodeIfPresent(Intensifier.self, forKey: .intensifier)
            // V0.4 fields (backwards compatible)
            perWeek = try container.decodeIfPresent([String: PartialSegment].self, forKey: .perWeek)
            groupRole = try container.decodeIfPresent(String.self, forKey: .groupRole)
            loadAxisTarget = try container.decodeIfPresent(LoadAxisTarget.self, forKey: .loadAxisTarget)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(exerciseCode, forKey: .exerciseCode)
            if let altGroup { try container.encode(altGroup, forKey: .altGroup) }
            try container.encode(entries, forKey: .entries)
            if let restSec { try container.encode(restSec, forKey: .restSec) }
            if let intensifier { try container.encode(intensifier, forKey: .intensifier) }
            // V0.4 fields
            if let perWeek { try container.encode(perWeek, forKey: .perWeek) }
            if let groupRole { try container.encode(groupRole, forKey: .groupRole) }
            if let loadAxisTarget { try container.encode(loadAxisTarget, forKey: .loadAxisTarget) }
        }
    }

    public struct SupersetSegment: Codable, Equatable {
        public struct Item: Codable, Equatable {
            public let exerciseCode: String
            public let altGroup: String?
            public let sets: Int
            public let reps: RepetitionRange?
            public let restSec: Int?
            public let intensifier: Intensifier?
            // V0.4 additions (CONFIRMED)
            public let perWeek: [String: PartialSegment]?
            public let groupRole: String?
            public let loadAxisTarget: LoadAxisTarget?

        private enum CodingKeys: String, CodingKey {
            case exerciseCode = "ex"
            case exerciseCodeAlt = "exercise_code"
            case altGroup = "alt_group"
            case sets
            case reps
            case restSec = "rest_sec"
            case intensifier
            // V0.4 keys
            case perWeek = "per_week"
            case groupRole = "group_role"
            case loadAxisTarget = "load_axis_target"
        }

            public init(
                exerciseCode: String,
                altGroup: String?,
                sets: Int,
                reps: RepetitionRange?,
                restSec: Int?,
                intensifier: Intensifier?,
                perWeek: [String: PartialSegment]? = nil,
                groupRole: String? = nil,
                loadAxisTarget: LoadAxisTarget? = nil
        ) {
            self.exerciseCode = exerciseCode
            self.altGroup = altGroup
            self.sets = sets
            self.reps = reps
            self.restSec = restSec
            self.intensifier = intensifier
            self.perWeek = perWeek
            self.groupRole = groupRole
            self.loadAxisTarget = loadAxisTarget
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exerciseCode = (try? container.decodeIfPresent(String.self, forKey: .exerciseCode))
                ?? (try? container.decodeIfPresent(String.self, forKey: .exerciseCodeAlt))
                ?? ""
            altGroup = try container.decodeIfPresent(String.self, forKey: .altGroup)
            sets = try container.decodeIfPresent(Int.self, forKey: .sets) ?? 1
            reps = try container.decodeIfPresent(RepetitionRange.self, forKey: .reps)
            restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
            intensifier = try container.decodeIfPresent(Intensifier.self, forKey: .intensifier)
            // V0.4 fields (backwards compatible)
            perWeek = try container.decodeIfPresent([String: PartialSegment].self, forKey: .perWeek)
            groupRole = try container.decodeIfPresent(String.self, forKey: .groupRole)
            loadAxisTarget = try container.decodeIfPresent(LoadAxisTarget.self, forKey: .loadAxisTarget)
            }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(exerciseCode, forKey: .exerciseCode)
            if let altGroup { try container.encode(altGroup, forKey: .altGroup) }
            try container.encode(sets, forKey: .sets)
            if let reps { try container.encode(reps, forKey: .reps) }
            if let restSec { try container.encode(restSec, forKey: .restSec) }
            if let intensifier { try container.encode(intensifier, forKey: .intensifier) }
            // V0.4 fields
            if let perWeek { try container.encode(perWeek, forKey: .perWeek) }
            if let groupRole { try container.encode(groupRole, forKey: .groupRole) }
            if let loadAxisTarget { try container.encode(loadAxisTarget, forKey: .loadAxisTarget) }
        }
        }

        public let label: String?
        public let rounds: Int
        public let items: [Item]
        public let restSec: Int?
        public let restBetweenRoundsSec: Int?

        private enum CodingKeys: String, CodingKey {
            case label
            case rounds
            case items
            case restSec
            case restBetweenRoundsSec
        }

        public init(
            label: String?,
            rounds: Int,
            items: [Item],
            restSec: Int?,
            restBetweenRoundsSec: Int?
        ) {
            self.label = label
            self.rounds = rounds
            self.items = items
            self.restSec = restSec
            self.restBetweenRoundsSec = restBetweenRoundsSec
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            rounds = try container.decodeIfPresent(Int.self, forKey: .rounds) ?? 1
            items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
            restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
            restBetweenRoundsSec = try container.decodeIfPresent(Int.self, forKey: .restBetweenRoundsSec)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let label { try container.encode(label, forKey: .label) }
            try container.encode(rounds, forKey: .rounds)
            try container.encode(items, forKey: .items)
            if let restSec { try container.encode(restSec, forKey: .restSec) }
            if let restBetweenRoundsSec { try container.encode(restBetweenRoundsSec, forKey: .restBetweenRoundsSec) }
        }
    }

    // V0.4: PercentageSegment (CRITICAL for 5-3-1 support)
    public struct PercentageSegment: Codable, Equatable {
        public let exerciseCode: String
        public let prescriptions: [PercentagePrescription]
        // V0.4: per_week support for week-dependent percentages
        public let perWeek: [String: PercentageOverlay]?

        private enum CodingKeys: String, CodingKey {
            case exerciseCode = "ex"
            case exerciseCodeAlt = "exercise_code"
            case prescriptions
            case perWeek = "per_week"
        }

        public init(
            exerciseCode: String,
            prescriptions: [PercentagePrescription],
            perWeek: [String: PercentageOverlay]? = nil
        ) {
            self.exerciseCode = exerciseCode
            self.prescriptions = prescriptions
            self.perWeek = perWeek
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exerciseCode = (try? container.decodeIfPresent(String.self, forKey: .exerciseCode))
                ?? (try? container.decodeIfPresent(String.self, forKey: .exerciseCodeAlt))
                ?? ""
            prescriptions = try container.decodeIfPresent([PercentagePrescription].self, forKey: .prescriptions) ?? []
            // V0.4 field (backwards compatible)
            perWeek = try container.decodeIfPresent([String: PercentageOverlay].self, forKey: .perWeek)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(exerciseCode, forKey: .exerciseCode)
            try container.encode(prescriptions, forKey: .prescriptions)
            if let perWeek { try container.encode(perWeek, forKey: .perWeek) }
        }
    }

    public struct RepetitionRange: Codable, Hashable {
        public let min: Int?
        public let max: Int?
        public let text: String?

        private enum CodingKeys: String, CodingKey {
            case min
            case max
            case text
        }

        public init(min: Int?, max: Int?, text: String?) {
            self.min = min
            self.max = max
            self.text = text
        }

        public init(from decoder: Decoder) throws {
            if let container = try? decoder.container(keyedBy: CodingKeys.self) {
                let min = try container.decodeIfPresent(Int.self, forKey: .min)
                let max = try container.decodeIfPresent(Int.self, forKey: .max)
                let text = try container.decodeIfPresent(String.self, forKey: .text)
                self.init(min: min, max: max, text: text)
            } else {
                let single = try decoder.singleValueContainer()
                if let value = try? single.decode(Int.self) {
                    self.init(min: value, max: value, text: nil)
                } else if let value = try? single.decode(String.self) {
                    self.init(min: nil, max: nil, text: value)
                } else {
                    self.init(min: nil, max: nil, text: nil)
                }
            }
        }

        public func encode(to encoder: Encoder) throws {
            // If text exists, encode as string
            if let text {
                var container = encoder.singleValueContainer()
                try container.encode(text)
            }
            // If min == max, encode as single Int
            else if let min, let max, min == max {
                var container = encoder.singleValueContainer()
                try container.encode(min)
            }
            // Otherwise, encode as object with min/max
            else {
                var container = encoder.container(keyedBy: CodingKeys.self)
                if let min { try container.encode(min, forKey: .min) }
                if let max { try container.encode(max, forKey: .max) }
            }
        }

        var displayText: String {
            if let text {
                return text
            }

            switch (min, max) {
            case let (min?, max?) where min == max:
                return "\(min)"
            case let (min?, max?):
                return "\(min)-\(max)"
            case (.some(let min), nil):
                return "\(min)+"
            case (nil, .some(let max)):
                return "≤\(max)"
            default:
                return "Reps"
            }
        }
    }

    public struct Intensifier: Codable, Equatable {
        public enum Kind: String, Codable {
            case dropset
            case amrap
            case unknown
        }

        public let kind: Kind
        public let when: String?
        public let dropPct: Double?
        public let steps: Int?

        public init(kind: Kind, when: String?, dropPct: Double?, steps: Int?) {
            self.kind = kind
            self.when = when
            self.dropPct = dropPct
            self.steps = steps
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawKind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "unknown"
            let kind = Kind(rawValue: rawKind) ?? .unknown
            let when = try container.decodeIfPresent(String.self, forKey: .when)
            let dropPct = try container.decodeIfPresent(Double.self, forKey: .dropPct)
            let steps = try container.decodeIfPresent(Int.self, forKey: .steps)
            self.init(kind: kind, when: when, dropPct: dropPct, steps: steps)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind.rawValue, forKey: .kind)
            if let when { try container.encode(when, forKey: .when) }
            if let dropPct { try container.encode(dropPct, forKey: .dropPct) }
            if let steps { try container.encode(steps, forKey: .steps) }
        }

        private enum CodingKeys: String, CodingKey {
            case kind
            case when
            case dropPct
            case steps
        }
    }

    // MARK: - V0.4 New Types

    /// Load axis target for a segment
    public struct LoadAxisTarget: Codable, Equatable, Hashable {
        public let axis: String
        public let target: String?

        private enum CodingKeys: String, CodingKey {
            case axis
            case target
        }

        public init(axis: String, target: String?) {
            self.axis = axis
            self.target = target
        }
    }

    /// Per-week overlay for straight/scheme/superset segments
    public struct PartialSegment: Codable, Equatable {
        public let sets: Int?
        public let reps: RepetitionRange?
        public let restSec: Int?
        public let rpe: Double?
        public let intensifier: Intensifier?
        public let timeSec: Int?

        private enum CodingKeys: String, CodingKey {
            case sets
            case reps
            case restSec = "rest_sec"
            case rpe
            case intensifier
            case timeSec = "time_sec"
        }
    }

    /// Group variant configuration (curated fields only)
    /// Can override: sets, reps, restSec, intensifier
    /// CANNOT override: rpe, timeSec, loadAxisTarget
    public struct GroupVariantConfig: Codable, Equatable {
        public let sets: Int?
        public let reps: RepetitionRange?
        public let restSec: Int?
        public let intensifier: Intensifier?

        private enum CodingKeys: String, CodingKey {
            case sets
            case reps
            case restSec = "rest_sec"
            case intensifier
        }
    }

    /// Exercise metadata including load axes
    public struct ExerciseMeta: Codable, Equatable {
        public let loadAxes: [String: LoadAxis]?

        private enum CodingKeys: String, CodingKey {
            case loadAxes = "load_axes"
        }
    }

    /// Load axis definition
    public struct LoadAxis: Codable, Equatable, Hashable {
        public enum AxisType: String, Codable {
            case categorical
            case ordinal
        }

        public let type: AxisType
        public let values: [String]

        private enum CodingKeys: String, CodingKey {
            case type = "kind"  // JSON uses "kind", Swift uses "type"
            case values
        }
    }

    /// Per-week overlay for percentage segments (CRITICAL for 5-3-1)
    public struct PercentageOverlay: Codable, Equatable {
        public let prescriptions: [PercentagePrescription]?

        private enum CodingKeys: String, CodingKey {
            case prescriptions
        }
    }

    /// Percentage prescription
    public struct PercentagePrescription: Codable, Equatable {
        public let sets: Int
        public let reps: RepetitionRange
        public let pctRM: Double
        public let intensifier: Intensifier?

        private enum CodingKeys: String, CodingKey {
            case sets
            case reps
            case pctRM = "pct_1rm"
            case intensifier
        }
    }

    /// Phase configuration for multi-week programs
    public struct Phase: Codable, Equatable {
        public let index: Int
        public let weeks: [Int]

        private enum CodingKeys: String, CodingKey {
            case index
            case weeks
        }
    }

    public let planName: String
    public let unit: WeightUnit
    public let exerciseNames: [String: String]
    public let altGroups: [String: [String]]
    public let days: [Day]
    public let scheduleOrder: [String]
    // V0.4 additions
    public let exerciseMeta: [String: ExerciseMeta]
    public let groupVariants: [String: [String: [String: GroupVariantConfig]]]
    public let phase: Phase?

    private enum CodingKeys: String, CodingKey {
        case name
        case unit
        case dictionary
        case groups
        case schedule
        // Legacy / alt keys
        case planName = "plan_name"
        case exerciseNames = "exercise_names"
        case altGroups = "alt_groups"
        case days
        // V0.4 keys
        case exerciseMeta = "exercise_meta"
        case groupVariants = "group_variants"
        case phase
    }

    public init(
        planName: String,
        unit: WeightUnit,
        exerciseNames: [String: String],
        altGroups: [String: [String]],
        days: [Day],
        scheduleOrder: [String],
        exerciseMeta: [String: ExerciseMeta] = [:],
        groupVariants: [String: [String: [String: GroupVariantConfig]]] = [:],
        phase: Phase? = nil
    ) {
        self.planName = planName
        self.unit = unit
        self.exerciseNames = exerciseNames
        self.altGroups = altGroups
        self.days = days
        self.scheduleOrder = scheduleOrder
        self.exerciseMeta = exerciseMeta
        self.groupVariants = groupVariants
        self.phase = phase
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planName = (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? (try? container.decodeIfPresent(String.self, forKey: .planName))
            ?? "Program"

        let unitString = (try container.decodeIfPresent(String.self, forKey: .unit)) ?? "lb"
        unit = WeightUnit(planString: unitString)

        exerciseNames = (try? container.decodeIfPresent([String: String].self, forKey: .dictionary))
            ?? (try? container.decodeIfPresent([String: String].self, forKey: .exerciseNames))
            ?? [:]

        altGroups = (try? container.decodeIfPresent([String: [String]].self, forKey: .groups))
            ?? (try? container.decodeIfPresent([String: [String]].self, forKey: .altGroups))
            ?? [:]

        let decodedDays: [Day]
        if container.contains(.schedule) {
            decodedDays = try container.decode([Day].self, forKey: .schedule)
        } else if container.contains(.days) {
            decodedDays = try container.decode([Day].self, forKey: .days)
        } else {
            decodedDays = []
        }
        days = decodedDays
        scheduleOrder = decodedDays.map { $0.label }

        // V0.4 fields (backwards compatible defaults)
        exerciseMeta = (try? container.decodeIfPresent([String: ExerciseMeta].self, forKey: .exerciseMeta)) ?? [:]
        groupVariants = (try? container.decodeIfPresent([String: [String: [String: GroupVariantConfig]]].self, forKey: .groupVariants)) ?? [:]
        phase = try? container.decodeIfPresent(Phase.self, forKey: .phase)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Use canonical keys for encoding
        try container.encode(planName, forKey: .name)
        try container.encode(unit, forKey: .unit)
        try container.encode(exerciseNames, forKey: .dictionary)
        try container.encode(altGroups, forKey: .groups)
        try container.encode(days, forKey: .schedule)
        // V0.4 fields
        if !exerciseMeta.isEmpty {
            try container.encode(exerciseMeta, forKey: .exerciseMeta)
        }
        if !groupVariants.isEmpty {
            try container.encode(groupVariants, forKey: .groupVariants)
        }
        if let phase {
            try container.encode(phase, forKey: .phase)
        }
    }

    func day(named label: String) -> Day? {
        days.first { $0.label == label }
    }
}

// MARK: - PlanV03 Copy-on-Write Helpers

extension PlanV03 {
    func withPlanName(_ name: String) -> PlanV03 {
        PlanV03(
            planName: name,
            unit: unit,
            exerciseNames: exerciseNames,
            altGroups: altGroups,
            days: days,
            scheduleOrder: scheduleOrder,
            exerciseMeta: exerciseMeta,
            groupVariants: groupVariants,
            phase: phase
        )
    }

    func withUnit(_ newUnit: WeightUnit) -> PlanV03 {
        PlanV03(
            planName: planName,
            unit: newUnit,
            exerciseNames: exerciseNames,
            altGroups: altGroups,
            days: days,
            scheduleOrder: scheduleOrder,
            exerciseMeta: exerciseMeta,
            groupVariants: groupVariants,
            phase: phase
        )
    }

    func withExerciseNames(_ names: [String: String]) -> PlanV03 {
        PlanV03(
            planName: planName,
            unit: unit,
            exerciseNames: names,
            altGroups: altGroups,
            days: days,
            scheduleOrder: scheduleOrder,
            exerciseMeta: exerciseMeta,
            groupVariants: groupVariants,
            phase: phase
        )
    }

    func withAltGroups(_ groups: [String: [String]]) -> PlanV03 {
        PlanV03(
            planName: planName,
            unit: unit,
            exerciseNames: exerciseNames,
            altGroups: groups,
            days: days,
            scheduleOrder: scheduleOrder,
            exerciseMeta: exerciseMeta,
            groupVariants: groupVariants,
            phase: phase
        )
    }

    func withDays(_ newDays: [Day]) -> PlanV03 {
        PlanV03(
            planName: planName,
            unit: unit,
            exerciseNames: exerciseNames,
            altGroups: altGroups,
            days: newDays,
            scheduleOrder: scheduleOrder,
            exerciseMeta: exerciseMeta,
            groupVariants: groupVariants,
            phase: phase
        )
    }

    func withScheduleOrder(_ order: [String]) -> PlanV03 {
        PlanV03(
            planName: planName,
            unit: unit,
            exerciseNames: exerciseNames,
            altGroups: altGroups,
            days: days,
            scheduleOrder: order,
            exerciseMeta: exerciseMeta,
            groupVariants: groupVariants,
            phase: phase
        )
    }

    func withExerciseMeta(_ meta: [String: ExerciseMeta]) -> PlanV03 {
        PlanV03(
            planName: planName,
            unit: unit,
            exerciseNames: exerciseNames,
            altGroups: altGroups,
            days: days,
            scheduleOrder: scheduleOrder,
            exerciseMeta: meta,
            groupVariants: groupVariants,
            phase: phase
        )
    }

    func withGroupVariants(_ variants: [String: [String: [String: GroupVariantConfig]]]) -> PlanV03 {
        PlanV03(
            planName: planName,
            unit: unit,
            exerciseNames: exerciseNames,
            altGroups: altGroups,
            days: days,
            scheduleOrder: scheduleOrder,
            exerciseMeta: exerciseMeta,
            groupVariants: variants,
            phase: phase
        )
    }

    func withPhase(_ newPhase: Phase?) -> PlanV03 {
        PlanV03(
            planName: planName,
            unit: unit,
            exerciseNames: exerciseNames,
            altGroups: altGroups,
            days: days,
            scheduleOrder: scheduleOrder,
            exerciseMeta: exerciseMeta,
            groupVariants: groupVariants,
            phase: newPhase
        )
    }
}
