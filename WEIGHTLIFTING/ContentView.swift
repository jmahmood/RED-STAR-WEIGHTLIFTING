//
//  ContentView.swift
//  WEIGHTLIFTING
//
//  Created by Jawaad Mahmood on 2025-10-28.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SessionViewModel(
        currentSet: SessionSet(
            exerciseName: "Bench Press",
            exCode: "BENCH.PRESS.BB",
            weight: nil,
            unit: "lb",
            reps: nil
        )
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.currentSet.exerciseName)
                .font(.title3)
                .bold()

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let latest = viewModel.latestWeightLabel {
                        Text("-> \(latest)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if let weight = viewModel.currentSet.weight {
                    Text(weightString(weight, unit: viewModel.currentSet.unit))
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let reps = viewModel.currentSet.reps {
                    Text("\(reps)")
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.previousEntries.isEmpty {
                Text("Prev: None")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.previousEntries.enumerated()), id: \.offset) { _, entry in
                    Text(entry.displayString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.prefillWeight()
        }
    }

    private func weightString(_ weight: Double, unit: String) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) \(unit)"
        } else {
            return "\(String(format: "%.1f", weight)) \(unit)"
        }
    }
}

#Preview {
    ContentView()
}
