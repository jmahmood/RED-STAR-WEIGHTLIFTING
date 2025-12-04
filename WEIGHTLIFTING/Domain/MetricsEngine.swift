import Foundation

/// Time range for metrics calculations
enum TimeRange: String, CaseIterable {
    case fourWeeks = "4w"
    case threeMonths = "3m"
    case sixMonths = "6m"
    case oneYear = "1y"
    case allTime = "All"

    var days: Int? {
        switch self {
        case .fourWeeks: return 28
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .allTime: return nil
        }
    }

    var displayName: String {
        switch self {
        case .fourWeeks: return "4 Weeks"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        case .allTime: return "All Time"
        }
    }
}

/// Computes derived metrics from workout sessions
final class MetricsEngine {
    private let adapter: WorkoutSessionAdapter
    private let exerciseUniverse: ExerciseUniverse

    init(adapter: WorkoutSessionAdapter, exerciseUniverse: ExerciseUniverse) {
        self.adapter = adapter
        self.exerciseUniverse = exerciseUniverse
    }

    /// Compute metrics for a specific time range
    func computeMetrics(for range: TimeRange) throws -> MetricsSummary {
        let sessions: [WorkoutSession]
        if let days = range.days {
            sessions = try adapter.loadRecentSessions(days: days)
        } else {
            sessions = try adapter.loadAllSessions()
        }

        let exerciseMetrics = computeExerciseMetrics(from: sessions)
        let globalMetrics = computeGlobalMetrics(from: sessions)
        let topExercises = identifyTopExercises(from: exerciseMetrics)

        return MetricsSummary(
            timeRange: range,
            exerciseMetrics: exerciseMetrics,
            globalMetrics: globalMetrics,
            topExercises: topExercises
        )
    }

    /// Get metrics for a specific exercise
    func exerciseMetrics(for exerciseCode: String, range: TimeRange) throws -> ExerciseMetrics? {
        let summary = try computeMetrics(for: range)
        return summary.exerciseMetrics[exerciseCode]
    }

