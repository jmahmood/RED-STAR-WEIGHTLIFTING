//
//  RemainingDrawerView.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct RemainingDrawerView: View {
    let remaining: [DeckItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remaining")
                .font(.headline)

            ForEach(remaining.prefix(3)) { item in
                Text(item.exerciseName)
                    .font(.caption)
            }

            if remaining.count > 3 {
                Text("+\(remaining.count - 3) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let sampleItems = (1...5).map { index in
        DeckItem(
            id: UUID(),
            kind: .straight,
            supersetID: nil,
            segmentID: index,
            sequence: index,
            setIndex: index,
            round: nil,
            exerciseCode: "CODE\(index)",
            exerciseName: "Exercise \(index)",
            altGroup: nil,
            targetReps: "8",
            unit: .pounds,
            isWarmup: false,
            badges: [],
            canSkip: false,
            restSeconds: 90
        )
    }
    return RemainingDrawerView(remaining: sampleItems)
}
