//
//  ToastUndoChip.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI
import Combine

struct ToastUndoChip: View {
    let title: String
    let actionTitle: String
    let deadline: Date
    let action: () -> Void

    @State private var now = Date()

    private var countdown: Int {
        max(0, Int(deadline.timeIntervalSince(now).rounded(.down)))
    }

    var body: some View {
        Text("✓ \(title) • Tap to \(actionTitle.lowercased()) (\(countdown)s)")
            .font(.caption2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.25))
            )
            .onTapGesture {
                action()
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { t in
                if countdown > 0 { now = t }
            }
    }
}

#Preview {
    ToastUndoChip(title: "Saved", actionTitle: "Undo", deadline: Date().addingTimeInterval(5), action: {})
}
