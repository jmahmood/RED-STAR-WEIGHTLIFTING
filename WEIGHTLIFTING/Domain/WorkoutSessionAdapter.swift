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

        // Load entire file into memory (works well for typical CSV sizes)
        // Note: Fixed Swift 6.2 FileHandle memory corruption issue
        let contents = try String(contentsOf: csvURL, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard let headerLine = lines.first else {
            throw AdapterError.invalidCSV
        }
        let headers = CSVRowParser.parse(line: headerLine)
        guard let columns = CSVColumns(headers: headers) else {
            throw AdapterError.invalidCSV
        }

        var sessionGroups: [String: [ParsedSet]] = [:]

        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            let values = CSVRowParser.parse(line: line)
            guard values.count == headers.count else { continue }
            guard let parsed = ParsedSet(values: values, columns: columns) else { continue }

            sessionGroups[parsed.sessionID, default: []].append(parsed)
        }

        return sessionGroups.map { sessionID, sets in
            buildSession(sessionID: sessionID, sets: sets)
        }.sorted { $0.date > $1.date }
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

        init?(values: [String], columns: CSVColumns) {
            guard
                let sessionID = columns.sessionID.flatMap({ values[safe: $0] }),
                let dateString = columns.date.flatMap({ values[safe: $0] }),
                let timeString = columns.time.flatMap({ values[safe: $0] }),
                let date = CSVDateParser.shared.parse(date: dateString, time: timeString),
                let planName = columns.planName.flatMap({ values[safe: $0] }),
                let dayLabel = columns.dayLabel.flatMap({ values[safe: $0] }),
                let segmentIDString = columns.segmentID.flatMap({ values[safe: $0] }),
                let segmentID = Int(segmentIDString),
                let exerciseCode = columns.exerciseCode.flatMap({ values[safe: $0] }),
                let setNumberString = columns.setNumber.flatMap({ values[safe: $0] }),
                let setNumber = Int(setNumberString),
                let reps = columns.reps.flatMap({ values[safe: $0] }),
                let unitString = columns.unit.flatMap({ values[safe: $0] }),
                let unit = WeightUnit.fromCSV(unitString),
                let isWarmupString = columns.isWarmup.flatMap({ values[safe: $0] }),
                let effortString = columns.effort.flatMap({ values[safe: $0] }),
                let effort = Int(effortString),
                let adlibString = columns.adlib.flatMap({ values[safe: $0] })
            else {
                return nil
            }

            self.sessionID = sessionID
            self.date = date
            self.time = timeString
            self.planName = planName
            self.dayLabel = dayLabel
            self.segmentID = segmentID
            self.supersetID = columns.supersetID.flatMap({ values[safe: $0] })
            self.exerciseCode = exerciseCode
            self.setNumber = setNumber
            self.reps = reps

            if let weightString = columns.weight.flatMap({ values[safe: $0] }),
               let weightValue = Double(weightString), weightValue > 0.0 {
                self.weight = weightValue
            } else {
                self.weight = nil
            }

            self.unit = unit
            self.isWarmup = isWarmupString == "1" || isWarmupString.lowercased() == "true"
            self.effort = effort
            self.isAdlib = adlibString == "1" || adlibString.lowercased() == "true"
            self.rpe = columns.rpe.flatMap({ values[safe: $0] }) ?? ""
            self.rir = columns.rir.flatMap({ values[safe: $0] }) ?? ""
        }
    }

    struct CSVColumns {
        let sessionID: Int?
        let date: Int?
        let time: Int?
        let planName: Int?
        let dayLabel: Int?
        let segmentID: Int?
        let supersetID: Int?
        let exerciseCode: Int?
        let adlib: Int?
        let setNumber: Int?
        let reps: Int?
        let weight: Int?
        let unit: Int?
        let isWarmup: Int?
        let effort: Int?
        let rpe: Int?
        let rir: Int?

        init?(headers: [String]) {
            func index(of name: String) -> Int? {
                headers.firstIndex { $0.lowercased() == name.lowercased() }
            }

            self.sessionID = index(of: "session_id")
            self.date = index(of: "date")
            self.time = index(of: "time")
            self.planName = index(of: "plan_name")
            self.dayLabel = index(of: "day_label")
            self.segmentID = index(of: "segment_id")
            self.supersetID = index(of: "superset_id")
            self.exerciseCode = index(of: "ex_code")
            self.adlib = index(of: "adlib")
            self.setNumber = index(of: "set_num")
            self.reps = index(of: "reps")
            self.weight = index(of: "weight")
            self.unit = index(of: "unit")
            self.isWarmup = index(of: "is_warmup")
            self.effort = index(of: "effort_1to5")
            self.rpe = index(of: "rpe")
            self.rir = index(of: "rir")

            // Validate minimum required columns
            guard sessionID != nil,
                  date != nil,
                  time != nil,
                  exerciseCode != nil,
                  weight != nil,
                  unit != nil
            else {
                return nil
            }
        }
    }

    struct CSVDateParser {
        static let shared = CSVDateParser()
        private let dateTimeFormatter: DateFormatter

        private init() {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateTimeFormatter = formatter
        }

        func parse(date: String, time: String) -> Date? {
            dateTimeFormatter.date(from: "\(date) \(time)")
        }
    }

    struct CSVRowParser {
        static func parse(line: String) -> [String] {
            var result: [String] = []
            var buffer = ""
            var insideQuotes = false
            let characters = Array(line)
            var index = 0

            while index < characters.count {
                let character = characters[index]
                if character == "\"" {
                    if insideQuotes && index + 1 < characters.count && characters[index + 1] == "\"" {
                        buffer.append("\"")
                        index += 2
                        continue
                    }
                    insideQuotes.toggle()
                    index += 1
                    continue
                }

                if character == "," && !insideQuotes {
                    result.append(buffer)
                    buffer.removeAll(keepingCapacity: true)
                    index += 1
                    continue
                }

                if character == "\r" {
                    index += 1
                    continue
                }

                buffer.append(character)
                index += 1
            }

            result.append(buffer)
            return result
        }
    }
}

// MARK: - Errors

enum AdapterError: Error {
    case csvMissing
    case invalidCSV
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
