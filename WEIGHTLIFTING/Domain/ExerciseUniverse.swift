import Foundation

/// Manages the complete universe of exercises (history + plan)
final class ExerciseUniverse {
    private let csvURL: URL
    private let planStore: PlanStore
    private let fileManager: FileManager

    private var cachedExercises: [Exercise]?
    private var lastBuildDate: Date?

    init(
        csvURL: URL,
        planStore: PlanStore = .shared,
        fileManager: FileManager = .default
    ) {
        self.csvURL = csvURL
        self.planStore = planStore
        self.fileManager = fileManager
    }

    /// Get all exercises (union of CSV history + active plan)
    func allExercises() throws -> [Exercise] {
        if let cached = cachedExercises,
           let lastBuild = lastBuildDate,
           Date().timeIntervalSince(lastBuild) < 300 { // 5 min cache
            return cached
        }

        let exercises = try buildExerciseUniverse()
        cachedExercises = exercises
        lastBuildDate = Date()
        return exercises
    }

    /// Get exercise by code
    func exercise(for code: String) throws -> Exercise? {
        try allExercises().first { $0.code == code }
    }

    /// Search exercises by name or code
    func search(_ query: String) throws -> [Exercise] {
        let lowercased = query.lowercased()
        return try allExercises().filter { exercise in
            exercise.code.lowercased().contains(lowercased) ||
            exercise.displayName.lowercased().contains(lowercased)
        }
    }

    /// Invalidate cache (call after plan change or CSV import)
    func invalidateCache() {
        cachedExercises = nil
        lastBuildDate = nil
    }

    private func buildExerciseUniverse() throws -> [Exercise] {
        var exerciseMap: [String: Exercise] = [:]

        // 1. Load exercises from CSV history
        let csvExercises = try loadExercisesFromCSV()
        for exercise in csvExercises {
            exerciseMap[exercise.code] = exercise
        }

        // 2. Enhance with plan metadata (if available)
        if let plan = try? planStore.loadActivePlan() {
            for (code, displayName) in plan.exerciseNames {
                if var existing = exerciseMap[code] {
                    // Update display name from plan
                    existing.displayName = displayName
                    exerciseMap[code] = existing
                } else {
                    // Add exercise from plan (even if not in history yet)
                    let exercise = Exercise(
                        code: code,
                        displayName: displayName,
                        unit: plan.unit,
                        altGroup: findAltGroup(for: code, in: plan)
                    )
                    exerciseMap[code] = exercise
                }
            }
        }

        return exerciseMap.values
            .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private func loadExercisesFromCSV() throws -> [Exercise] {
        guard fileManager.fileExists(atPath: csvURL.path) else {
            return []
        }

        let (_, rows) = try CSVReader.readRows(from: csvURL, fileManager: fileManager)

        var exerciseCodes: Set<String> = []
        var unitMap: [String: WeightUnit] = [:]

        for row in rows {
            let code = row.exerciseCode
            exerciseCodes.insert(code)
            if let unit = WeightUnit.fromCSV(row.unitString) {
                unitMap[code] = unit
            }
        }

        return exerciseCodes.map { code in
            Exercise(
                code: code,
                displayName: nil, // Will be formatted from code
                unit: unitMap[code],
                altGroup: nil
            )
        }
    }

    private func findAltGroup(for exerciseCode: String, in plan: PlanV03) -> String? {
        for (groupName, codes) in plan.altGroups {
            if codes.contains(exerciseCode) {
                return groupName
            }
        }
        return nil
    }

    // MARK: - Canonical Exercise Detection

    /// Detect if exercise is a canonical big lift (Squat/Bench/Deadlift/OHP)
    func canonicalLiftType(for code: String) -> CanonicalLift? {
        let lowercased = code.lowercased()

        // Squat detection
        if lowercased.contains("squat") && !lowercased.contains("front") {
            return .squat
        }

        // Bench press detection
        if (lowercased.contains("bench") || lowercased.contains("press")) &&
           lowercased.contains("bench") &&
           !lowercased.contains("incline") &&
           !lowercased.contains("decline") {
            return .bench
        }

        // Deadlift detection
        if lowercased.contains("deadlift") &&
           !lowercased.contains("rdl") &&
           !lowercased.contains("romanian") {
            return .deadlift
        }

        // Overhead press detection
        if lowercased.contains("press") &&
           !lowercased.contains("bench") &&
           !lowercased.contains("leg") &&
           (lowercased.contains("overhead") ||
            lowercased.contains("ohp") ||
            lowercased.contains("shoulder") ||
            (lowercased.contains("bb") && lowercased.contains("stand"))) {
            return .overheadPress
        }

        return nil
    }
}

// MARK: - Supporting Types

enum CanonicalLift: String, CaseIterable {
    case squat = "Squat"
    case bench = "Bench Press"
    case deadlift = "Deadlift"
    case overheadPress = "Overhead Press"
}

// MARK: - CSV Parsing (reused from adapter)

private extension ExerciseUniverse {
}
