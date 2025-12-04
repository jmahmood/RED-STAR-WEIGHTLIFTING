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
        guard let csvURL = try? container.fileSystem.globalCsvURL(),
              let content = try? String(contentsOf: csvURL, encoding: .utf8) else {
            return nil
        }

        let lines = content.split(whereSeparator: \.isNewline)
        guard lines.count > 1 else { return nil }

        let headers = parseCSVRow(String(lines[0]))
        guard let sessionIDIndex = headers.firstIndex(of: "session_id"),
              let dayLabelIndex = headers.firstIndex(of: "day"),
              let weightIndex = headers.firstIndex(of: "weight") else {
            return nil
        }

        var sessions: [String: Double] = [:]
        for line in lines.dropFirst() {
            let values = parseCSVRow(String(line))
            guard values.count > max(sessionIDIndex, dayLabelIndex, weightIndex),
                  let weight = Double(values[weightIndex]) else { continue }
            let sessionID = values[sessionIDIndex]
            let dayLabel = values[dayLabelIndex]
            if dayLabel == context.day.label {
                sessions[sessionID, default: 0] += weight
            }
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

    private func parseCSVRow(_ line: String) -> [String] {
        var result: [String] = []
        var buffer = ""
        var insideQuotes = false
        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if insideQuotes && index + 1 < characters.count && characters[index + 1] == "\"" {
                    buffer.append("\"")
                    index += 2
                    continue
                }
                insideQuotes.toggle()
                index += 1
                continue
            }

            if character == "," && !insideQuotes {
                result.append(buffer)
                buffer.removeAll(keepingCapacity: true)
                index += 1
                continue
            }

            buffer.append(character)
            index += 1
        }

        result.append(buffer)
        return result
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