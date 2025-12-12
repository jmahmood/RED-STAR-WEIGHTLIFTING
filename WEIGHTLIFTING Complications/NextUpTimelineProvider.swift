//
//  NextUpTimelineProvider.swift
//  WEIGHTLIFTING Complications
//
//  Timeline Provider for Next Up widget
//

import WidgetKit
import SwiftUI

/// Timeline provider for the Next Up workout complication
struct NextUpTimelineProvider: TimelineProvider {

    // MARK: - TimelineProvider Methods

    /// Provides placeholder data for widget gallery
    func placeholder(in context: Context) -> NextUpEntry {
        return NextUpEntry.placeholder()
    }

    /// Provides a snapshot for widget gallery and transitions
    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) {
        if context.isPreview {
            completion(NextUpEntry.placeholder())
        } else {
            let entry = NextUpEntry.fromSharedDefaults()
            completion(entry)
        }
    }

    /// Provides the timeline of entries for the widget
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        // Get current data from shared storage
        let currentEntry = NextUpEntry.fromSharedDefaults()

        // Create a timeline that refreshes every 5 minutes
        // This ensures the widget updates even if the app doesn't trigger a reload
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()

        let timeline = Timeline(
            entries: [currentEntry],
            policy: .after(refreshDate)
        )

        completion(timeline)
    }
}
