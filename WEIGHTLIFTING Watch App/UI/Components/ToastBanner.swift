//
//  ToastBanner.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-29.
//

import SwiftUI

struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.25))
            )
    }
}

#Preview {
    ToastBanner(message: "Switched to Upper A")
}
