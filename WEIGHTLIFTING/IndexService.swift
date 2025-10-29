//
//  IndexService.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-28.
//

import Foundation

/// Represents the most recent logged weight details for a specific exercise.
struct LatestWeight: Equatable {
    let weight: Double
    let unit: String
    let reps: Int
    let date: Date
}

/// Provides read access to the precomputed global index that stores the last
/// logged sets per exercise. The service now keeps the index in sync with the
/// latest global CSV so callers never need to run a manual rebuild script.
final class IndexService {
    static let shared = IndexService()

    private let fileManager: FileManager
    private let indexURL: URL
    private let csvURL: URL

    private var cache: [String: [LatestWeight]] = [:]
    private var cacheSignature: CacheSignature?
    private let queue = DispatchQueue(label: "IndexService.cacheQueue", qos: .utility)

    init(
        fileManager: FileManager = .default,
        indexURL: URL? = nil,
        csvURL: URL? = nil
    ) {
        self.fileManager = fileManager
        if let indexURL {
            self.indexURL = indexURL
        } else {
            self.indexURL = IndexService.makeDefaultIndexURL(using: fileManager)
        }

        if let csvURL {
            self.csvURL = csvURL
        } else {
            let defaultCSV = IndexService.makeDefaultCSVURL(using: fileManager)
            self.csvURL = IndexService.resolveCSVURL(defaultURL: defaultCSV, fileManager: fileManager)
        }

        reload()
    }

    /// Reloads the in-memory cache from disk. This forces a fresh check of the
    /// CSV/JSON timestamps so the next lookup always reflects the newest saves.
    func reload() {
        queue.sync {
            loadCache(force: true)
        }
    }

    /// Returns the latest completed weight entry for the provided exercise code.
    ///
    /// - Parameter exCode: Exercise identifier (`ex_code` column in CSV).
    /// - Returns: Most recent completed weight entry, or `nil` when no rows exist.
    func latestWeight(exCode: String) -> LatestWeight? {
        queue.sync {
            loadCache(force: false)
            return cache[exCode]?.first
        }
    }

    /// Returns up to the last two completed entries for the provided exercise.
    func lastTwo(exCode: String) -> [LatestWeight] {
        queue.sync {
            loadCache(force: false)
            if let cached = cache[exCode] {
                return Array(cached.prefix(2))
            }
            return []
        }
    }

    struct RecentExercise: Equatable {
        let exerciseCode: String
        let latest: LatestWeight
    }

    func recentExercises(inLast days: Int = 7, limit: Int = 8) -> [RecentExercise] {
        queue.sync {
            loadCache(force: false)
            let threshold = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
            let candidates = cache.compactMap { key, entries -> RecentExercise? in
                guard let latest = entries.first, latest.date >= threshold else { return nil }
                return RecentExercise(exerciseCode: key, latest: latest)
            }
            let sorted = candidates.sorted { lhs, rhs in
                lhs.latest.date > rhs.latest.date
            }
            return Array(sorted.prefix(limit))
        }
    }
}

private extension IndexService {
    struct CacheSignature: Equatable {
        let indexModificationDate: Date?
        let csvModificationDate: Date?
    }

    struct IndexEntry: Codable {
        let date: String?
        let time: String?
        let weight: Double?
        let unit: String?
        let reps: Int?
    }

    typealias RawIndex = [String: [IndexEntry]]

    func loadCache(force: Bool) {
        let signature = makeSignature()
        if !force, signature == cacheSignature {
            return
        }

        let raw = resolveIndex(using: signature)
        let transformed = raw.mapValues { entries in
            entries.compactMap { IndexService.transform($0) }
        }
        cache = transformed
        cacheSignature = signature
    }

    static func makeDefaultIndexURL(using fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        return base
            .appendingPathComponent("WeightWatch", isDirectory: true)
            .appendingPathComponent("Global", isDirectory: true)
            .appendingPathComponent("index_last_by_ex.json", isDirectory: false)
    }

    static func makeDefaultCSVURL(using fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        return base
            .appendingPathComponent("WeightWatch", isDirectory: true)
            .appendingPathComponent("Global", isDirectory: true)
            .appendingPathComponent("all_time.csv", isDirectory: false)
    }

    static func resolveCSVURL(defaultURL: URL, fileManager: FileManager) -> URL {
        if fileManager.fileExists(atPath: defaultURL.path) {
            return defaultURL
        }

        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let fallback = cwd.appendingPathComponent("lifts.csv", isDirectory: false)
        if fileManager.fileExists(atPath: fallback.path) {
            return fallback
        }

        return defaultURL
    }

