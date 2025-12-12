//
//  LoadAxisPicker.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Claude on 2025-12-10.
//  V0.4: Load axis picker for non-weight load tracking (band colors, machine settings)
//

import SwiftUI

#if os(watchOS)

/// Load axis picker component for selecting non-weight load values
struct LoadAxisPicker: View {
    let axisName: String
    let axisType: LoadAxis.AxisType
    let values: [String]
    let targetValue: String?
    @Binding var selectedValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(axisName.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            selectedValue = value
                        } label: {
                            Text(value)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedValue == value ? Color.black : Color.primary)
                                .frame(minWidth: 36, minHeight: 32)
                                .background(selectedValue == value ? Color.green : Color(white: 0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .onAppear {
            // Pre-select target value if specified and not already selected
            if selectedValue == nil, let target = targetValue, values.contains(target) {
                selectedValue = target
            }
        }
    }
}

/// Load axis definition (matches PlanV03 structure)
struct LoadAxis {
    enum AxisType: String {
        case categorical
        case ordinal
    }

    let type: AxisType
    let values: [String]
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LoadAxisPicker(
            axisName: "pin_hole",
            axisType: .ordinal,
            values: ["1", "2", "3", "4", "5", "6", "7", "8"],
            targetValue: "5",
            selectedValue: .constant("5")
        )

        LoadAxisPicker(
            axisName: "band_color",
            axisType: .categorical,
            values: ["red", "blue", "green", "black"],
            targetValue: "blue",
            selectedValue: .constant(nil)
        )
    }
    .padding()
}

#endif
