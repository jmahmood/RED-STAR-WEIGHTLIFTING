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
        Button {
            vm.presentWorkoutSwitchSheet()
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.activeWorkoutName.isEmpty ? "—" : vm.activeWorkoutName)
                        .font(.headline)
                        .lineLimit(1)
                    if !vm.planName.isEmpty {
                        Text(vm.planName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
