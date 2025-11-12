//
//  NextWorkoutBuilder.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-11-02.
//

import Foundation

struct NextWorkoutBuilder {
    func makeNextWorkout(plan: PlanV03, currentDayLabel: String?) throws -> NextWorkoutDisplay {
        guard !plan.scheduleOrder.isEmpty else {
            throw InsightsError.planMissing
        }

        let currentLabel = currentDayLabel ?? plan.scheduleOrder.last ?? ""
        let currentIndex = plan.scheduleOrder.firstIndex(of: currentLabel) ?? (plan.scheduleOrder.count - 1)
        let nextIndex = (currentIndex + 1) % plan.scheduleOrder.count
        let nextLabel = plan.scheduleOrder[nextIndex]
        guard let day = plan.days.first(where: { $0.label == nextLabel }) else {
            throw InsightsError.planMissing
        }

        var accumulators: [String: ExerciseSummary] = [:]
        var orderedCodes: [String] = []
        var timedSetsSkipped = false

        for instance in expand(day: day, plan: plan) {
            if instance.isTimed {
                timedSetsSkipped = true
                continue
            }

            if var existing = accumulators[instance.code] {
                existing.register(reps: instance.targetReps, badges: instance.badges)
                accumulators[instance.code] = existing
            } else {
                var summary = ExerciseSummary(name: instance.name, firstIndex: orderedCodes.count)
                summary.register(reps: instance.targetReps, badges: instance.badges)
                accumulators[instance.code] = summary
                orderedCodes.append(instance.code)
            }
        }

        let lines = orderedCodes.compactMap { code -> NextWorkoutDisplay.Line? in
            guard let summary = accumulators[code] else { return nil }
            let reps = summary.dominantReps
            return NextWorkoutDisplay.Line(
                id: code,
                name: summary.name,
                targetReps: reps,
                badges: summary.badges
            )
        }

        let limited = Array(lines.prefix(10))
        let remaining = max(0, lines.count - limited.count)
        return NextWorkoutDisplay(
            planName: plan.planName,
            dayLabel: day.label,
            lines: limited,
            remainingCount: remaining,
            timedSetsSkipped: timedSetsSkipped
        )
    }
}

private extension NextWorkoutBuilder {
    struct ExerciseInstance {
        let code: String
        let name: String
        let targetReps: String
        let badges: [String]
        let isTimed: Bool
    }

    struct ExerciseSummary {
        let name: String
        let firstIndex: Int
        private(set) var repCounts: [String: Int] = [:]
        private(set) var repOrder: [String] = []
        private(set) var badges: [String] = []

        init(name: String, firstIndex: Int) {
            self.name = name
            self.firstIndex = firstIndex
        }

        mutating func register(reps: String, badges: [String]) {
            repCounts[reps, default: 0] += 1
            if !repOrder.contains(reps) {
                repOrder.append(reps)
            }
            for badge in badges where !badge.isEmpty {
                if !self.badges.contains(badge) {
                    self.badges.append(badge)
                }
            }
        }

        var dominantReps: String {
            guard let best = repCounts.max(by: { lhs, rhs in
                if lhs.value == rhs.value {
                    let lhsIndex = repOrder.firstIndex(of: lhs.key) ?? Int.max
                    let rhsIndex = repOrder.firstIndex(of: rhs.key) ?? Int.max
                    return lhsIndex > rhsIndex
                }
                return lhs.value < rhs.value
            }) else {
                return repOrder.first ?? "Reps"
            }
            return best.key
        }
    }

    func expand(day: PlanV03.Day, plan: PlanV03) -> [ExerciseInstance] {
        var result: [ExerciseInstance] = []

        for segment in day.segments {
            switch segment {
            case .straight(let straight):
                let sets = max(1, straight.sets)
                let reps = straight.reps?.displayText ?? "Reps"
                let badges = makeBadges(
                    intensifier: straight.intensifier,
                    restSec: straight.restSec
                )
                let instance = ExerciseInstance(
                    code: straight.exerciseCode,
                    name: displayName(for: straight.exerciseCode, plan: plan),
                    targetReps: reps,
                    badges: badges,
                    isTimed: straight.timeSec != nil
                )
                for _ in 0..<sets {
                    result.append(instance)
                }
            case .scheme(let scheme):
                for entry in scheme.entries {
                    let sets = max(1, entry.sets)
                    let reps = entry.reps?.displayText ?? scheme.entries.first?.reps?.displayText ?? "Reps"
                    let badges = makeBadges(
                        intensifier: entry.intensifier ?? scheme.intensifier,
                        restSec: entry.restSec ?? scheme.restSec
                    )
                    let instance = ExerciseInstance(
                        code: scheme.exerciseCode,
                        name: displayName(for: scheme.exerciseCode, plan: plan),
                        targetReps: reps,
                        badges: badges,
                        isTimed: false
                    )
                    for _ in 0..<sets {
                        result.append(instance)
                    }
                }
            case .superset(let superset):
                let rounds = max(1, superset.rounds)
                for _ in 0..<rounds {
                    for item in superset.items {
                        let sets = max(1, item.sets)
                        let reps = item.reps?.displayText ?? "Reps"
                        let badges = makeBadges(
                            intensifier: item.intensifier,
                            restSec: item.restSec ?? superset.restSec ?? superset.restBetweenRoundsSec
                        )
                        let instance = ExerciseInstance(
                            code: item.exerciseCode,
                            name: displayName(for: item.exerciseCode, plan: plan),
                            targetReps: reps,
                            badges: badges,
                            isTimed: false
                        )
                        for _ in 0..<sets {
                            result.append(instance)
                        }
                    }
                }
            case .unsupported:
                continue
            }
        }

        return result
    }

    func displayName(for code: String, plan: PlanV03) -> String {
        plan.exerciseNames[code] ?? code
    }

    func makeBadges(intensifier: PlanV03.Intensifier?, restSec: Int?) -> [String] {
        var badges: [String] = []
        if let intensifier {
            switch intensifier.kind {
            case .dropset:
                badges.append("dropset")
            case .amrap:
                badges.append("amrap")
            case .unknown:
                break
            }
        }
        if let restSec, restSec == 0 {
            badges.append("zero-rest")
        }
        return badges
    }
}
