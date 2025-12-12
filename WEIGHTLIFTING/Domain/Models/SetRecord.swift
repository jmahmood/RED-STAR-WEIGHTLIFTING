import Foundation

/// Represents a single set within a workout session
struct SetRecord: Identifiable {
    /// Runtime-only identifier
    let id: UUID

    /// Session this set belongs to
    let sessionID: String

    /// Segment identifier from plan
    let segmentID: Int

    /// Optional superset identifier
    let supersetID: String?

    /// Exercise code (e.g., "PRESS.DB.FLAT")
    let exerciseCode: String

    /// Set number within the exercise
    let setNumber: Int

    /// Reps performed (stored as string to preserve format like "10", "8-12", etc.)
    let reps: String

    /// Weight lifted (nil for bodyweight-only)
    let weight: Double?

    /// Unit (lb, kg, bw)
    let unit: WeightUnit

    /// Whether this is a warmup set
    let isWarmup: Bool

    /// Effort rating (1=easy, 3=expected, 5=hard)
    let effort: Int

    /// Whether this was an ad-lib (unplanned) exercise
    let isAdlib: Bool

    /// RPE value if recorded
    let rpe: String

    /// RIR value if recorded
    let rir: String

    init(
        id: UUID = UUID(),
        sessionID: String,
        segmentID: Int,
        supersetID: String?,
        exerciseCode: String,
        setNumber: Int,
        reps: String,
        weight: Double?,
        unit: WeightUnit,
        isWarmup: Bool,
        effort: Int,
        isAdlib: Bool,
        rpe: String = "",
        rir: String = ""
    ) {
        self.id = id
        self.sessionID = sessionID
        self.segmentID = segmentID
        self.supersetID = supersetID
        self.exerciseCode = exerciseCode
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.unit = unit
        self.isWarmup = isWarmup
        self.effort = effort
        self.isAdlib = isAdlib
        self.rpe = rpe
        self.rir = rir
    }

    /// Calculated tonnage (weight × reps)
    var tonnage: Double? {
        guard let weight = weight,
              let repsValue = Int(reps) else { return nil }
        return weight * Double(repsValue)
    }

    /// Estimated 1RM using Epley formula: weight × (1 + reps / 30)
    var estimated1RM: Double? {
        guard let weight = weight,
              let repsValue = Int(reps),
              repsValue > 0 else { return nil }
        return weight * (1.0 + Double(repsValue) / 30.0)
    }
}
