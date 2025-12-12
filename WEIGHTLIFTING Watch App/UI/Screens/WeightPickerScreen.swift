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

    @State private var selectionIndex: Int

    private let step: Double
    private let pickerRange: [Int]

    init(value: Binding<Double>, unit: WeightUnit) {
        let initialValue = value.wrappedValue
        let step = Self.step(for: unit)
        let pickerRange = Self.range(for: unit)
        let initialIndex = Self.clamp(Int(round(initialValue / step)), range: pickerRange)
        self._value = value
        self.unit = unit
        self.step = step
        self.pickerRange = pickerRange
        self._selectionIndex = State(initialValue: initialIndex)
    }

    private static func step(for unit: WeightUnit) -> Double {
        switch unit {
        case .pounds: return 2.5
        case .kilograms: return 0.5
        }
    }

    private static func range(for unit: WeightUnit) -> [Int] {
        let step = Self.step(for: unit)
        switch unit {
        case .pounds:
            return Array(Int(-300 / step)...Int(1000 / step))
        case .kilograms:
            return Array(Int(-200 / step)...Int(450 / step))
        }
    }

    private static func clamp(_ raw: Int, range: [Int]) -> Int {
        guard let lower = range.first, let upper = range.last else { return raw }
        return min(max(raw, lower), upper)
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
        Picker("Weight", selection: $selectionIndex) {
            ForEach(pickerRange, id: \.self) { value in
                Text(display(value)).tag(value)
            }
        }
        .navigationTitle("Weight")
        .pickerStyle(.wheel)
        .onDisappear {
            value = Double(selectionIndex) * step
        }
    }

    private func clamp(_ raw: Int) -> Int {
        let range = Self.range(for: unit)
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
