//
//  PlanModels.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-31.
//

import Foundation

enum WeightUnit: String, Codable, Hashable {
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

struct PlanV03: Decodable {
    enum Segment: Decodable, Equatable {
        case straight(StraightSegment)
        case scheme(SchemeSegment)
        case superset(SupersetSegment)
        case unsupported(String)

        private enum CodingKeys: String, CodingKey {
            case type
        }

        init(from decoder: Decoder) throws {
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
            default:
                self = .unsupported(rawType)
            }
        }
    }

    struct Day: Decodable, Equatable {
        let label: String
        let segments: [Segment]
        let dayNumber: Int?

        private enum CodingKeys: String, CodingKey {
            case label
            case segments
            case day
        }

        init(label: String, segments: [Segment], dayNumber: Int? = nil) {
            self.label = label
            self.segments = segments
            self.dayNumber = dayNumber
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = try container.decode(String.self, forKey: .label)
            segments = try container.decode([Segment].self, forKey: .segments)
            dayNumber = try container.decodeIfPresent(Int.self, forKey: .day)
        }
    }

    struct StraightSegment: Decodable, Equatable {
        let exerciseCode: String
        let altGroup: String?
        let sets: Int
        let reps: RepetitionRange?
        let restSec: Int?
        let rpe: Double?
        let intensifier: Intensifier?
        let timeSec: Int?
        let tags: [String]?

        private enum CodingKeys: String, CodingKey {
            case exerciseCode = "ex"
            case altGroup
            case sets
            case reps
            case restSec
            case rpe
            case intensifier
            case timeSec
            case tags
        }

        init(
            exerciseCode: String,
            altGroup: String?,
            sets: Int,
            reps: RepetitionRange?,
            restSec: Int?,
            rpe: Double?,
            intensifier: Intensifier?,
            timeSec: Int?,
            tags: [String]?
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
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exerciseCode = try container.decode(String.self, forKey: .exerciseCode)
            altGroup = try container.decodeIfPresent(String.self, forKey: .altGroup)
            sets = try container.decodeIfPresent(Int.self, forKey: .sets) ?? 1
            reps = try container.decodeIfPresent(RepetitionRange.self, forKey: .reps)
            restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
            rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
            intensifier = try container.decodeIfPresent(Intensifier.self, forKey: .intensifier)
            timeSec = try container.decodeIfPresent(Int.self, forKey: .timeSec)
            tags = try container.decodeIfPresent([String].self, forKey: .tags)
        }
    }

    struct SchemeSegment: Decodable, Equatable {
        struct Entry: Decodable, Equatable {
            let label: String?
            let sets: Int
            let reps: RepetitionRange?
            let restSec: Int?
            let intensifier: Intensifier?

            private enum CodingKeys: String, CodingKey {
                case label
                case sets
                case reps
                case restSec
                case intensifier
            }

            init(
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

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                label = try container.decodeIfPresent(String.self, forKey: .label)
                sets = try container.decodeIfPresent(Int.self, forKey: .sets) ?? 1
                reps = try container.decodeIfPresent(RepetitionRange.self, forKey: .reps)
                restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
                intensifier = try container.decodeIfPresent(Intensifier.self, forKey: .intensifier)
            }
        }

        let exerciseCode: String
        let altGroup: String?
        let entries: [Entry]
        let restSec: Int?
        let intensifier: Intensifier?

        private enum CodingKeys: String, CodingKey {
            case exerciseCode = "ex"
            case altGroup
            case entries = "sets"
            case restSec
            case intensifier
        }

        init(
            exerciseCode: String,
            altGroup: String?,
            entries: [Entry],
            restSec: Int?,
            intensifier: Intensifier?
        ) {
            self.exerciseCode = exerciseCode
            self.altGroup = altGroup
            self.entries = entries
            self.restSec = restSec
            self.intensifier = intensifier
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exerciseCode = try container.decode(String.self, forKey: .exerciseCode)
            altGroup = try container.decodeIfPresent(String.self, forKey: .altGroup)
            entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
            restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
            intensifier = try container.decodeIfPresent(Intensifier.self, forKey: .intensifier)
        }
    }

    struct SupersetSegment: Decodable, Equatable {
        struct Item: Decodable, Equatable {
            let exerciseCode: String
            let altGroup: String?
            let sets: Int
            let reps: RepetitionRange?
            let restSec: Int?
            let intensifier: Intensifier?

