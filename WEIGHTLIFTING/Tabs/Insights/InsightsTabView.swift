import SwiftUI

/// Insights tab root view
struct InsightsTabView: View {
    @EnvironmentObject private var coordinator: TabCoordinator

    var body: some View {

        NavigationStack(path: $coordinator.insightsNavPath) {
            InsightsOverviewView()
                .navigationTitle("Insights")
                .navigationDestination(for: InsightsDestination.self) { destination in
                    switch destination {
                    case .exerciseDetail(let code):
                        ExerciseDetailView(exerciseCode: code)
                    case .sessionDetail(let sessionID):
                        SessionDetailView(sessionID: sessionID)
                    case .prList:
                        PRListView()
                    }
                }
        }
    }
}

// Note: Full implementations of ExerciseDetailView, SessionDetailView,
// and PRListView are in separate files
