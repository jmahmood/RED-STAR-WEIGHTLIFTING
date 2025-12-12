//
//  PersonalRecordService.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-11-02.
//

import CryptoKit
import Foundation

@MainActor
final class PersonalRecordService {
    private let csvURL: URL
    private let cacheDirectory: URL
    private let fileManager: FileManager
#if DEBUG
    // During XCTest the simulator runtime is occasionally tripping a bogus double-free
    // on deinit; retain instances to avoid deallocation while tests execute.
    private static var testRetain: [PersonalRecordService] = []
#endif

    private var cachedSummary: PersonalRecordSummary?
    private var cachedSummaryURL: URL?

    init(globalDirectory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.cacheDirectory = globalDirectory
        self.csvURL = globalDirectory.appendingPathComponent("all_time.csv", isDirectory: false)
        try? fileManager.createDirectory(at: globalDirectory, withIntermediateDirectories: true)
        loadLatestSummary()
#if DEBUG
        if NSClassFromString("XCTest") != nil {
            PersonalRecordService.testRetain.append(self)
        }
#endif
    }

    func summary() throws -> PersonalRecordSummary {
        try ensureFreshSummaryLocked()
        guard let cachedSummary else {
            throw InsightsError.csvMissing
        }
        return cachedSummary
    }
}

// MARK: - Cache Management

private extension PersonalRecordService {
    func ensureFreshSummaryLocked() throws {
        guard fileManager.fileExists(atPath: csvURL.path) else {
            throw InsightsError.csvMissing
        }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: csvURL.path)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain, error.code == NSFileReadNoSuchFileError {
                throw InsightsError.csvMissing
            }
            throw error
        }
        let size = attributes[.size] as? NSNumber
        let modification = attributes[.modificationDate] as? Date
        let signature = PersonalRecordSummary.FileSignature(
            sizeBytes: UInt64(truncating: size ?? 0),
            modificationDate: modification
        )

        if let cachedSummary, cachedSummary.fileSignature == signature {
            return
        }

        cachedSummary = try rebuildLocked(signature: signature)
    }

    func rebuildLocked(signature: PersonalRecordSummary.FileSignature) throws -> PersonalRecordSummary {
        guard fileManager.fileExists(atPath: csvURL.path) else {
            throw InsightsError.csvMissing
        }

        let data = try Data(contentsOf: csvURL)
        let (_, rows) = try CSVReader.readRows(from: csvURL, fileManager: fileManager)

        var accumulators: [ExerciseUnitKey: ExerciseAccumulator] = [:]
        var rowCount = 0
        var latestSession: (date: Date, dayLabel: String)?

        for row in rows {
            rowCount += 1
            guard let parsed = ParsedRow(row: row) else { continue }

            if let dayLabel = parsed.dayLabel {
                if let existing = latestSession {
                    if parsed.timestamp > existing.date {
                        latestSession = (parsed.timestamp, dayLabel)
                    }
                } else {
                    latestSession = (parsed.timestamp, dayLabel)
                }
            }

            self.update(accumulators: &accumulators, with: parsed)
        }

        let entries = accumulators
            .map { key, accumulator in
                PersonalRecordSummary.Entry(
                    exerciseCode: key.exerciseCode,
                    unit: key.unit,
                    load: accumulator.load,
                    volume: accumulator.volume,
                    epley: accumulator.epley
                )
            }
            .sorted {
                if $0.exerciseCode == $1.exerciseCode {
                    return $0.unit < $1.unit
                }
                return $0.exerciseCode < $1.exerciseCode
            }

        let sha256 = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let summary = PersonalRecordSummary(
            generatedAt: Date(),
            fileSignature: signature,
            sha256: sha256,
            rowCount: rowCount,
            entries: entries,
            latestDayLabel: latestSession?.dayLabel,
            latestSessionDate: latestSession?.date
        )

        try persist(summary: summary)
        cachedSummary = summary
        return summary
    }

    func persist(summary: PersonalRecordSummary) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(summary)
        let url = makeSummaryURL(for: summary.generatedAt)
        try data.write(to: url, options: .atomic)
        pruneOldSummaries(keeping: url)
        cachedSummaryURL = url
    }

    func loadLatestSummary() {
        guard let url = try? latestSummaryURL() else {
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: url),
           let summary = try? decoder.decode(PersonalRecordSummary.self, from: data) {
            cachedSummary = summary
            cachedSummaryURL = url
        }
    }

    func latestSummaryURL() throws -> URL? {
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let candidates = contents.filter { $0.lastPathComponent.lowercased().hasSuffix(".pr.json") }
        guard !candidates.isEmpty else { return nil }
        let sorted = candidates.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return lhsDate > rhsDate
        }
        return sorted.first
    }

    func makeSummaryURL(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        let stamp = formatter.string(from: date)
        let filename = "AllTime-\(stamp).pr.json"
        return cacheDirectory.appendingPathComponent(filename, isDirectory: false)
    }

    func pruneOldSummaries(keeping target: URL) {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in contents where url.lastPathComponent.lowercased().hasSuffix(".pr.json") && url != target {
            try? fileManager.removeItem(at: url)
        }
    }
}

