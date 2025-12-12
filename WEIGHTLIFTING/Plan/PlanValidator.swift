//
//  PlanValidator.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-31.
//

import CryptoKit
import Foundation

public struct PlanSummary: Equatable {
    public let planName: String
    public let unit: WeightUnit
    public let dayCount: Int
    public let scheduleOrder: [String]
    public let unsupportedSegmentTypes: [String]
    public let warnings: [String]
    public let sha256: String
}

public enum PlanValidationError: Error {
    case emptyData
    case decodingFailed(Error)
    case missingDays
    // Tier 1 validation errors
    case exerciseCodeNotInDictionary(String, dayLabel: String)
    case invalidSets(Int, exerciseCode: String, dayLabel: String)
    case invalidReps(exerciseCode: String, dayLabel: String, reason: String)
}

public struct PlanValidationResult {
    public let summary: PlanSummary
    public let plan: PlanV03
}

public enum PlanValidator {
    public static func validate(data: Data) throws -> PlanValidationResult {
        guard !data.isEmpty else { throw PlanValidationError.emptyData }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        let plan: PlanV03
        do {
            plan = try decoder.decode(PlanV03.self, from: data)
        } catch {
            throw PlanValidationError.decodingFailed(error)
        }

        guard !plan.days.isEmpty else { throw PlanValidationError.missingDays }

        var unsupportedTypes = Set<String>()
        var totalSegments = 0
        for day in plan.days {
            for segment in day.segments {
                totalSegments += 1
                if case let .unsupported(rawType) = segment {
                    unsupportedTypes.insert(rawType)
                }
            }
        }

        var warnings: [String] = []
        if totalSegments == 0 {
            warnings.append("No segments detected in the schedule.")
        }

        if !unsupportedTypes.isEmpty {
            let sorted = unsupportedTypes.sorted()
            let segments = sorted.joined(separator: ",")
            warnings.append("Unsupported segment types: \(segments).")
        }

        // V0.4: Validate V0.4 features
        let v04Warnings = validateV04Features(plan: plan)
        warnings.append(contentsOf: v04Warnings)

        // Tier 1: Validate Tier 1 editing requirements
        try validateTier1Requirements(plan: plan)

        let sha256 = Self.digest(for: data)
        let summary = PlanSummary(
            planName: plan.planName,
            unit: plan.unit,
            dayCount: plan.days.count,
            scheduleOrder: plan.scheduleOrder,
            unsupportedSegmentTypes: unsupportedTypes.sorted(),
            warnings: warnings,
            sha256: sha256
        )

        return PlanValidationResult(summary: summary, plan: plan)
    }

