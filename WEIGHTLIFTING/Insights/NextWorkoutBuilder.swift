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

        for instance in PlanTraversal.expand(day: day, plan: plan, capabilities: .v04Preview) {
            if capabilitiesSkipTimed(instance: instance, capabilities: .v04Preview) {
                timedSetsSkipped = true
                continue
            }

            if var existing = accumulators[instance.code] {
                existing.register(reps: instance.targetReps, badges: instance.badges)
                accumulators[instance.code] = existing
            } else {
                let name = displayName(for: instance.code, plan: plan)
                var summary = ExerciseSummary(name: name, firstIndex: orderedCodes.count)
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

    func displayName(for code: String, plan: PlanV03) -> String {
        plan.exerciseNames[code] ?? code
    }

    func capabilitiesSkipTimed(instance: PlanExerciseInstance, capabilities: PlanCapabilities) -> Bool {
        capabilities.skipTimedSets && instance.isTimed
    }
}