    func makeSignature() -> CacheSignature {
        let indexDate = (try? fileManager.attributesOfItem(atPath: indexURL.path)[.modificationDate] as? Date) ?? nil
        let csvDate = (try? fileManager.attributesOfItem(atPath: csvURL.path)[.modificationDate] as? Date) ?? nil
        return CacheSignature(indexModificationDate: indexDate, csvModificationDate: csvDate)
    }

    func resolveIndex(using signature: CacheSignature) -> RawIndex {
        if let csvDate = signature.csvModificationDate {
            if let indexDate = signature.indexModificationDate, indexDate >= csvDate {
                if let payload = readIndexFile() {
                    return payload
                }
            }
            return rebuildIndexFromCSV()
        }

        if let payload = readIndexFile() {
            return payload
        }

        return [:]
    }

    func readIndexFile() -> RawIndex? {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: indexURL)
            if data.isEmpty {
                return [:]
            }
            let decoder = JSONDecoder()
            return try decoder.decode(RawIndex.self, from: data)
        } catch {
            return nil
        }
    }

    func rebuildIndexFromCSV() -> RawIndex {
        guard fileManager.fileExists(atPath: csvURL.path) else {
            return [:]
        }

        do {
            let content = try String(contentsOf: csvURL, encoding: .utf8)
            let lines = content.split(whereSeparator: \.isNewline)
            guard let headerLine = lines.first else {
                return [:]
            }

            let headers = IndexService.parseCSVRow(String(headerLine))
            guard headers.contains("ex_code") else { return [:] }

            var scratch: [String: [(entry: IndexEntry, sortDate: Date?)]] = [:]

            for slice in lines.dropFirst() {
                let line = String(slice)
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }

                let values = IndexService.parseCSVRow(line)
                if values.count != headers.count {
                    continue
                }

                var row: [String: String] = [:]
                for (index, header) in headers.enumerated() {
                    row[header] = values[index]
                }

                guard let exCode = row["ex_code"], !exCode.isEmpty else { continue }

                guard
                    let weightString = row["weight"], !weightString.isEmpty,
                    let weight = Double(weightString),
                    let unit = row["unit"], !unit.isEmpty,
                    let repsString = row["reps"], !repsString.isEmpty
                else { continue }

                guard let reps = Int(repsString) else { continue }

                let dateString = row["date"]
                let timeString = row["time"]
                let sortDate = IndexService.parseDate(dateString, timeString: timeString)

                let entry = IndexEntry(
                    date: dateString,
                    time: timeString,
                    weight: weight,
                    unit: unit,
                    reps: reps
                )

                scratch[exCode, default: []].append((entry, sortDate))
            }

            var result: RawIndex = [:]
            for (code, entries) in scratch {
                let sorted = entries.sorted { lhs, rhs in
                    switch (lhs.sortDate, rhs.sortDate) {
                    case let (l?, r?):
                        return l > r
                    case (.some, nil):
                        return true
                    case (nil, .some):
                        return false
                    case (nil, nil):
                        return false
                    }
                }
                let trimmed = sorted.prefix(2).map { $0.entry }
                if !trimmed.isEmpty {
                    result[code] = Array(trimmed)
                }
            }

            try writeIndex(result)
            return result
        } catch {
            return [:]
        }
    }

    func writeIndex(_ index: RawIndex) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        let directory = indexURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: indexURL, options: .atomic)
    }

    static func transform(_ entry: IndexEntry) -> LatestWeight? {
        guard
            let weight = entry.weight,
            let unit = entry.unit,
            let reps = entry.reps,
            let date = parseDate(entry.date, timeString: entry.time)
        else {
            return nil
        }

        return LatestWeight(weight: weight, unit: unit, reps: reps, date: date)
    }

    static func parseCSVRow(_ line: String) -> [String] {
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

            buffer.append(character)
            index += 1
        }

        result.append(buffer)
        return result
    }

    static func parseDate(_ dateString: String?, timeString: String?) -> Date? {
        guard let dateString else { return nil }

        if let timeString, !timeString.isEmpty {
            let full = "\(dateString)T\(timeString)"
            if let combinedDate = isoDateTimeFormatter.date(from: full) {
                return combinedDate
            }
        }

        if let dateOnly = isoDateFormatter.date(from: dateString) {
            return dateOnly
        }

        return dashDateFormatter.date(from: dateString)
    }

    static let isoDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()

    static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return formatter
    }()

    static let dashDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
