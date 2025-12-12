import SwiftUI

/// Main container view with tabs for Next, Insights, Programs, and Data
struct TabContainerView: View {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var coordinator = TabCoordinator()
    @StateObject private var exportStore: ExportInboxStore

    init(exportStore: ExportInboxStore) {
        _exportStore = StateObject(wrappedValue: exportStore)
    }

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            NextTabView()
                .tabItem {
                    Label("Next", systemImage: "dumbbell.fill")
                }
                .tag(AppTab.next)

            InsightsTabView()
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.insights)

            ProgramsTabView()
                .tabItem {
                    Label("Programs", systemImage: "list.bullet.clipboard")
                }
                .tag(AppTab.programs)

            DataTabView()
                .tabItem {
                    Label("Data", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(AppTab.data)
        }
        .environmentObject(coordinator)
        .environmentObject(exportStore)
    }
}
