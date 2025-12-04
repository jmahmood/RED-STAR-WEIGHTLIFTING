import SwiftUI

/// Displays upcoming workout sessions based on plan schedule
struct UpcomingSessionsView: View {
    @EnvironmentObject private var exportStore: ExportInboxStore
    let upcomingSessions: [UpcomingSession]

    var body: some View {
        List {
            ForEach(upcomingSessions) { session in
                UpcomingSessionRow(session: session)
            }
        }
        .navigationTitle("Upcoming Sessions")
    }
}

/// Single upcoming session row
struct UpcomingSessionRow: View {
    let session: UpcomingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session \(session.sessionNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if session.exerciseCount > 0 {
                    Text("\(session.exerciseCount) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(session.dayLabel)
                .font(.headline)

            Text(session.planName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Models

struct UpcomingSession: Identifiable {
    let id = UUID()
    let sessionNumber: Int
    let dayLabel: String
    let planName: String
    let exerciseCount: Int
}

// MARK: - Helper

extension UpcomingSessionsView {
    /// Generate upcoming sessions from a plan
    static func generateUpcoming(from plan: PlanV03, currentDayLabel: String?, count: Int = 10) -> [UpcomingSession] {
        guard !plan.scheduleOrder.isEmpty else { return [] }

        let currentLabel = currentDayLabel ?? plan.scheduleOrder.last ?? ""
        let currentIndex = plan.scheduleOrder.firstIndex(of: currentLabel) ?? (plan.scheduleOrder.count - 1)

        var sessions: [UpcomingSession] = []

        for i in 0..<count {
            let index = (currentIndex + 1 + i) % plan.scheduleOrder.count
            let dayLabel = plan.scheduleOrder[index]

            // Find the day in the plan to get exercise count
            let day = plan.days.first { $0.label == dayLabel }
            let exerciseCount = day?.segments.count ?? 0

            let session = UpcomingSession(
                sessionNumber: i + 1,
                dayLabel: dayLabel,
                planName: plan.planName,
                exerciseCount: exerciseCount
            )
            sessions.append(session)
        }

        return sessions
    }
}
