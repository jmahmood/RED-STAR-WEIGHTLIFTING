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
            }
            .padding()
        }
    }

    private func formattedTotalWeight() -> String {
        let total = context.deck
            .filter { completedSetIDs.contains($0.id) }
            .compactMap { $0.prevCompletions.last?.weight }
            .reduce(0, +)
        return "\(Int(total)) \(context.plan.unit.displaySymbol)"
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