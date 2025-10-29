//
//  SetCardView.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct SetCardView: View {
    let item: DeckItem
    @Binding var weight: Double
    @Binding var reps: Int
    @Binding var effort: DeckItem.Effort
    let setPosition: (current: Int, total: Int)
    let targetDisplay: String
    let prevCompletions: [DeckItem.PrevCompletion]
    let onExerciseTap: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            badgeRow
            DotsView(total: setPosition.total, currentIndex: max(0, setPosition.current - 1))

            VStack(alignment: .leading, spacing: 14) {
                NavigationLink(destination: WeightPickerScreen(value: $weight, unit: item.unit)) {
                    ValueRow(title: "Weight", valueText: weightDisplay, trailing: latestWeightText)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RepsPickerScreen(value: $reps)) {
                    ValueRow(title: "Reps", valueText: "\(reps)", trailing: targetDisplay)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Effort")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    EffortPicker(selected: $effort)
                }

                targetRow
                prevRows
            }

            Spacer()

            Button("Save", action: onSave)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        Button(action: onExerciseTap) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exerciseName)
                        .font(.headline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Set \(setPosition.current) of \(setPosition.total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badgeRow: some View {
        HStack(spacing: 4) {
            ForEach(item.badges, id: \.self) { badge in
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.2))
                    )
            }
        }
        .opacity(item.badges.isEmpty ? 0 : 1)
    }

    private var targetRow: some View {
        Group {
            if !targetDisplay.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
            }
        }
    }

    private var prevRows: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !prevCompletions.isEmpty {
                Text("Prev")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(prevCompletions.prefix(2).enumerated()), id: \.offset) { entry in
                let item = entry.element
                HStack {
                    Text(item.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let w = item.weight {
                        Text(weightDisplay(w))
                            .font(.caption2)
                    }
                    if let reps = item.reps {
                        Text("\(reps) reps")
                            .font(.caption2)
                    }
                    if let effort = item.effort {
                        Text(effort.displayTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .opacity(prevCompletions.isEmpty ? 0 : 1)
    }

    private var weightDisplay: String {
        weightDisplay(weight)
    }

    private var latestWeightText: String? {
        guard let latest = prevCompletions.first, let value = latest.weight else {
            return nil
        }
        return "Prev \(weightDisplay(value))"
    }

    private func weightDisplay(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.0001 {
            return "\(Int(value)) \(item.unit.displaySymbol)"
        }
        return String(format: "%.1f %@", value, item.unit.displaySymbol)
    }
}

#Preview {
    NavigationStack {
        SetCardView(
            item: DeckItem(
                id: UUID(),
                kind: .straight,
                supersetID: nil,
                segmentID: 1,
                sequence: 1,
                setIndex: 1,
                round: nil,
                exerciseCode: "PRESS.DB.FLAT",
                exerciseName: "Dumbbell Press",
                altGroup: "GROUP_CHEST_PRESS",
                targetReps: "8-10",
                unit: .pounds,
                isWarmup: false,
                badges: ["DROP"],
                canSkip: false,
                restSeconds: 120
            ),
            weight: .constant(135),
            reps: .constant(8),
            effort: .constant(.expected),
            setPosition: (current: 1, total: 3),
            targetDisplay: "8-10",
            prevCompletions: [],
            onExerciseTap: {},
            onSave: {}
        )
    }
}

private struct ValueRow: View {
    let title: String
    let valueText: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(valueText)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