    /// Get recent sessions for an exercise
    func recentSessions(for exerciseCode: String, limit: Int = 10) throws -> [WorkoutSession] {
        let allSessions = try adapter.loadAllSessions()
        return allSessions
            .filter { session in
                session.sets.contains { $0.exerciseCode == exerciseCode }
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Get strength change percentage for top lifts
    func strengthChange(for range: TimeRange) throws -> Double? {
        let summary = try computeMetrics(for: range)
        let topLiftCodes = summary.topExercises.prefix(4).map { $0.exerciseCode }

        var totalChange: Double = 0
        var count = 0

        for code in topLiftCodes {
            if let change = try computeStrengthChange(for: code, range: range) {
                totalChange += change
                count += 1
            }
        }

        return count > 0 ? totalChange / Double(count) : nil
    }

    /// Compute volume change for a time range
    func volumeChange(for range: TimeRange) throws -> Double? {
        guard let days = range.days else { return nil }

        let recentSessions = try adapter.loadRecentSessions(days: days)
        let previousSessions = try adapter.loadSessions(
            from: Calendar.current.date(byAdding: .day, value: -days * 2, to: Date()) ?? Date(),
            to: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        )

        let recentVolume = recentSessions.map { $0.totalVolume }.reduce(0, +)
        let previousVolume = previousSessions.map { $0.totalVolume }.reduce(0, +)

        guard previousVolume > 0 else { return nil }
        return ((recentVolume - previousVolume) / previousVolume) * 100.0
    }

    /// Compute sessions per week change
    func sessionsPerWeekChange(for range: TimeRange) throws -> Double? {
        guard let days = range.days else { return nil }

        let recentSessions = try adapter.loadRecentSessions(days: days)
        let previousSessions = try adapter.loadSessions(
            from: Calendar.current.date(byAdding: .day, value: -days * 2, to: Date()) ?? Date(),
            to: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        )

        let recentPerWeek = Double(recentSessions.count) / Double(days) * 7.0
        let previousPerWeek = Double(previousSessions.count) / Double(days) * 7.0

        guard previousPerWeek > 0 else { return nil }
        return ((recentPerWeek - previousPerWeek) / previousPerWeek) * 100.0
    }

    // MARK: - Private Helpers

    private func computeExerciseMetrics(from sessions: [WorkoutSession]) -> [String: ExerciseMetrics] {
        var metricsMap: [String: ExerciseMetrics] = [:]

        for session in sessions {
            for (exerciseCode, sets) in session.setsByExercise {
                var metrics = metricsMap[exerciseCode] ?? ExerciseMetrics(exerciseCode: exerciseCode)

                // Update best e1RM
                for set in sets where !set.isWarmup {
                    if let e1rm = set.estimated1RM {
                        if let currentBest = metrics.best1RM {
                            if e1rm > currentBest.value {
                                metrics.best1RM = MetricPoint(value: e1rm, date: session.date, set: set)
                            }
                        } else {
                            metrics.best1RM = MetricPoint(value: e1rm, date: session.date, set: set)
                        }
                    }
                }

                // Update volume
                let sessionVolume = sets.filter { !$0.isWarmup }.compactMap { $0.tonnage }.reduce(0, +)
                metrics.totalVolume += sessionVolume
                metrics.sessionCount += 1
                metrics.volumePerSession.append(VolumePoint(date: session.date, volume: sessionVolume))

                // Update frequency (sessions per week)
                if !metrics.sessionDates.contains(session.date) {
                    metrics.sessionDates.insert(session.date)
                }

                metricsMap[exerciseCode] = metrics
            }
        }

        // Calculate frequency for each exercise
        for (code, var metrics) in metricsMap {
            metrics.frequencyPerWeek = calculateFrequency(from: metrics.sessionDates)
            metricsMap[code] = metrics
        }

        return metricsMap
    }

    private func computeGlobalMetrics(from sessions: [WorkoutSession]) -> GlobalMetrics {
        let totalVolume = sessions.map { $0.totalVolume }.reduce(0, +)
        let totalSets = sessions.map { $0.totalSets }.reduce(0, +)
        let totalWorkingSets = sessions.map { $0.workingSets }.reduce(0, +)

        let sessionDates = Set(sessions.map { Calendar.current.startOfDay(for: $0.date) })
        let frequencyPerWeek = calculateFrequency(from: sessionDates)

        return GlobalMetrics(
            totalSessions: sessions.count,
            totalVolume: totalVolume,
            totalSets: totalSets,
            totalWorkingSets: totalWorkingSets,
            sessionsPerWeek: frequencyPerWeek,
            averageVolumePerSession: sessions.isEmpty ? 0 : totalVolume / Double(sessions.count)
        )
    }

    private func calculateFrequency(from dates: Set<Date>) -> Double {
        guard !dates.isEmpty else { return 0 }

        let sortedDates = dates.sorted()
        guard let first = sortedDates.first,
              let last = sortedDates.last else { return 0 }

        let daysBetween = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        let weeks = max(1, Double(daysBetween) / 7.0)

        return Double(dates.count) / weeks
    }

    private func identifyTopExercises(from metrics: [String: ExerciseMetrics]) -> [ExerciseMetrics] {
        metrics.values
            .sorted { $0.totalVolume > $1.totalVolume }
            .map { $0 }
    }

    private func computeStrengthChange(for exerciseCode: String, range: TimeRange) throws -> Double? {
        guard let days = range.days, days > 0 else { return nil }

        let allSessions = try adapter.loadAllSessions()
        let exerciseSessions = allSessions.filter { session in
            session.sets.contains { $0.exerciseCode == exerciseCode }
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentSessions = exerciseSessions.filter { $0.date >= cutoffDate }
        let previousSessions = exerciseSessions.filter { $0.date < cutoffDate }

        let recentBest = recentSessions
            .flatMap { $0.sets }
            .filter { $0.exerciseCode == exerciseCode && !$0.isWarmup }
            .compactMap { $0.estimated1RM }
            .max()

        let previousBest = previousSessions
            .flatMap { $0.sets }
            .filter { $0.exerciseCode == exerciseCode && !$0.isWarmup }
            .compactMap { $0.estimated1RM }
            .max()

        guard let recentBest = recentBest, let previousBest = previousBest else {
            return nil
        }

        return ((recentBest - previousBest) / previousBest) * 100.0
    }
}

// MARK: - Metrics Models

struct MetricsSummary {
    let timeRange: TimeRange
    let exerciseMetrics: [String: ExerciseMetrics]
    let globalMetrics: GlobalMetrics
    let topExercises: [ExerciseMetrics]
}

struct ExerciseMetrics {
    let exerciseCode: String
    var best1RM: MetricPoint?
    var totalVolume: Double = 0
    var sessionCount: Int = 0
    var volumePerSession: [VolumePoint] = []
    var sessionDates: Set<Date> = []
    var frequencyPerWeek: Double = 0
}

struct MetricPoint {
    let value: Double
    let date: Date
    let set: SetRecord
}

struct VolumePoint {
    let date: Date
    let volume: Double
}

struct GlobalMetrics {
    let totalSessions: Int
    let totalVolume: Double
    let totalSets: Int
    let totalWorkingSets: Int
    let sessionsPerWeek: Double
    let averageVolumePerSession: Double
}
