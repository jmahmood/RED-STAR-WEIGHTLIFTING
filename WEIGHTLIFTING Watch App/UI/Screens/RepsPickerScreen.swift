//
//  RepsPickerScreen.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct RepsPickerScreen: View {
    @Binding var value: Int
    private let range = Array(1...30)

    var body: some View {
        Picker("Reps", selection: $value) {
            ForEach(range, id: \.self) { reps in
                Text("\(reps)").tag(reps)
            }
        }
        .navigationTitle("Reps")
        .pickerStyle(.wheel)
    }
}

#Preview {
    NavigationStack {
        RepsPickerScreen(value: .constant(10))
    }
}
