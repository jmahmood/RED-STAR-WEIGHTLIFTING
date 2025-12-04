import Foundation

/// Represents a complete workout session
struct WorkoutSession: Identifiable {
    /// Session identifier from CSV (canonical)
    let id: String

    /// Session date
    let date: Date

    /// Session start time (HH:mm:ss format)
    let time: String

    /// Plan name this session belongs to
    let planName: String

    /// Day label from plan (e.g., "Push Day A")
    let dayLabel: String

    /// All sets performed in this session
    let sets: [SetRecord]

    init(
        id: String,
        date: Date,
        time: String,
        planName: String,
        dayLabel: String,
        sets: [SetRecord]
    ) {
        self.id = id
        self.date = date
        self.time = time
        self.planName = planName
        self.dayLabel = dayLabel
        self.sets = sets
    }

    /// Total volume (tonnage) for the session
    var totalVolume: Double {
        sets.compactMap { $0.tonnage }.reduce(0, +)
    }

    /// Number of unique exercises performed
    var uniqueExercises: Int {
        Set(sets.map { $0.exerciseCode }).count
    }

    /// Total number of sets (excluding warmups)
    var workingSets: Int {
        sets.filter { !$0.isWarmup }.count
    }

    /// Total number of sets (including warmups)
    var totalSets: Int {
        sets.count
    }

    /// Get sets grouped by exercise code
    var setsByExercise: [String: [SetRecord]] {
        Dictionary(grouping: sets, by: { $0.exerciseCode })
    }

    /// Duration is not available with current data (session-level timestamps only)
    var duration: TimeInterval? { nil }

    /// Get all unique exercises in this session
    func exercises(from exerciseUniverse: [Exercise]) -> [Exercise] {
        let codes = Set(sets.map { $0.exerciseCode })
        return exerciseUniverse.filter { codes.contains($0.code) }
    }
}
