//
//  CycleManager.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Claude on 2025-12-10.
//  V0.4: Manages week advancement and cycle tracking for multi-week programs
//

import Foundation

#if os(watchOS)

/// Protocol for cycle management
protocol CycleManaging {
    func shouldAdvanceWeek(meta: SessionMeta, plan: PlanV03) -> Bool
    func advanceWeek(meta: SessionMeta, plan: PlanV03) -> (newWeek: Int, newCycleId: String)
    func detectMaxWeek(plan: PlanV03) -> Int
    func computeCycleId(week: Int, startDate: Date) -> String
}

/// Cycle manager implementation
struct CycleManager: CycleManaging {

    // MARK: - Week Advancement Detection

    func shouldAdvanceWeek(meta: SessionMeta, plan: PlanV03) -> Bool {
        // Must have completed current session
        guard meta.sessionCompleted else {
            return false
        }

        // Check if all days in scheduleOrder have been completed
        let uniqueDaysCompleted = Set(meta.switchHistory).count
        let totalDaysInSchedule = plan.scheduleOrder.count

        return uniqueDaysCompleted >= totalDaysInSchedule
    }

    // MARK: - Week Advancement

    func advanceWeek(meta: SessionMeta, plan: PlanV03) -> (newWeek: Int, newCycleId: String) {
        let maxWeek = detectMaxWeek(plan: plan)
        let newWeek = (meta.cycleWeek % maxWeek) + 1
        let newCycleId = computeCycleId(week: newWeek, startDate: Date())

        return (newWeek, newCycleId)
    }

    // MARK: - Max Week Detection

    func detectMaxWeek(plan: PlanV03) -> Int {
        // PRIMARY: Check plan.phase?.weeks array
        if let phase = plan.phase,
           let maxWeek = phase.weeks.max() {
            return maxWeek
        }

        // FALLBACK: Scan all segments for per_week keys
        var maxWeekFromSegments = 1

        for day in plan.days {
            for segment in day.segments {
                switch segment {
                case .straight(let straight):
                    if let perWeek = straight.perWeek {
                        maxWeekFromSegments = max(maxWeekFromSegments, maxWeekFromKeys(perWeek))
                    }

                case .scheme(let scheme):
                    if let perWeek = scheme.perWeek {
                        maxWeekFromSegments = max(maxWeekFromSegments, maxWeekFromKeys(perWeek))
                    }

                case .superset(let superset):
                    for item in superset.items {
                        if let perWeek = item.perWeek {
                            maxWeekFromSegments = max(maxWeekFromSegments, maxWeekFromKeys(perWeek))
                        }
                    }

                case .percentage(let percentage):
                    if let perWeek = percentage.perWeek {
                        maxWeekFromSegments = max(maxWeekFromSegments, maxWeekFromPercentageKeys(perWeek))
                    }

                case .unsupported:
                    continue
                }
            }
        }

        return maxWeekFromSegments
    }

    // MARK: - Cycle ID Generation

    func computeCycleId(week: Int, startDate: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: startDate)
        let weekOfYear = calendar.component(.weekOfYear, from: startDate)

        return String(format: "%04d-W%02d", year, weekOfYear)
    }

    // MARK: - Private Helpers

    private func maxWeekFromKeys(_ perWeek: [String: PlanV03.PartialSegment]) -> Int {
        return perWeek.keys.compactMap { Int($0) }.max() ?? 1
    }

    private func maxWeekFromPercentageKeys(_ perWeek: [String: PlanV03.PercentageOverlay]) -> Int {
        return perWeek.keys.compactMap { Int($0) }.max() ?? 1
    }
}

#endif
