//
//  PlanTraversal.swift
//  Shared
//
//  Shared traversal + expansion helpers for PlanV03.
//

import Foundation

public struct PlanExerciseInstance: Sendable {
    public let code: String
    public let targetReps: String
    public let badges: [String]
    public let isTimed: Bool
}

public enum PlanTraversal {
    public static func forEachSegment(
        in plan: PlanV03,
        _ handler: (PlanV03.Segment, PlanV03.Day) throws -> Void
    ) rethrows {
        for day in plan.days {
            for segment in day.segments {
                try handler(segment, day)
            }
        }
    }

    public static func expand(
        day: PlanV03.Day,
        plan: PlanV03,
        capabilities: PlanCapabilities = .v03MVP
    ) -> [PlanExerciseInstance] {
        var result: [PlanExerciseInstance] = []

        for segment in day.segments {
            switch segment {
            case .straight(let straight):
                guard capabilities.supportsStraight else { continue }
                let sets = max(1, straight.sets)
                let reps = straight.reps?.displayText ?? "Reps"
                let badges = makeBadges(intensifier: straight.intensifier, restSec: straight.restSec)
                let instance = PlanExerciseInstance(
                    code: straight.exerciseCode,
                    targetReps: reps,
                    badges: badges,
                    isTimed: straight.timeSec != nil
                )
                for _ in 0..<sets { result.append(instance) }

            case .scheme(let scheme):
                guard capabilities.supportsScheme else { continue }
                for entry in scheme.entries {
                    let sets = max(1, entry.sets)
                    let reps = entry.reps?.displayText ?? scheme.entries.first?.reps?.displayText ?? "Reps"
                    let badges = makeBadges(
                        intensifier: entry.intensifier ?? scheme.intensifier,
                        restSec: entry.restSec ?? scheme.restSec
                    )
                    let instance = PlanExerciseInstance(
                        code: scheme.exerciseCode,
                        targetReps: reps,
                        badges: badges,
                        isTimed: false
                    )
                    for _ in 0..<sets { result.append(instance) }
                }

            case .superset(let superset):
                guard capabilities.supportsSuperset else { continue }
                let rounds = max(1, superset.rounds)
                for _ in 0..<rounds {
                    for item in superset.items {
                        let sets = max(1, item.sets)
                        let reps = item.reps?.displayText ?? "Reps"
                        let badges = makeBadges(
                            intensifier: item.intensifier,
                            restSec: item.restSec ?? superset.restSec ?? superset.restBetweenRoundsSec
                        )
                        let instance = PlanExerciseInstance(
                            code: item.exerciseCode,
                            targetReps: reps,
                            badges: badges,
                            isTimed: false
                        )
                        for _ in 0..<sets { result.append(instance) }
                    }
                }

            case .percentage(let percentage):
                guard capabilities.supportsPercentage else { continue }
                for prescription in percentage.prescriptions {
                    let sets = max(1, prescription.sets)
                    let reps = prescription.reps.displayText
                    let badges = makeBadges(intensifier: prescription.intensifier, restSec: nil)
                    let instance = PlanExerciseInstance(
                        code: percentage.exerciseCode,
                        targetReps: reps,
                        badges: badges,
                        isTimed: false
                    )
                    for _ in 0..<sets { result.append(instance) }
                }

            case .unsupported:
                continue
            }
        }

        return result
    }

    public static func makeBadges(intensifier: PlanV03.Intensifier?, restSec: Int?) -> [String] {
        var badges: [String] = []
        if let intensifier {
            switch intensifier.kind {
            case .dropset: badges.append("dropset")
            case .amrap: badges.append("amrap")
            case .unknown: break
            }
        }
        if let restSec, restSec == 0 {
            badges.append("zero-rest")
        }
        return badges
    }
}

