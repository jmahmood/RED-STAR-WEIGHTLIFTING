import Foundation

/// Adapts CSV rows into WorkoutSession domain models
final class WorkoutSessionAdapter {
    private let csvURL: URL
    private let fileManager: FileManager

    init(csvURL: URL, fileManager: FileManager = .default) {
        self.csvURL = csvURL
        self.fileManager = fileManager
    }

    /// Parse all sessions from the CSV file
    func loadAllSessions() throws -> [WorkoutSession] {
        guard fileManager.fileExists(atPath: csvURL.path) else {
            throw AdapterError.csvMissing
        }

        let (_, rows) = try CSVReader.readRows(from: csvURL, fileManager: fileManager)

        var sessionGroups: [String: [ParsedSet]] = [:]
        sessionGroups.reserveCapacity(64)

        for row in rows {
            guard let parsed = ParsedSet(row: row) else { continue }
            sessionGroups[parsed.sessionID, default: []].append(parsed)
        }

        return sessionGroups
            .map { sessionID, sets in buildSession(sessionID: sessionID, sets: sets) }
            .sorted { $0.date > $1.date }
    }

    /// Load sessions within a date range
    func loadSessions(from startDate: Date, to endDate: Date) throws -> [WorkoutSession] {
        try loadAllSessions().filter { session in
            session.date >= startDate && session.date <= endDate
        }
    }

    /// Load sessions for the last N days
    func loadRecentSessions(days: Int) throws -> [WorkoutSession] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return try loadSessions(from: startDate, to: Date())
    }

    private func buildSession(sessionID: String, sets: [ParsedSet]) -> WorkoutSession {
        guard let first = sets.first else {
            fatalError("Cannot build session without sets")
        }

        let setRecords = sets.map { parsedSet in
            SetRecord(
                sessionID: parsedSet.sessionID,
                segmentID: parsedSet.segmentID,
                supersetID: parsedSet.supersetID,
                exerciseCode: parsedSet.exerciseCode,
                setNumber: parsedSet.setNumber,
                reps: parsedSet.reps,
                weight: parsedSet.weight,
                unit: parsedSet.unit,
                isWarmup: parsedSet.isWarmup,
                effort: parsedSet.effort,
                isAdlib: parsedSet.isAdlib,
                rpe: parsedSet.rpe,
                rir: parsedSet.rir
            )
        }

        return WorkoutSession(
            id: sessionID,
            date: first.date,
            time: first.time,
            planName: first.planName,
            dayLabel: first.dayLabel,
            sets: setRecords
        )
    }
}

// MARK: - Parsed Models

private extension WorkoutSessionAdapter {
    struct ParsedSet {
        let sessionID: String
        let date: Date
        let time: String
        let planName: String
        let dayLabel: String
        let segmentID: Int
        let supersetID: String?
        let exerciseCode: String
        let setNumber: Int
        let reps: String
        let weight: Double?
        let unit: WeightUnit
        let isWarmup: Bool
        let effort: Int
        let isAdlib: Bool
        let rpe: String
        let rir: String

        init?(row: CSVRow) {
            guard
                let timestamp = row.timestamp,
                let segmentID = row.segmentID,
                let setNumber = row.setNumber,
                let unit = WeightUnit.fromCSV(row.unitString)
            else {
                return nil
            }

            self.sessionID = row.sessionID
            self.date = timestamp
            self.time = row.timeString
            self.planName = row.planName
            self.dayLabel = row.dayLabel
            self.segmentID = segmentID
            self.supersetID = row.supersetID
            self.exerciseCode = row.exerciseCode
            self.setNumber = setNumber
            self.reps = row.repsString
            self.weight = row.weight
            self.unit = unit
            self.isWarmup = row.isWarmup
            self.effort = row.effort ?? 0
            self.isAdlib = row.adlib
            self.rpe = row.rpeString
            self.rir = row.rirString
        }
    }
}

// MARK: - Errors

enum AdapterError: Error {
    case csvMissing
    case invalidCSV
}

