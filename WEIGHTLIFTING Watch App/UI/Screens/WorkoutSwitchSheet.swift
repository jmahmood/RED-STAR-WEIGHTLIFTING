//
//  WorkoutSwitchSheet.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-29.
//

import SwiftUI

struct WorkoutSwitchSheet: View {
    @ObservedObject var vm: SessionVM

    var body: some View {
        NavigationStack {
            List {
                if vm.planDays.isEmpty {
                    Section {
                        Text("No workouts in plan.")
                            .foregroundStyle(.secondary)
                    }
                    .disabled(true)
                } else {
                    Section(vm.planName.isEmpty ? "Workouts" : vm.planName) {
                        ForEach(vm.planDays, id: \.self) { day in
                            HStack {
                                Text(day)
                                if day == vm.activeWorkoutName {
                                    Spacer()
                                    Text("(current)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard day != vm.activeWorkoutName else {
                                    vm.isWorkoutSheetVisible = false
                                    return
                                }
                                vm.switchWorkout(to: day)
                            }
                        }
                    }
                }
            }
            .listStyle(.carousel)
            .navigationTitle("Switch Workout")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let vm = SessionVM()
    vm.planName = "Minimalist 4x"
    vm.planDays = ["Upper A", "Lower A", "Upper B"]
    vm.activeWorkoutName = "Upper A"
    return WorkoutSwitchSheet(vm: vm)
}
