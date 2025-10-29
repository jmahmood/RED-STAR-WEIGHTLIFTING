//
//  ToastUndoChip.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct ToastUndoChip: View {
    let title: String
    let actionTitle: String
    let countdown: Int
    let action: () -> Void

    var body: some View {
        HStack {
            Text("\(title) (\(countdown)s)")
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }
}

#Preview {
    ToastUndoChip(title: "Saved", actionTitle: "Undo", countdown: 5, action: {})
}
