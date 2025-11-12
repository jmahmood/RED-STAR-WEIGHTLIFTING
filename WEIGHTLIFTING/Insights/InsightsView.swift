//
//  InsightsView.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-11-02.
//

import SwiftUI

struct InsightsView: View {
    let snapshot: InsightsSnapshot

    var body: some View {
        VStack(spacing: 16) {
            PersonalRecordsCard(state: snapshot.personalRecords)
            NextWorkoutCard(state: snapshot.nextWorkout)
        }
    }
}

private struct PersonalRecordsCard: View {
    let state: CardState<[PersonalRecordDisplay]>
    private let dateFormatter = DateFormatter.shortStyle

    var body: some View {
        InsightCard(title: "Personal Records (all-time)", subtitle: "NEW = set in last 30 days") {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            case .empty(let message):
                Text(message)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
            case .error(let message):
                Text(message)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.red)
            case .ready(let records):
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(record.exerciseName)
                                    .font(.headline)
                                if record.isNew {
                                    Text("NEW")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.green.opacity(0.2)))
                                }
                            }
                            if let primary = record.primary {
                                HStack(spacing: 8) {
                                    Text(primary.kind.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(InsightsFormatter.weight(value: primary.value, unit: record.unitSymbol))
                                        .font(.body.weight(.semibold))
                                        .monospacedDigit()
                                    Text(InsightsFormatter.setDetail(weight: primary.weight, reps: primary.reps, unit: record.unitSymbol))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dateFormatter.string(from: primary.date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let message = record.missingPrimaryMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let secondary = record.secondary {
                                HStack(spacing: 8) {
                                    Text(secondary.kind.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(InsightsFormatter.volume(value: secondary.value, unit: record.unitSymbol))
                                        .font(.subheadline)
                                        .monospacedDigit()
                                    Text(InsightsFormatter.setDetail(weight: secondary.weight, reps: secondary.reps, unit: record.unitSymbol))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if record.id != records.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct NextWorkoutCard: View {
    let state: CardState<NextWorkoutDisplay>

    var body: some View {
        InsightCard(title: "Next Workout", subtitle: subtitle) {
            switch state {
            case .loading:
                ProgressView()
            case .empty(let message):
                Text(message)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .error(let message):
                Text(message)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .ready(let display):
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(display.lines) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(line.name)
                                    .font(.body)
                                Spacer()
                                Text(line.targetReps)
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if !line.badges.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(line.badges, id: \.self) { badge in
                                        Text("[\(badge)]")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if line.id != display.lines.last?.id {
                            Divider()
                        }
                    }
                    if display.remainingCount > 0 {
                        Text("+\(display.remainingCount) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if display.timedSetsSkipped {
                        Text("Timed sets not supported (skipped).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var subtitle: String? {
        guard case let .ready(display) = state else { return nil }
        return "\(display.planName) • \(display.dayLabel)"
    }
}

private struct InsightCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private enum InsightsFormatter {
    static func weight(value: Double, unit: String?) -> String {
        guard let unit else {
            return numberFormatter(decimals: 1, grouping: false).string(from: NSNumber(value: value)) ?? "\(value)"
        }
        switch unit.lowercased() {
        case "kg":
            let formatted = numberFormatter(decimals: 1, grouping: false).string(from: NSNumber(value: value)) ?? "\(value)"
            return "\(formatted) kg"
        case "lb":
            let formatted = numberFormatter(decimals: 0, grouping: false).string(from: NSNumber(value: value)) ?? "\(value)"
            return "\(formatted) lb"
        default:
            return numberFormatter(decimals: 1, grouping: false).string(from: NSNumber(value: value)) ?? "\(value)"
        }
    }

    static func volume(value: Double, unit: String?) -> String {
        let formatted = numberFormatter(decimals: 0, grouping: true).string(from: NSNumber(value: value)) ?? "\(value)"
        if let unit {
            return "\(formatted) \(unit)"
        }
        return formatted
    }

    static func setDetail(weight: Double, reps: Int, unit: String?) -> String {
        let weightString: String
        if let unit {
            let decimals = unit.lowercased() == "kg" ? 1 : 0
            weightString = numberFormatter(decimals: decimals, grouping: false).string(from: NSNumber(value: weight)) ?? "\(weight)"
        } else {
            weightString = numberFormatter(decimals: 1, grouping: false).string(from: NSNumber(value: weight)) ?? "\(weight)"
        }
        return "(\(reps)×\(weightString))"
    }

    private static func numberFormatter(decimals: Int, grouping: Bool) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = grouping ? .decimal : .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.usesGroupingSeparator = grouping
        formatter.locale = Locale.current
        return formatter
    }
}

private extension DateFormatter {
    static let shortStyle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}
