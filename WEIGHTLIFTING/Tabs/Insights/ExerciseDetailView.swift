import SwiftUI
import Charts

/// Detailed view for a single exercise showing metrics and history
struct ExerciseDetailView: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    let exerciseCode: String

    @State private var selectedRange: TimeRange = .threeMonths
    @State private var exerciseMetrics: ExerciseMetrics?
    @State private var recentSessions: [WorkoutSession] = []
    @State private var exerciseName: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time range selector
                timeRangeSelector

                if isLoading {
                    ProgressView("Loading data...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let metrics = exerciseMetrics {
                    // Best 1RM card
                    bestE1RMCard(metrics: metrics)

                    // e1RM trend chart
                    e1RMTrendChart(metrics: metrics)

                    // Volume per session chart
                    volumePerSessionChart(metrics: metrics)

                    // Frequency summary
                    frequencyCard(metrics: metrics)

                    // Recent sessions
                    recentSessionsSection
                } else {
                    noDataView
                }
            }
            .padding()
        }
        .navigationTitle(exerciseName ?? Exercise.formatExerciseCode(exerciseCode))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadData()
        }
    }

    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedRange) { _ in
            Task {
                await loadData()
            }
        }
    }

    private func bestE1RMCard(metrics: ExerciseMetrics) -> some View {
        VStack(spacing: 12) {
            if let best = metrics.best1RM {
                VStack(spacing: 8) {
                    Text("Best Estimated 1RM")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.0f lb", best.value))
                        .font(.system(size: 48, weight: .bold))

                    HStack(spacing: 12) {
                        if let weight = best.set.weight {
                            Text("\(String(format: "%.0f", weight)) × \(best.set.reps)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(best.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No PR Data")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func e1RMTrendChart(metrics: ExerciseMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("e1RM Trend")
                .font(.headline)

            if !metrics.volumePerSession.isEmpty {
                Chart {
                    ForEach(Array(metrics.volumePerSession.enumerated()), id: \.offset) { index, point in
                        // Simplified line chart - would need actual e1RM data points
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("e1RM", point.volume / 100) // Placeholder calculation
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
            } else {
                Text("No data for selected range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func volumePerSessionChart(metrics: ExerciseMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume Per Session")
                .font(.headline)

            if !metrics.volumePerSession.isEmpty {
                Chart {
                    ForEach(Array(metrics.volumePerSession.enumerated()), id: \.offset) { index, point in
                        BarMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(.green)
                    }
                }
                .frame(height: 200)
            } else {
                Text("No data for selected range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func frequencyCard(metrics: ExerciseMetrics) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frequency")
                        .font(.headline)

                    Text(String(format: "%.1f sessions/week", metrics.frequencyPerWeek))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Sessions")
                        .font(.headline)

                    Text("\(metrics.sessionCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if recentSessions.isEmpty {
                Text("No recent sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(recentSessions) { session in
                        RecentSessionRow(session: session, exerciseCode: exerciseCode)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                coordinator.navigateToSessionDetail(session.id)
                            }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Data Available")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No history found for this exercise in the selected time range.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        guard let csvURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("WeightWatch/Global/all_time.csv") else {
            return
        }

        guard let activePlanURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("WeightWatch/Plans/active_plan.json") else {
            return
        }

        let adapter = WorkoutSessionAdapter(csvURL: csvURL)
        let universe = ExerciseUniverse(csvURL: csvURL, activePlanURL: activePlanURL)
        let engine = MetricsEngine(adapter: adapter, exerciseUniverse: universe)

        do {
            // Load exercise name
            if let exercise = try universe.exercise(for: exerciseCode) {
                exerciseName = exercise.displayName
            }

            // Load metrics
            exerciseMetrics = try engine.exerciseMetrics(for: exerciseCode, range: selectedRange)

            // Load recent sessions
            recentSessions = try engine.recentSessions(for: exerciseCode, limit: 10)
        } catch {
            print("Failed to load exercise data: \(error)")
        }
    }
}

// MARK: - Recent Session Row

struct RecentSessionRow: View {
    let session: WorkoutSession
    let exerciseCode: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date, style: .date)
                    .font(.body)
                    .fontWeight(.medium)

                if !session.dayLabel.isEmpty {
                    Text(session.dayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text("\(exerciseSets) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.0f lb", exerciseVolume))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let topSet = topSet {
                VStack(alignment: .trailing, spacing: 2) {
                    if let weight = topSet.weight {
                        Text(String(format: "%.0f", weight))
                            .font(.body)
                            .fontWeight(.semibold)

                        Text("\(topSet.reps) reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var exerciseSets: Int {
        session.sets.filter { $0.exerciseCode == exerciseCode && !$0.isWarmup }.count
    }

    private var exerciseVolume: Double {
        session.sets
            .filter { $0.exerciseCode == exerciseCode && !$0.isWarmup }
            .compactMap { $0.tonnage }
            .reduce(0, +)
    }

    private var topSet: SetRecord? {
        session.sets
            .filter { $0.exerciseCode == exerciseCode && !$0.isWarmup }
            .max { ($0.estimated1RM ?? 0) < ($1.estimated1RM ?? 0) }
    }
}
