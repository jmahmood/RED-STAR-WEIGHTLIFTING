//
//  WorkoutMenuView.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct WorkoutMenuView: View {
    @ObservedObject var vm: SessionVM
    let onExport: () -> Void
    let onAddExercise: (() -> Void)?

    var body: some View {
        List {
            Button("Switch Workout") {
                vm.presentWorkoutSwitchFromMenu()
            }

            Button("Export CSV to Phone") {
                vm.dismissWorkoutMenu()
                DispatchQueue.main.async {
                    onExport()
                }
            }

            if let onAddExercise {
                Button("Add Exercise") {
                    vm.dismissWorkoutMenu()
                    DispatchQueue.main.async {
                        onAddExercise()
                    }
                }
            }
        }
        .navigationTitle("Workout")
    }
}

#Preview {
    let vm = SessionVM()
    vm.planName = "Minimalist 4x"
    vm.activeWorkoutName = "Upper A"
    return WorkoutMenuView(vm: vm, onExport: {}, onAddExercise: {})
}
