//
//  NextUpWidgetView.swift
//  WEIGHTLIFTING Complications
//
//  SwiftUI views for Next Up widget across all complication families
//

import SwiftUI
import WidgetKit

/// Main widget view that adapts to different complication families
struct NextUpWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: NextUpEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularView(entry: entry)
            case .accessoryRectangular:
                RectangularView(entry: entry)
            case .accessoryInline:
                InlineView(entry: entry)
            case .accessoryCorner:
                CornerView(entry: entry)
            @unknown default:
                RectangularView(entry: entry)
            }
        }
        .widgetURL(deepLinkURL())
    }

    /// Creates a deep link URL to open the workout session
    private func deepLinkURL() -> URL? {
        // Deep link to the current workout session
        return URL(string: "weightlifting://workout/current")
    }
}

// MARK: - Circular Complication

/// Circular complication view (small, round complications)
struct CircularView: View {
    let entry: NextUpEntry

    var body: some View {
        if let exerciseName = entry.exerciseName {
            VStack(spacing: 2) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 20))
                Text(repsOnly() ?? "")
                    .font(.system(size: 16, weight: .semibold))
            }
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 24))
        }
    }

    private func repsOnly() -> String? {
        guard let detail = entry.detail else { return nil }
        // Extract just the reps number if format is "weight × reps"
        if let index = detail.lastIndex(of: "×") {
            let reps = detail[detail.index(after: index)...].trimmingCharacters(in: .whitespaces)
            return reps
        }
        return detail
    }
}

// MARK: - Rectangular Complication

/// Rectangular complication view (standard horizontal complications)
struct RectangularView: View {
    let entry: NextUpEntry

    var body: some View {
        if let exerciseName = entry.exerciseName {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14))
                    Text(exerciseName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }

                if let detail = entry.detail {
                    Text(detail)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                }

                if let footer = entry.footer, !footer.isEmpty {
                    Text(footer)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14))
                    Text("No Active Workout")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Inline Complication

/// Inline complication view (single line of text)
struct InlineView: View {
    let entry: NextUpEntry

    var body: some View {
        if let exerciseName = entry.exerciseName {
            HStack(spacing: 4) {
                Image(systemName: "figure.strengthtraining.traditional")
                if let detail = entry.detail {
                    Text("\(exerciseName): \(detail)")
                } else {
                    Text(exerciseName)
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "figure.strengthtraining.traditional")
                Text("No workout")
            }
        }
    }
}

// MARK: - Corner Complication

/// Corner complication view (wraps around watch face corner)
struct CornerView: View {
    let entry: NextUpEntry

    var body: some View {
        if let exerciseName = entry.exerciseName {
            VStack(spacing: 0) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16))
                if let detail = entry.detail {
                    Text(repsOnly(from: detail))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 20))
        }
    }

    private func repsOnly(from detail: String) -> String {
        // Extract just the reps number if format is "weight × reps"
        if let index = detail.lastIndex(of: "×") {
            return detail[detail.index(after: index)...].trimmingCharacters(in: .whitespaces)
        }
        return detail
    }
}

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    NextUpWidget()
} timeline: {
    NextUpEntry.placeholder()
    NextUpEntry.empty()
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NextUpWidget()
} timeline: {
    NextUpEntry.placeholder()
    NextUpEntry.empty()
}

#Preview("Inline", as: .accessoryInline) {
    NextUpWidget()
} timeline: {
    NextUpEntry.placeholder()
    NextUpEntry.empty()
}