            private enum CodingKeys: String, CodingKey {
                case exerciseCode = "ex"
                case altGroup
                case sets
                case reps
                case restSec
                case intensifier
            }

            init(
                exerciseCode: String,
                altGroup: String?,
                sets: Int,
                reps: RepetitionRange?,
                restSec: Int?,
                intensifier: Intensifier?
            ) {
                self.exerciseCode = exerciseCode
                self.altGroup = altGroup
                self.sets = sets
                self.reps = reps
                self.restSec = restSec
                self.intensifier = intensifier
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                exerciseCode = try container.decode(String.self, forKey: .exerciseCode)
                altGroup = try container.decodeIfPresent(String.self, forKey: .altGroup)
                sets = try container.decodeIfPresent(Int.self, forKey: .sets) ?? 1
                reps = try container.decodeIfPresent(RepetitionRange.self, forKey: .reps)
                restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
                intensifier = try container.decodeIfPresent(Intensifier.self, forKey: .intensifier)
            }
        }

        let label: String?
        let rounds: Int
        let items: [Item]
        let restSec: Int?
        let restBetweenRoundsSec: Int?

        private enum CodingKeys: String, CodingKey {
            case label
            case rounds
            case items
            case restSec
            case restBetweenRoundsSec
        }

        init(
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            rounds = try container.decodeIfPresent(Int.self, forKey: .rounds) ?? 1
            items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
            restSec = try container.decodeIfPresent(Int.self, forKey: .restSec)
            restBetweenRoundsSec = try container.decodeIfPresent(Int.self, forKey: .restBetweenRoundsSec)
        }
    }

    struct RepetitionRange: Decodable, Hashable {
        let min: Int?
        let max: Int?
        let text: String?

        private enum CodingKeys: String, CodingKey {
            case min
            case max
            case text
        }

        init(min: Int?, max: Int?, text: String?) {
            self.min = min
            self.max = max
            self.text = text
        }

        init(from decoder: Decoder) throws {
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

    struct Intensifier: Decodable, Equatable {
        enum Kind: String, Decodable {
            case dropset
            case amrap
            case unknown
        }

        let kind: Kind
        let when: String?
        let dropPct: Double?
        let steps: Int?

        init(kind: Kind, when: String?, dropPct: Double?, steps: Int?) {
            self.kind = kind
            self.when = when
            self.dropPct = dropPct
            self.steps = steps
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawKind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "unknown"
            let kind = Kind(rawValue: rawKind) ?? .unknown
            let when = try container.decodeIfPresent(String.self, forKey: .when)
            let dropPct = try container.decodeIfPresent(Double.self, forKey: .dropPct)
            let steps = try container.decodeIfPresent(Int.self, forKey: .steps)
            self.init(kind: kind, when: when, dropPct: dropPct, steps: steps)
        }

        private enum CodingKeys: String, CodingKey {
            case kind
            case when
            case dropPct
            case steps
        }
    }

    let planName: String
    let unit: WeightUnit
    let exerciseNames: [String: String]
    let altGroups: [String: [String]]
    let days: [Day]
    let scheduleOrder: [String]

    private enum CodingKeys: String, CodingKey {
        case name
        case unit
        case dictionary
        case groups
        case schedule
    }

    init(
        planName: String,
        unit: WeightUnit,
        exerciseNames: [String: String],
        altGroups: [String: [String]],
        days: [Day],
        scheduleOrder: [String]
    ) {
        self.planName = planName
        self.unit = unit
        self.exerciseNames = exerciseNames
        self.altGroups = altGroups
        self.days = days
        self.scheduleOrder = scheduleOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planName = try container.decode(String.self, forKey: .name)
        let unitString = (try container.decodeIfPresent(String.self, forKey: .unit)) ?? "lb"
        unit = WeightUnit(planString: unitString)
        exerciseNames = try container.decodeIfPresent([String: String].self, forKey: .dictionary) ?? [:]
        altGroups = try container.decodeIfPresent([String: [String]].self, forKey: .groups) ?? [:]
        let decodedDays = try container.decode([Day].self, forKey: .schedule)
        days = decodedDays
        scheduleOrder = decodedDays.map { $0.label }
    }

    func day(named label: String) -> Day? {
        days.first { $0.label == label }
    }
}
