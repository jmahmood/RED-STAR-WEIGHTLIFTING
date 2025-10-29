//
//  WeightUnit.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

enum WeightUnit: String, Codable, Hashable {
    case pounds = "lb"
    case kilograms = "kg"

    init(planString: String) {
        switch planString.lowercased() {
        case "kg", "kgs", "kilogram", "kilograms":
            self = .kilograms
        default:
            self = .pounds
        }
    }

    var csvValue: String { rawValue }
    var displaySymbol: String {
        switch self {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        }
    }
}
