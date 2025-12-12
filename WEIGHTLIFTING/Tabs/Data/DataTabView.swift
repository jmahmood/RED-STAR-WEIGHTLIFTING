import SwiftUI

/// Data tab root view
struct DataTabView: View {
    @EnvironmentObject private var coordinator: TabCoordinator

    var body: some View {

        NavigationStack(path: $coordinator.dataNavPath) {
            DataOverviewView()
                .navigationTitle("Data")
                .navigationDestination(for: DataDestination.self) { destination in
                    switch destination {
                    case .exportHistory:
                        ExportHistoryView()
                    case .diagnostics:
                        DiagnosticsView()
                    case .storedLinks:
                        StoredLinksView()
                    }
                }
        }
    }
}

/// Export history placeholder
struct ExportHistoryView: View {
    var body: some View {
        List {
            Section("Recent Exports") {
                Text("No exports yet")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Export History")
    }
}
