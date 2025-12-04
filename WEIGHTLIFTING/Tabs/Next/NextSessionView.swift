import SwiftUI

/// Displays the next workout session
struct NextSessionView: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    @EnvironmentObject private var exportStore: ExportInboxStore
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let nextWorkout = exportStore.nextWorkout {
                    NextWorkoutDetailCard(
                        workout: nextWorkout
                    )
                } else if exportStore.activePlan != nil {
                    noNextWorkoutView
                } else {
                    noPlanView
                }
            }
            .padding()
        }
        .navigationTitle("Next Workout")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    coordinator.navigateToPrograms()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    private var noNextWorkoutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Next Workout")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Unable to determine the next workout from your plan.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("View Programs") {
                coordinator.navigateToPrograms()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noPlanView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Active Program")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Set up your first program to see your next workout.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Browse Programs") {
                coordinator.navigateToPrograms()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Card displaying next workout details
struct NextWorkoutDetailCard: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    let workout: NextWorkoutDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.planName)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(workout.dayLabel)
                    .font(.title)
                    .fontWeight(.bold)
            }

            Divider()

            // Exercise list
            VStack(alignment: .leading, spacing: 12) {
                ForEach(workout.lines) { line in
                    ExerciseLineView(line: line)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            coordinator.navigateToExerciseDetail(line.id)
                        }
                }

                if workout.remainingCount > 0 {
                    Text("+ \(workout.remainingCount) more exercises")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            // Warnings
            if workout.timedSetsSkipped {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Some timed sets are not shown (not yet supported)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Actions
            Button {
                coordinator.navigateToPrograms()
            } label: {
                Label("Change Program", systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Individual exercise line
struct ExerciseLineView: View {
    let line: NextWorkoutDisplay.Line

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Exercise name
            VStack(alignment: .leading, spacing: 2) {
                Text(line.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(line.targetReps)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Badges
            if !line.badges.isEmpty {
                HStack(spacing: 4) {
                    ForEach(line.badges, id: \.self) { badge in
                        BadgeView(text: badge)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// Badge view for exercise modifiers
struct BadgeView: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(badgeColor)
            .cornerRadius(4)
    }

    private var badgeColor: Color {
        switch text.lowercased() {
        case "amrap":
            return .orange
        case "dropset":
            return .purple
        case "zero-rest":
            return .red
        default:
            return .blue
        }
    }
}
