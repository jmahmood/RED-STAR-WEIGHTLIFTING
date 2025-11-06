//
//  NextUpWidget.swift
//  WEIGHTLIFTING Complications
//
//  Main widget definition and configuration
//

import WidgetKit
import SwiftUI

/// The Next Up widget showing the upcoming exercise in the workout
struct NextUpWidget: Widget {
    let kind: String = "NextUpWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextUpTimelineProvider()) { entry in
            NextUpWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Up")
        .description("Shows your next exercise in the current workout")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

/// Widget bundle containing all widgets in this extension
@main
struct WEIGHTLIFTINGComplicationsBundle: WidgetBundle {
    var body: some Widget {
        NextUpWidget()
    }
}
