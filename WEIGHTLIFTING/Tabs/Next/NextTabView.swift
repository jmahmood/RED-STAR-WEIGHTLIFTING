import SwiftUI

/// Next tab root view
struct NextTabView: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    @EnvironmentObject private var exportStore: ExportInboxStore

    var body: some View {

        NavigationStack(path: $coordinator.nextNavPath) {
            NextSessionView()
                .navigationDestination(for: NextDestination.self) { destination in
                    switch destination {
                    case .upcomingSessions:
                        if let plan = exportStore.activePlan {
                            let upcoming = UpcomingSessionsView.generateUpcoming(
                                from: plan,
                                currentDayLabel: exportStore.latestDayLabel
                            )
                            UpcomingSessionsView(upcomingSessions: upcoming)
                        }
                    }
                }
        }
    }
}

// MARK: - Navigation Destinations

enum NextDestination: Hashable {
    case upcomingSessions
}