// MARK: - Aggregation

private extension PersonalRecordService {
    struct ExerciseUnitKey: Hashable {
        let exerciseCode: String
        let unit: String
    }

    struct ExerciseAccumulator {
        var load: PersonalRecordSummary.Metric?
        var volume: PersonalRecordSummary.Metric?
        var epley: PersonalRecordSummary.Metric?
    }

    struct ParsedRow {
        let exerciseCode: String
        let reps: Int
        let weight: Double
        let unit: UnitCategory
        let timestamp: Date
        let dayLabel: String?
    }

    enum UnitCategory: Equatable {
        case weight(WeightUnit)
        case bodyweight

        init?(rawValue: String) {
            if let unit = WeightUnit.fromCSV(rawValue) {
                self = .weight(unit)
            } else if rawValue.lowercased() == "bw" || rawValue.lowercased() == "bodyweight" {
                self = .bodyweight
            } else {
                return nil
            }
        }

        var rawString: String {
            switch self {
            case .weight(let unit):
                return unit.csvValue
            case .bodyweight:
                return "bw"
            }
        }
    }

    func update(accumulators: inout [ExerciseUnitKey: ExerciseAccumulator], with row: ParsedRow) {
        let key = ExerciseUnitKey(exerciseCode: row.exerciseCode, unit: row.unit.rawString)
        var accumulator = accumulators[key] ?? ExerciseAccumulator()

        switch row.unit {
        case .weight:
            let loadMetric = PersonalRecordSummary.Metric(
                value: row.weight,
                weight: row.weight,
                reps: row.reps,
                date: row.timestamp
            )
            accumulator.load = chooseBetter(existing: accumulator.load, candidate: loadMetric)

            let est = row.weight * (1.0 + Double(row.reps) / 30.0)
            let epleyMetric = PersonalRecordSummary.Metric(
                value: est,
                weight: row.weight,
                reps: row.reps,
                date: row.timestamp
            )
            accumulator.epley = chooseBetter(existing: accumulator.epley, candidate: epleyMetric)
        case .bodyweight:
            break
        }

        let volumeValue = abs(row.weight) * Double(row.reps)
        let volumeMetric = PersonalRecordSummary.Metric(
            value: volumeValue,
            weight: row.weight,
            reps: row.reps,
            date: row.timestamp
        )
        accumulator.volume = chooseBetter(existing: accumulator.volume, candidate: volumeMetric)

        accumulators[key] = accumulator
    }

    func chooseBetter(existing: PersonalRecordSummary.Metric?, candidate: PersonalRecordSummary.Metric) -> PersonalRecordSummary.Metric {
        guard let existing else { return candidate }
        if candidate.value > existing.value + 0.0001 {
            return candidate
        } else if abs(candidate.value - existing.value) <= 0.0001, candidate.date >= existing.date {
            return candidate
        }
        return existing
    }
}

// MARK: - CSV Parsing

private extension PersonalRecordService {
}

private extension PersonalRecordService.ParsedRow {
    init?(row: CSVRow) {
        let repsValue = Int(row.repsString.trimmingCharacters(in: .whitespaces)) ?? 0
        guard
            repsValue >= 1,
            row.isWarmup == false,
            let unit = PersonalRecordService.UnitCategory(rawValue: row.unitString.trimmingCharacters(in: .whitespaces)),
            let weightValue = row.weight,
            let timestamp = row.timestamp,
            !row.exerciseCode.isEmpty
        else {
            return nil
        }

        let rawLabel = row.dayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = rawLabel.isEmpty ? nil : rawLabel

        self.init(
            exerciseCode: row.exerciseCode,
            reps: repsValue,
            weight: weightValue,
            unit: unit,
            timestamp: timestamp,
            dayLabel: label
        )
    }
}
