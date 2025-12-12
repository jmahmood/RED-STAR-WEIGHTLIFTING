//
//  UndoChip.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-29.
//

import SwiftUI
import Combine

struct UndoChip: View {
    @State private var now = Date()
    let deadline: Date

    var remaining: Int { max(0, Int(deadline.timeIntervalSince(now).rounded(.down))) }

    var body: some View {
        Text("Undo (\(remaining)s)")
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { t in
                // tick only while chip visible
                if remaining > 0 { now = t }
            }
    }
}