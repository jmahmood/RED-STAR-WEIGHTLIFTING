//
//  NextUpEntry.swift
//  WEIGHTLIFTING Complications
//
//  Widget Entry model for Next Up complication
//

import WidgetKit
import Foundation

/// Timeline entry for the Next Up widget
struct NextUpEntry: TimelineEntry {
    let date: Date
    let exerciseName: String?
    let detail: String?
    let footer: String?

    /// Indicates whether this is placeholder/sample data
    var isPlaceholder: Bool {
        return exerciseName == nil
    }

    /// Creates a placeholder entry for widget previews
    static func placeholder() -> NextUpEntry {
        return NextUpEntry(
            date: Date(),
            exerciseName: "Bench Press",
            detail: "135lb × 8",
            footer: "••• +2"
        )
    }

    /// Creates an empty entry when no workout is active
    static func empty() -> NextUpEntry {
        return NextUpEntry(
            date: Date(),
            exerciseName: nil,
            detail: nil,
            footer: nil
        )
    }

    /// Creates an entry from shared UserDefaults data
    static func fromSharedDefaults() -> NextUpEntry {
        let defaults = SharedDefaults.shared

        guard let exerciseName = defaults.string(forKey: ComplicationDefaultsKey.exercise),
              !exerciseName.isEmpty else {
            return empty()
        }

        let detail = defaults.string(forKey: ComplicationDefaultsKey.detail)
        let footer = defaults.string(forKey: ComplicationDefaultsKey.footer)

        return NextUpEntry(
            date: Date(),
            exerciseName: exerciseName,
            detail: detail,
            footer: footer
        )
    }
}
