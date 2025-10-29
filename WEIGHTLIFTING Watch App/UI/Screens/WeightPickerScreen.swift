//
//  WeightPickerScreen.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

struct WeightPickerScreen: View {
    @Binding var value: Double
    let unit: WeightUnit

    private var step: Double {
        switch unit {
        case .pounds: return 2.5
        case .kilograms: return 0.5
        }
    }

    private var selection: Binding<Int> {
        Binding(
            get: {
                clamp(Int(round(value / step)))
            },
            set: { newValue in
                value = Double(newValue) * step
            }
        )
    }

    private var range: [Int] {
        switch unit {
        case .pounds:
            return Array(Int(-300 / step)...Int(1000 / step))
        case .kilograms:
            return Array(Int(-200 / step)...Int(450 / step))
        }
    }

    var body: some View {
        Picker("Weight", selection: selection) {
            ForEach(range, id: \.self) { value in
                Text(display(value)).tag(value)
            }
        }
        .navigationTitle("Weight")
        .pickerStyle(.wheel)
    }

    private func clamp(_ raw: Int) -> Int {
        guard let lower = range.first, let upper = range.last else { return raw }
        return min(max(raw, lower), upper)
    }

    private func display(_ raw: Int) -> String {
        let actual = Double(raw) * step
        let text: String
        if abs(actual - actual.rounded()) < 0.0001 {
            text = "\(Int(actual))"
        } else {
            text = String(format: "%.1f", actual)
        }
        return "\(text) \(unit.displaySymbol)"
    }
}

#Preview {
    NavigationStack {
        WeightPickerScreen(value: .constant(135), unit: .pounds)
    }
}
