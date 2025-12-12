//
//  EndOfSessionView.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-29.
//

import SwiftUI

struct EndOfSessionView: View {
    @EnvironmentObject private var container: AppContainer
    let context: SessionContext
    let completedSetIDs: Set<UUID>
    let onStartNewSession: () -> Void
    let onAddAdhoc: () -> Void
    let onExportToPhone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Session Complete!")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                 VStack(alignment: .leading, spacing: 8) {
                     Text("Summary:")
                         .font(.subheadline)
                         .foregroundStyle(.secondary)

                     Text("Sets completed: \(completedSetIDs.count)")
                     Text("Total weight: \(formattedTotalWeight())")
                     Text("Duration: \(formattedDuration())")

                     if let previous = previousSessionTotalWeight() {
                         HStack {
                             Text("vs Last: \(Int(previous)) \(context.plan.unit.displaySymbol)")
                             if totalWeight > previous {
                                 Image(systemName: "chevron.up")
                                     .foregroundColor(.green)
                             }
                         }
                         .font(.subheadline)
                         .foregroundStyle(.secondary)
                     }
                 }
                 .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Button("Start New Session") {
                    onStartNewSession()
                }
                .buttonStyle(.borderedProminent)

                Button("Add Adhoc Exercise") {
                    onAddAdhoc()
                }
                .buttonStyle(.bordered)

                Button {
                    onExportToPhone()
                } label: {
                    Label("Send to iPhone", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
            .padding()
        }
    }

    private var totalWeight: Double {
        context.deck
            .filter { completedSetIDs.contains($0.id) }
            .compactMap { $0.prevCompletions.last?.weight }
            .reduce(0, +)
    }

    private func formattedTotalWeight() -> String {
        "\(Int(totalWeight)) \(context.plan.unit.displaySymbol)"
    }

    private func previousSessionTotalWeight() -> Double? {
        // Parse CSV to find last session with same dayLabel
        guard let csvURL = try? container.fileSystem.globalCsvURL() else {
            return nil
        }
        guard let (_, rows) = try? CSVReader.readRows(from: csvURL) else { return nil }

        var sessions: [String: Double] = [:]
        for row in rows {
            guard row.dayLabel == context.day.label else { continue }
            guard let weight = row.weight else { continue }
            sessions[row.sessionID, default: 0] += weight
        }

        // Find the most recent session before current
        let currentSessionDate = parseSessionDate(context.sessionID)
        let sortedSessions = sessions.sorted { lhs, rhs in
            let lhsDate = parseSessionDate(lhs.key)
            let rhsDate = parseSessionDate(rhs.key)
            return (lhsDate ?? Date.distantPast) > (rhsDate ?? Date.distantPast)
        }

        for (sessionID, total) in sortedSessions {
            if let sessionDate = parseSessionDate(sessionID),
               sessionDate < (currentSessionDate ?? Date()) {
                return total
            }
        }
        return nil
    }

    private func parseSessionDate(_ sessionID: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: String(sessionID.prefix(10)))
    }

    private func formattedDuration() -> String {
        guard let start = parseSessionStart(context.sessionID) else {
            return "—"
        }
        guard let end = (context.deck
            .filter { completedSetIDs.contains($0.id) }
            .compactMap { $0.prevCompletions.last?.date }
            .max()) else {
            return "—"
        }
        let duration = end.timeIntervalSince(start)
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }

    private func parseSessionStart(_ sessionID: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return formatter.date(from: sessionID)
    }
}
