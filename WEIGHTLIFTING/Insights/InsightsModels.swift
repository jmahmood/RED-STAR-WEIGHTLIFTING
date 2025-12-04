//
//  InsightsModels.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-11-02.
//

import Foundation

enum InsightsError: Error {
    case csvMissing
    case planMissing
    case invalidCSV
}

enum CardState<Value: Equatable>: Equatable {
    case loading
    case empty(message: String)
    case error(message: String)
    case ready(Value)
}

struct InsightsSnapshot: Equatable {
    var personalRecords: CardState<[PersonalRecordDisplay]>
    var nextWorkout: CardState<NextWorkoutDisplay>
    var latestDayLabel: String?
    var generatedAt: Date?
}

struct PersonalRecordDisplay: Equatable, Identifiable {
    struct Metric: Equatable {
        enum Kind: String {
            case oneRepMax = "1RM"
            case load = "Load"
            case volume = "Vol"
        }

        let kind: Kind
        let value: Double
        let weight: Double
        let reps: Int
        let date: Date
    }

    let id: String
    let exerciseCode: String
    let exerciseName: String
    let unitSymbol: String?
    let primary: Metric?
    let secondary: Metric?
    let isNew: Bool
    let missingPrimaryMessage: String?
}

struct NextWorkoutDisplay: Equatable {
    struct Line: Equatable, Identifiable {
        let id: String
        let name: String
        let targetReps: String
        let badges: [String]
    }

    let planName: String
    let dayLabel: String
    let lines: [Line]
    let remainingCount: Int
    let timedSetsSkipped: Bool
}

// MARK: - Raw Summary Models

struct PersonalRecordSummary: Codable, Equatable {
    struct FileSignature: Codable, Equatable {
        let sizeBytes: UInt64
        let modificationDate: Date?
    }

    struct Metric: Codable, Equatable {
        let value: Double
        let weight: Double
        let reps: Int
        let date: Date
    }

    struct Entry: Codable, Equatable {
        let exerciseCode: String
        let unit: String
        let load: Metric?
        let volume: Metric?
        let epley: Metric?
    }

    let generatedAt: Date
    let fileSignature: FileSignature
    let sha256: String
    let rowCount: Int
    let entries: [Entry]
    let latestDayLabel: String?
    let latestSessionDate: Date?
}

extension WeightUnit {
    static func fromCSV(_ value: String) -> WeightUnit? {
        switch value.lowercased() {
        case "lb", "lbs", "pound", "pounds":
            return .pounds
        case "kg", "kgs", "kilogram", "kilograms":
            return .kilograms
        default:
            return nil
        }
    }
}
