//
//  SessionHeaderView.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-29.
//

import SwiftUI

struct SessionHeaderView: View {
    @ObservedObject var vm: SessionVM

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !vm.planName.isEmpty {
                Text(vm.planName)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(vm.activeWorkoutName.isEmpty ? "—" : vm.activeWorkoutName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.presentWorkoutSwitchSheet()
        }
        .accessibilityLabel("Switch workout")
        .accessibilityValue(vm.activeWorkoutName)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    let vm = SessionVM()
    vm.planName = "Minimalist 4x"
    vm.planDays = ["Upper A", "Lower A", "Upper B"]
    vm.activeWorkoutName = "Upper A"
    return SessionHeaderView(vm: vm)
}
