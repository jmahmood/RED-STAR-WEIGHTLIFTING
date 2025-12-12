import SwiftUI

/// Displays all personal records
struct PRListView: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    @State private var prRecords: [PRRecord] = []
    @State private var sortOption: PRSortOption = .by1RM
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading PRs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if prRecords.isEmpty {
                emptyView
            } else {
                List {
                    Section {
                        Picker("Sort By", selection: $sortOption) {
                            ForEach(PRSortOption.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        ForEach(sortedRecords) { record in
                            PRRecordRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    coordinator.navigateToExerciseDetail(record.exerciseCode)
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadPRs()
        }
    }

    private var sortedRecords: [PRRecord] {
        switch sortOption {
        case .by1RM:
            return prRecords.sorted { ($0.best1RM ?? 0) > ($1.best1RM ?? 0) }
        case .byDate:
            return prRecords.sorted { $0.prDate > $1.prDate }
        case .alphabetical:
            return prRecords.sorted { $0.exerciseName < $1.exerciseName }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No PRs Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete workouts to set personal records.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func loadPRs() async {
        isLoading = true
        defer { isLoading = false }

        let paths = StoragePaths.makeDefault()
        let csvURL = paths.globalCSVURL

        let adapter = WorkoutSessionAdapter(csvURL: csvURL)
        let universe = ExerciseUniverse(csvURL: csvURL)
        let engine = MetricsEngine(adapter: adapter, exerciseUniverse: universe)

        do {
            let metrics = try engine.computeMetrics(for: .allTime)
            let exercises = try universe.allExercises()

            prRecords = metrics.exerciseMetrics.compactMap { code, exerciseMetrics in
                guard let best1RM = exerciseMetrics.best1RM else { return nil }

                let exercise = exercises.first { $0.code == code }
                return PRRecord(
                    exerciseCode: code,
                    exerciseName: exercise?.displayName ?? Exercise.formatExerciseCode(code),
                    best1RM: best1RM.value,
                    prDate: best1RM.date,
                    weight: best1RM.set.weight,
                    reps: best1RM.set.reps
                )
            }
        } catch {
            print("Failed to load PRs: \(error)")
        }
    }
}

// MARK: - PR Record Row

struct PRRecordRow: View {
    let record: PRRecord

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.exerciseName)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if let weight = record.weight {
                        Text("\(String(format: "%.0f", weight)) × \(record.reps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(record.prDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", record.best1RM ?? 0))
                    .font(.title3)
                    .fontWeight(.bold)

                Text("e1RM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Models

struct PRRecord: Identifiable {
    let id = UUID()
    let exerciseCode: String
    let exerciseName: String
    let best1RM: Double?
    let prDate: Date
    let weight: Double?
    let reps: String
}

enum PRSortOption: String, CaseIterable {
    case by1RM = "1RM"
    case byDate = "Date"
    case alphabetical = "A-Z"

    var displayName: String {
        rawValue
    }
}
