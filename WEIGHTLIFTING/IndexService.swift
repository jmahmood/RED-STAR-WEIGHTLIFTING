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
        let paths = StoragePaths.makeDefault(fileManager: fileManager)
        self.indexURL = indexURL ?? paths.globalIndexURL
        let defaultCSV = csvURL ?? paths.globalCSVURL
        self.csvURL = IndexService.resolveCSVURL(defaultURL: defaultCSV, fileManager: fileManager)

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
        guard fileManager.fileExists(atPath: csvURL.path) else { return [:] }

        do {
            let index = try CSVIndexBuilder.buildLastTwoByExercise(from: csvURL)
            let result: RawIndex = index.mapValues { rows in
                rows.map { row in
                    IndexEntry(
                        date: row.dateString,
                        time: row.timeString,
                        weight: row.weight,
                        unit: row.unit,
                        reps: row.reps
                    )
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
            let date = CSVTimestampParser.parse(dateString: entry.date, timeString: entry.time)
        else {
            return nil
        }

        return LatestWeight(weight: weight, unit: unit, reps: reps, date: date)
    }
}
