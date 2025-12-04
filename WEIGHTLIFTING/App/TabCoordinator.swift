import Foundation
import SwiftUI
import Combine

/// Coordinates navigation across tabs
final class TabCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .next
    @Published var nextNavPath = NavigationPath()
    @Published var insightsNavPath = NavigationPath()
    @Published var programsNavPath = NavigationPath()
    @Published var dataNavPath = NavigationPath()

    // MARK: - Cross-Tab Navigation

    /// Navigate to exercise detail in Insights tab
    func navigateToExerciseDetail(_ exerciseCode: String) {
        selectedTab = .insights
        insightsNavPath.append(InsightsDestination.exerciseDetail(exerciseCode))
    }

    /// Navigate to session detail in Insights tab
    func navigateToSessionDetail(_ sessionID: String) {
        selectedTab = .insights
        insightsNavPath.append(InsightsDestination.sessionDetail(sessionID))
    }

    /// Navigate to PR list in Insights tab
    func navigateToPRList() {
        selectedTab = .insights
        insightsNavPath.append(InsightsDestination.prList)
    }

    /// Navigate to Programs tab
    func navigateToPrograms() {
        selectedTab = .programs
    }

    /// Navigate to program detail in Programs tab
    func navigateToProgramDetail(_ programName: String) {
        selectedTab = .programs
        programsNavPath.append(ProgramsDestination.programDetail(programName))
    }

    /// Navigate to Data tab
    func navigateToData() {
        selectedTab = .data
    }

    // MARK: - Path Reset

    func resetAllPaths() {
        nextNavPath = NavigationPath()
        insightsNavPath = NavigationPath()
        programsNavPath = NavigationPath()
        dataNavPath = NavigationPath()
    }
}

// MARK: - Tab Definition

enum AppTab: Hashable {
    case next
    case insights
    case programs
    case data
}

// MARK: - Navigation Destinations

enum InsightsDestination: Hashable {
    case exerciseDetail(String)
    case sessionDetail(String)
    case prList
}

enum ProgramsDestination: Hashable {
    case programDetail(String)
    case programDayDetail(String, String) // programName, dayLabel
}

enum DataDestination: Hashable {
    case exportHistory
    case diagnostics
}
