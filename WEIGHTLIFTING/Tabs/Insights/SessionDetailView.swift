import SwiftUI

/// Displays detailed information about a single workout session
struct SessionDetailView: View {
    let sessionID: String

    @State private var session: WorkoutSession?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading session...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let session = session {
                List {
                    // Session overview
                    Section("Session Info") {
                        LabeledContent("Date", value: session.date, format: .dateTime.day().month().year())
                        LabeledContent("Time", value: session.time)
                        if !session.planName.isEmpty {
                            LabeledContent("Plan", value: session.planName)
                        }
                        if !session.dayLabel.isEmpty {
                            LabeledContent("Day", value: session.dayLabel)
                        }
                    }

                    // Summary metrics
                    Section("Summary") {
                        LabeledContent("Total Volume", value: String(format: "%.0f lb", session.totalVolume))
                        LabeledContent("Working Sets", value: "\(session.workingSets)")
                        LabeledContent("Total Sets", value: "\(session.totalSets)")
                        LabeledContent("Exercises", value: "\(session.uniqueExercises)")
                    }

                    // Per-exercise breakdown
                    ForEach(Array(session.setsByExercise.keys.sorted()), id: \.self) { exerciseCode in
                        if let sets = session.setsByExercise[exerciseCode] {
                            Section(Exercise.formatExerciseCode(exerciseCode)) {
                                ForEach(sets) { set in
                                    SetRow(set: set)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView(
                    "Session Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Unable to load session data.")
                )
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadSession()
        }
    }

    private func loadSession() async {
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

        let adapter = WorkoutSessionAdapter(csvURL: csvURL)

        do {
            let allSessions = try adapter.loadAllSessions()
            session = allSessions.first { $0.id == sessionID }
        } catch {
            print("Failed to load session: \(error)")
        }
    }
}

// MARK: - Set Row

struct SetRow: View {
    let set: SetRecord

    var body: some View {
        HStack {
            // Set number
            Text("Set \(set.setNumber)")
                .font(.body)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)

            Spacer()

            // Reps
            VStack(alignment: .trailing, spacing: 2) {
                Text(set.reps)
                    .font(.body)
                    .fontWeight(.semibold)

                Text("reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)

            // Weight
            if let weight = set.weight {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", weight))
                        .font(.body)
                        .fontWeight(.semibold)

                    Text(set.unit.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60)
            } else {
                Text("BW")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 60)
            }

            // Effort
            if set.effort > 0 {
                EffortIndicator(effort: set.effort)
                    .frame(width: 80)
            }

            // Badges
            HStack(spacing: 4) {
                if set.isWarmup {
                    Text("W")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.gray)
                        .cornerRadius(9)
                }

                if set.isAdlib {
                    Text("A")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.purple)
                        .cornerRadius(9)
                }
            }
            .frame(width: 40)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Effort Indicator

struct EffortIndicator: View {
    let effort: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= effort ? effortColor : Color.gray.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var effortColor: Color {
        switch effort {
        case 1:
            return .green
        case 2:
            return .yellow
        case 3:
            return .orange
        case 4:
            return .red
        case 5:
            return .purple
        default:
            return .gray
        }
    }
}
