//
//  EffortPicker.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct EffortPicker: View {
    @Binding var selected: DeckItem.Effort

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DeckItem.Effort.allCases, id: \.self) { effort in
                Button(action: { selected = effort }) {
                    Text(effort.displayTitle)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EffortButtonStyle(isSelected: effort == selected))
            }
        }
    }
}

private struct EffortButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            )
            .foregroundStyle(isSelected ? Color.black : Color.primary)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview {
    EffortPicker(selected: .constant(.expected))
        .padding()
}
