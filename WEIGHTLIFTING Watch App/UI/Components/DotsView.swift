//
//  DotsView.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct DotsView: View {
    let total: Int
    let currentIndex: Int
    private let maxDots = 12

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<visibleCount, id: \.self) { idx in
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1))
                    .background(
                        Circle()
                            .fill(idx == currentIndex ? Color.clear : Color.accentColor)
                    )
                    .frame(width: 6, height: 6)
                    .opacity(idx <= currentIndex ? 1 : 0.4)
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentIndex)
    }

    private var visibleCount: Int {
        min(total, maxDots)
    }

    private var overflowCount: Int {
        max(0, total - maxDots)
    }
}

#Preview {
    DotsView(total: 15, currentIndex: 3)
}
