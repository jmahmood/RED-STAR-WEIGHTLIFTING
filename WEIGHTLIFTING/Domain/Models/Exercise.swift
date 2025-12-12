import Foundation

/// Represents an exercise in the workout universe
struct Exercise: Identifiable, Hashable {
    /// Raw exercise code from CSV (e.g., "PRESS.DB.FLAT")
    let code: String

    /// Display name (from plan dictionary or formatted code)
    var displayName: String

    /// Unit for this exercise (from plan or inferred from history)
    let unit: WeightUnit?

    /// Alternative exercise group (from plan)
    let altGroup: String?

    var id: String { code }

    init(code: String, displayName: String? = nil, unit: WeightUnit? = nil, altGroup: String? = nil) {
        self.code = code
        self.displayName = displayName ?? Exercise.formatExerciseCode(code)
        self.unit = unit
        self.altGroup = altGroup
    }

    /// Format exercise code for display by replacing underscores/dashes with spaces and capitalizing
    static func formatExerciseCode(_ code: String) -> String {
        code
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}
