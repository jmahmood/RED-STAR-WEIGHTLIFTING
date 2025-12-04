import SwiftUI

/// Main insights overview with metrics and exercise explorer
struct InsightsOverviewView: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    @EnvironmentObject private var exportStore: ExportInboxStore

    @State private var selectedRange: TimeRange = .threeMonths
    @State private var metrics: MetricsSummary?
    @State private var exerciseUniverse: ExerciseUniverse?
    @State private var isLoading = false
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time range selector
                timeRangeSelector

                if isLoading {
                    ProgressView("Loading metrics...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let metrics = metrics {
                    // Strength overview cards
                    strengthOverviewSection(metrics: metrics)

                    // Recent progress summary
                    recentProgressSection(metrics: metrics)

                    // PR snapshot
                    prSnapshotSection(metrics: metrics)
                } else {
                    noDataView
                }

                // Exercise explorer
                exerciseExplorerSection
            }
            .padding()
        }
        .navigationTitle("Insights")
        .task {
            await loadMetrics()
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
                await loadMetrics()
            }
        }
    }

    private func strengthOverviewSection(metrics: MetricsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strength Overview")
                .font(.title3)
                .fontWeight(.semibold)

            let topExercises = identifyTopExercises(from: metrics)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(topExercises.prefix(4), id: \.exerciseCode) { exercise in
                    StrengthCard(
                        exerciseCode: exercise.exerciseCode,
                        displayName: displayName(for: exercise.exerciseCode),
                        metrics: exercise,
                        onTap: {
                            coordinator.navigateToExerciseDetail(exercise.exerciseCode)
                        }
                    )
                }
            }
        }
    }

    private func recentProgressSection(metrics: MetricsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Progress")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ProgressRow(
                    title: "Sessions/Week",
                    value: String(format: "%.1f", metrics.globalMetrics.sessionsPerWeek),
                    change: nil
                )

                ProgressRow(
                    title: "Total Volume",
                    value: formatWeight(metrics.globalMetrics.totalVolume),
                    change: nil
                )

                ProgressRow(
                    title: "Total Sessions",
                    value: "\(metrics.globalMetrics.totalSessions)",
                    change: nil
                )
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func prSnapshotSection(metrics: MetricsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal Records")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button("View All") {
                    coordinator.navigateToPRList()
                }
                .font(.caption)
            }

            VStack(spacing: 8) {
                ForEach(Array(metrics.exerciseMetrics.values.prefix(5)), id: \.exerciseCode) { exercise in
                    if let best1RM = exercise.best1RM {
                        PRSnapshotRow(
                            exerciseCode: exercise.exerciseCode,
                            displayName: displayName(for: exercise.exerciseCode),
                            value: best1RM.value,
                            date: best1RM.date
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            coordinator.navigateToExerciseDetail(exercise.exerciseCode)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private var exerciseExplorerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Explorer")
                .font(.title3)
                .fontWeight(.semibold)

            TextField("Search exercises...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            if let universe = exerciseUniverse {
                let exercises = searchText.isEmpty
                    ? try? universe.allExercises()
                    : try? universe.search(searchText)

                if let exercises = exercises {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(exercises.prefix(20), id: \.code) { exercise in
                                ExerciseChip(exercise: exercise)
                                    .onTapGesture {
                                        coordinator.navigateToExerciseDetail(exercise.code)
                                    }
                            }
                        }
                    }
                }
            }
        }
    }

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Data Available")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete workouts to see your insights.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    private func loadMetrics() async {
        isLoading = true
        defer { isLoading = false }

        // Initialize services
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

        exerciseUniverse = universe

        do {
            metrics = try engine.computeMetrics(for: selectedRange)
        } catch {
            print("Failed to load metrics: \(error)")
        }
    }

    private func identifyTopExercises(from metrics: MetricsSummary) -> [ExerciseMetrics] {
        // Try to find canonical lifts first
        guard let universe = exerciseUniverse else {
            return Array(metrics.topExercises.prefix(4))
        }

        var topExercises: [ExerciseMetrics] = []

        // Try canonical lifts
        for canonicalType in CanonicalLift.allCases {
            if let exercise = metrics.exerciseMetrics.values.first(where: {
                universe.canonicalLiftType(for: $0.exerciseCode) == canonicalType
            }) {
                topExercises.append(exercise)
            }

            if topExercises.count >= 4 {
                break
            }
        }

        // Fill with top by volume if needed
        if topExercises.count < 4 {
            let remaining = metrics.topExercises
                .filter { candidate in
                    !topExercises.contains(where: { $0.exerciseCode == candidate.exerciseCode })
                }
                .prefix(4 - topExercises.count)
            topExercises.append(contentsOf: remaining)
        }

        return topExercises
    }

    private func formatWeight(_ weight: Double) -> String {
        String(format: "%.0f lb", weight)
    }

    private func displayName(for code: String) -> String {
        if let universe = exerciseUniverse,
           let exercise = try? universe.exercise(for: code) {
            return exercise.displayName
        }
        return Exercise.formatExerciseCode(code)
    }
}

// MARK: - Strength Card

struct StrengthCard: View {
    let exerciseCode: String
    let displayName: String
    let metrics: ExerciseMetrics
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let best1RM = metrics.best1RM {
                    Text(String(format: "%.0f", best1RM.value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("e1RM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Row

struct ProgressRow: View {
    let title: String
    let value: String
    let change: Double?

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)

                if let change = change {
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text(String(format: "%.1f%%", abs(change)))
                            .font(.caption)
                    }
                    .foregroundStyle(change >= 0 ? .green : .red)
                }
            }
        }
    }
}

// MARK: - PR Snapshot Row

struct PRSnapshotRow: View {
    let exerciseCode: String
    let displayName: String
    let value: Double
    let date: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.0f", value))
                .font(.body)
                .fontWeight(.semibold)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Exercise Chip

struct ExerciseChip: View {
    let exercise: Exercise

    var body: some View {
        Text(exercise.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
    }
}
