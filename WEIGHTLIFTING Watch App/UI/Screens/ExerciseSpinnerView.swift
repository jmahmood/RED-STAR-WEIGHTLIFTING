//
//  ExerciseSpinnerView.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct ExerciseSpinnerView: View {
    let exercises: [String]
    @State private var selection: String
    let apply: (String, Bool) -> Void

    init(exercises: [String], current: String, apply: @escaping (String, Bool) -> Void) {
        self.exercises = exercises
        self._selection = State(initialValue: current)
        self.apply = apply
    }

    var body: some View {
        VStack {
            Picker("Exercise", selection: $selection) {
                ForEach(exercises, id: \.self) { ex in
                    Text(ex).tag(ex)
                }
            }
            .pickerStyle(.wheel)

            Button("Apply to Remaining") {
                apply(selection, true)
            }

            Button("This Set Only") {
                apply(selection, false)
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding()
    }
}

#Preview {
    ExerciseSpinnerView(exercises: ["PRESS.DB.FLAT", "PRESS.DB.INCL"], current: "PRESS.DB.FLAT") { _, _ in }
}
