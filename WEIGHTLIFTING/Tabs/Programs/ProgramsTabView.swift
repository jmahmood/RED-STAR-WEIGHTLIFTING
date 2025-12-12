import SwiftUI

/// Programs tab root view
struct ProgramsTabView: View {
    @EnvironmentObject private var coordinator: TabCoordinator

    var body: some View {

        NavigationStack(path: $coordinator.programsNavPath) {
            ProgramListView()
                .navigationTitle("Programs")
                .navigationDestination(for: ProgramsDestination.self) { destination in
                    switch destination {
                    case .programDetail(let programName):
                        ProgramDetailView(programName: programName)
                    case .programDayDetail(let programName, let dayLabel):
                        ProgramDayDetailView(programName: programName, dayLabel: dayLabel)
                    case .editActiveProgram:
                        EditProgramView()
                    }
                }
        }
    }
}