    private static func digest(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - V0.4 Validation

    private static func validateV04Features(plan: PlanV03) -> [String] {
        var warnings: [String] = []

        // Validate per_week keys (must be numeric)
        for day in plan.days {
            for segment in day.segments {
                switch segment {
                case .straight(let straight):
                    if let perWeek = straight.perWeek {
                        warnings.append(contentsOf: validatePerWeekKeys(perWeek.keys, segmentType: "straight", dayLabel: day.label))
                    }
                    warnings.append(contentsOf: validateLoadAxisTarget(straight.loadAxisTarget, exerciseCode: straight.exerciseCode, plan: plan))

                case .scheme(let scheme):
                    if let perWeek = scheme.perWeek {
                        warnings.append(contentsOf: validatePerWeekKeys(perWeek.keys, segmentType: "scheme", dayLabel: day.label))
                    }
                    warnings.append(contentsOf: validateLoadAxisTarget(scheme.loadAxisTarget, exerciseCode: scheme.exerciseCode, plan: plan))

                case .superset(let superset):
                    for (itemIndex, item) in superset.items.enumerated() {
                        if let perWeek = item.perWeek {
                            warnings.append(contentsOf: validatePerWeekKeys(perWeek.keys, segmentType: "superset item \(itemIndex)", dayLabel: day.label))
                        }
                        warnings.append(contentsOf: validateLoadAxisTarget(item.loadAxisTarget, exerciseCode: item.exerciseCode, plan: plan))
                    }

                case .percentage(let percentage):
                    if let perWeek = percentage.perWeek {
                        warnings.append(contentsOf: validatePerWeekKeys(perWeek.keys, segmentType: "percentage", dayLabel: day.label))
                    }

                case .unsupported:
                    continue
                }
            }
        }

        // Validate group_variants
        if !plan.groupVariants.isEmpty {
            for (groupName, roles) in plan.groupVariants {
                // Check if group exists in plan.altGroups
                if plan.altGroups[groupName] == nil {
                    warnings.append("group_variants references unknown group '\(groupName)'")
                }

                for (roleName, exercises) in roles {
                    for (exCode, _) in exercises {
                        // Check if exercise code exists in the group
                        if let groupExercises = plan.altGroups[groupName],
                           !groupExercises.contains(exCode) {
                            warnings.append("group_variants[\(groupName)][\(roleName)] references exercise '\(exCode)' not in group")
                        }
                    }
                }
            }
        }

        return warnings
    }

    private static func validatePerWeekKeys<T>(_ keys: Dictionary<String, T>.Keys, segmentType: String, dayLabel: String) -> [String] {
        var warnings: [String] = []
        for key in keys {
            if Int(key) == nil {
                warnings.append("per_week key '\(key)' in \(segmentType) on '\(dayLabel)' is not numeric")
            }
        }
        return warnings
    }

    private static func validateLoadAxisTarget(_ target: PlanV03.LoadAxisTarget?, exerciseCode: String, plan: PlanV03) -> [String] {
        guard let target = target else { return [] }

        var warnings: [String] = []

        // Check if exercise has exerciseMeta
        guard let exerciseMeta = plan.exerciseMeta[exerciseCode] else {
            warnings.append("Exercise '\(exerciseCode)' has load_axis_target but no exercise_meta defined")
            return warnings
        }

        // Check if axis exists in load_axes
        if let loadAxes = exerciseMeta.loadAxes {
            if loadAxes[target.axis] == nil {
                warnings.append("Exercise '\(exerciseCode)' load_axis_target references unknown axis '\(target.axis)'")
            }
        } else {
            warnings.append("Exercise '\(exerciseCode)' has load_axis_target but no load_axes defined in exercise_meta")
        }

        return warnings
    }

    // MARK: - Tier 1 Validation

    private static func validateTier1Requirements(plan: PlanV03) throws {
        // Validate all straight segments
        try PlanTraversal.forEachSegment(in: plan) { segment, day in
            let dayLabel = day.label
            switch segment {
            case .straight(let straight):
                // 1. Exercise code must exist in exerciseNames
                if plan.exerciseNames[straight.exerciseCode] == nil {
                    throw PlanValidationError.exerciseCodeNotInDictionary(straight.exerciseCode, dayLabel: dayLabel)
                }

                // 2. Sets must be > 0
                if straight.sets <= 0 {
                    throw PlanValidationError.invalidSets(straight.sets, exerciseCode: straight.exerciseCode, dayLabel: dayLabel)
                }

                // 3. Reps min/max must be non-nil and 1 ≤ min ≤ max
                if let reps = straight.reps {
                    if let min = reps.min, let max = reps.max {
                        if min < 1 || max < 1 || min > max {
                            throw PlanValidationError.invalidReps(
                                exerciseCode: straight.exerciseCode,
                                dayLabel: dayLabel,
                                reason: "reps min=\(min), max=\(max) invalid (must be 1 ≤ min ≤ max)"
                            )
                        }
                    } else if reps.text == nil {
                        // If text is also nil, then we have incomplete reps
                        throw PlanValidationError.invalidReps(
                            exerciseCode: straight.exerciseCode,
                            dayLabel: dayLabel,
                            reason: "reps min or max is nil and no text provided"
                        )
                    }
                }

            case .scheme(let scheme):
                // Validate scheme segment exercise codes
                if plan.exerciseNames[scheme.exerciseCode] == nil {
                    throw PlanValidationError.exerciseCodeNotInDictionary(scheme.exerciseCode, dayLabel: dayLabel)
                }

            case .superset(let superset):
                // Validate superset item exercise codes
                for item in superset.items {
                    if plan.exerciseNames[item.exerciseCode] == nil {
                        throw PlanValidationError.exerciseCodeNotInDictionary(item.exerciseCode, dayLabel: dayLabel)
                    }
                }

            case .percentage(let percentage):
                // Validate percentage segment exercise codes
                if plan.exerciseNames[percentage.exerciseCode] == nil {
                    throw PlanValidationError.exerciseCodeNotInDictionary(percentage.exerciseCode, dayLabel: dayLabel)
                }

            case .unsupported:
                break
            }
        }
    }
}
