//
//  RepsPickerScreen.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct RepsPickerScreen: View {
    @Binding var value: Int
    @State private var selectionIndex: Int
    private let range = Array(1...30)

    init(value: Binding<Int>) {
        self._value = value
        let initialValue = value.wrappedValue
        self._selectionIndex = State(initialValue: min(max(initialValue, 1), 30))
    }

    var body: some View {
        Picker("Reps", selection: $selectionIndex) {
            ForEach(range, id: \.self) { reps in
                Text("\(reps)").tag(reps)
            }
        }
        .navigationTitle("Reps")
        .pickerStyle(.wheel)
        .onDisappear {
            value = selectionIndex
        }
    }
}

#Preview {
    NavigationStack {
        RepsPickerScreen(value: .constant(10))
    }
}
