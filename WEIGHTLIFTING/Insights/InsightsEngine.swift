//
//  InsightsEngine.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-11-02.
//

import Foundation

final class InsightsEngine {
    private let personalRecordService: PersonalRecordService
    private let nextWorkoutBuilder = NextWorkoutBuilder()
    private let planDirectory: URL
    private let fileManager: FileManager

    init(
        globalDirectory: URL,
        planDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.personalRecordService = PersonalRecordService(globalDirectory: globalDirectory, fileManager: fileManager)
        self.planDirectory = planDirectory
        self.fileManager = fileManager
    }

    func computeSnapshot() -> InsightsSnapshot {
        let plan = try? loadPlan()
        let prState = makePersonalRecordsState(plan: plan)
        let nextWorkoutState = makeNextWorkoutState(plan: plan, currentDayLabel: prState.latestDayLabel)

        return InsightsSnapshot(
            personalRecords: prState.state,
            nextWorkout: nextWorkoutState,
            latestDayLabel: prState.latestDayLabel,
            generatedAt: prState.generatedAt
        )
    }
}

private extension InsightsEngine {
    struct PersonalRecordComputation {
        let state: CardState<[PersonalRecordDisplay]>
        let latestDayLabel: String?
        let generatedAt: Date?
    }

    func makePersonalRecordsState(plan: PlanV03?) -> PersonalRecordComputation {
        do {
            let summary = try personalRecordService.summary()
            let displays = format(summary: summary, plan: plan)
            let state: CardState<[PersonalRecordDisplay]> =
                displays.isEmpty ? .empty(message: "No data yet.") : .ready(displays)
            return PersonalRecordComputation(
                state: state,
                latestDayLabel: summary.latestDayLabel,
                generatedAt: summary.generatedAt
            )
        } catch InsightsError.csvMissing {
            return PersonalRecordComputation(
                state: .empty(message: "No data yet."),
                latestDayLabel: nil,
                generatedAt: nil
            )
        } catch {
            return PersonalRecordComputation(
                state: .error(message: "Unable to parse snapshot."),
                latestDayLabel: nil,
                generatedAt: nil
            )
        }
    }

    func makeNextWorkoutState(plan: PlanV03?, currentDayLabel: String?) -> CardState<NextWorkoutDisplay> {
        guard let plan else {
            return .empty(message: "Import a plan to preview your next workout.")
        }

        do {
            let display = try nextWorkoutBuilder.makeNextWorkout(plan: plan, currentDayLabel: currentDayLabel)
            if display.lines.isEmpty {
                return .empty(message: "No exercises scheduled for \(display.dayLabel).")
            }
            return .ready(display)
        } catch InsightsError.planMissing {
            return .empty(message: "Plan schedule is incomplete.")
        } catch {
            return .error(message: "Unable to expand plan.")
        }
    }

    func loadPlan() throws -> PlanV03 {
        if let plan = try PlanStore.shared.loadActivePlan() {
            return plan
        }
        throw InsightsError.planMissing
    }

    func format(summary: PersonalRecordSummary, plan: PlanV03?) -> [PersonalRecordDisplay] {
        let preferredUnit = plan?.unit
        let exerciseNames = plan?.exerciseNames ?? [:]
        let grouped = Dictionary(grouping: summary.entries, by: { $0.exerciseCode })

        let displays: [PersonalRecordDisplay] = grouped.compactMap { code, entries in
            guard let entry = selectEntry(from: entries, preferredUnit: preferredUnit) else { return nil }

            let name = exerciseNames[code] ?? code
            let unitSymbol = WeightUnit.fromCSV(entry.unit)?.displaySymbol

            let primaryMetric: PersonalRecordDisplay.Metric?
            let secondaryMetric: PersonalRecordDisplay.Metric?
            var message: String?

            if let epley = entry.epley {
                primaryMetric = PersonalRecordDisplay.Metric(
                    kind: .oneRepMax,
                    value: epley.value,
                    weight: epley.weight,
                    reps: epley.reps,
                    date: epley.date
                )
            } else if let load = entry.load {
                primaryMetric = PersonalRecordDisplay.Metric(
                    kind: .load,
                    value: load.value,
                    weight: load.weight,
                    reps: load.reps,
                    date: load.date
                )
            } else {
                primaryMetric = nil
            }

            if let volume = entry.volume {
                secondaryMetric = PersonalRecordDisplay.Metric(
                    kind: .volume,
                    value: volume.value,
                    weight: volume.weight,
                    reps: volume.reps,
                    date: volume.date
                )
            } else {
                secondaryMetric = nil
            }

            if primaryMetric == nil, secondaryMetric != nil {
                message = "PRs not available for pure bodyweight sets."
            } else if primaryMetric == nil && secondaryMetric == nil {
                return nil
            }

            let recencyDate = primaryMetric?.date ?? secondaryMetric?.date
            let isNew = recencyDate.map { Self.isRecent($0) } ?? false

            return PersonalRecordDisplay(
                id: "\(code)|\(entry.unit)",
                exerciseCode: code,
                exerciseName: name,
                unitSymbol: unitSymbol,
                primary: primaryMetric,
                secondary: secondaryMetric,
                isNew: isNew,
                missingPrimaryMessage: message
            )
        }

        return displays
            .sorted(by: Self.sortRecords)
            .prefix(8)
            .map { $0 }
    }

    static func isRecent(_ date: Date) -> Bool {
        guard let window = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else {
            return false
        }
        return date >= window
    }

    static func sortRecords(lhs: PersonalRecordDisplay, rhs: PersonalRecordDisplay) -> Bool {
        let lhsDate = lhs.primary?.date ?? lhs.secondary?.date ?? Date.distantPast
        let rhsDate = rhs.primary?.date ?? rhs.secondary?.date ?? Date.distantPast
        if lhsDate == rhsDate {
            return lhs.exerciseName < rhs.exerciseName
        }
        return lhsDate > rhsDate
    }

    func selectEntry(from entries: [PersonalRecordSummary.Entry], preferredUnit: WeightUnit?) -> PersonalRecordSummary.Entry? {
        if let preferredUnit {
            if let match = entries.first(where: { WeightUnit.fromCSV($0.unit) == preferredUnit }) {
                return match
            }
        }

        if let weighted = entries.first(where: { WeightUnit.fromCSV($0.unit) != nil }) {
            return weighted
        }

        return entries.first
    }
}
