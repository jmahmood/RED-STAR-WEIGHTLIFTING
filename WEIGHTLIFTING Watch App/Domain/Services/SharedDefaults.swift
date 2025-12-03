//
//  SharedDefaults.swift
//  WEIGHTLIFTING Watch App
//
//  Shared UserDefaults storage for App Groups
//  Provides centralized access to shared data between Watch App and Widgets
//

import Foundation

/// Keys for storing complication data (shared between Watch App and Widget Extension)
enum ComplicationDefaultsKey {
    static let exercise = "complication_next_exercise"
    static let detail = "complication_next_detail"
    static let footer = "complication_next_footer"
    static let sessionID = "complication_next_sessionID"
    static let deckIndex = "complication_next_deckIndex"
}

/// Centralized access to shared UserDefaults storage using App Groups
/// This allows data sharing between the Watch App and Widget Extension
final class SharedDefaults {

    // MARK: - Shared Instance

    /// The App Group identifier for sharing data between targets
    private static let appGroupIdentifier = "group.com.jawaadmahmood.WEIGHTLIFTING_SHARED"

    /// Shared UserDefaults suite for the App Group
    static let shared: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            fatalError("Unable to create UserDefaults with suite name: \(appGroupIdentifier)")
        }
        return defaults
    }()
}
