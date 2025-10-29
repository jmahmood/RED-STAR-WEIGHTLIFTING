//
//  IndexService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-28.
//

import Foundation

protocol IndexRepositorying {
    func applyCommit(_ row: CsvRow) throws
    func fetchLastTwo(for exerciseCode: String) throws -> [DeckItem.PrevCompletion]
    func latestCompletion(for exerciseCode: String) throws -> DeckItem.PrevCompletion?
    func recentExercises(inLast days: Int, limit: Int) throws -> [IndexService.RecentExercise]
}

final class IndexService: IndexRepositorying {
    struct RecentExercise: Equatable {
        let exerciseCode: String
        let latest: DeckItem.PrevCompletion
    }

    private let dataStore: IndexDataStore
    private let fileSystem: FileSystem
    private let queue = DispatchQueue(label: "IndexService.queue", qos: .utility)

    private var cache: [String: [DeckItem.PrevCompletion]] = [:]
    private var cacheSignature: CacheSignature?

    init(dataStore: IndexDataStore, fileSystem: FileSystem) {
        self.dataStore = dataStore
        self.fileSystem = fileSystem
    }

    func applyCommit(_ row: CsvRow) throws {
        try queue.sync {
            try loadCache(force: false)
            guard let completion = makeCompletion(from: row) else { return }
            var current = cache[row.exerciseCode] ?? []
            current.insert(completion, at: 0)
            cache[row.exerciseCode] = Array(current.prefix(2))
            try dataStore.writeIndex(cache)
            cacheSignature = makeSignature()
        }
    }

    func fetchLastTwo(for exerciseCode: String) throws -> [DeckItem.PrevCompletion] {
        try queue.sync {
            try loadCache(force: false)
            return cache[exerciseCode] ?? []
        }
    }

    func latestCompletion(for exerciseCode: String) throws -> DeckItem.PrevCompletion? {
        try queue.sync {
            try loadCache(force: false)
            return cache[exerciseCode]?.first
        }
    }

    func recentExercises(inLast days: Int = 7, limit: Int = 8) throws -> [RecentExercise] {
        try queue.sync {
            try loadCache(force: false)
            let threshold = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
            let candidates = cache.compactMap { pair -> RecentExercise? in
                let (code, completions) = pair
                guard let latest = completions.first, latest.date >= threshold else {
                    return nil
                }
                return RecentExercise(exerciseCode: code, latest: latest)
            }
            let sorted = candidates.sorted { lhs, rhs in
                lhs.latest.date > rhs.latest.date
            }
            return Array(sorted.prefix(limit))
        }
    }
}

// MARK: - Private helpers

private extension IndexService {
    struct CacheSignature: Equatable {
        let indexDate: Date?
        let csvDate: Date?
        let csvPath: String?
    }

    func makeCompletion(from row: CsvRow) -> DeckItem.PrevCompletion? {
        guard let weight = Double(row.weight), !row.weight.isEmpty else {
            return nil
        }
        let reps = Int(row.reps)
        let effort = DeckItem.Effort(rawValue: row.effort)
        let timestamp = CsvDateFormatter.date(from: row.dateString, timeString: row.timeString) ?? Date()
        return DeckItem.PrevCompletion(date: timestamp, weight: weight, reps: reps, effort: effort)
    }

    func loadCache(force: Bool) throws {
        let signature = makeSignature()
        if !force, signature == cacheSignature {
            return
        }

        let rawIndex: [String: [DeckItem.PrevCompletion]]
        if let csvDate = signature.csvDate {
            if let indexDate = signature.indexDate,
               indexDate >= csvDate,
               let stored = try? dataStore.readIndex() {
                rawIndex = stored
            } else {
                rawIndex = try rebuildIndexFromCSV()
            }
        } else if let stored = try? dataStore.readIndex() {
            rawIndex = stored
        } else {
            rawIndex = [:]
        }

        cache = rawIndex
        cacheSignature = makeSignature()
    }

    func makeSignature() -> CacheSignature {
        let indexDate: Date?
        let csvDate: Date?
        let csvURL = resolveCsvURL()
        do {
            let url = try fileSystem.indexURL()
            indexDate = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? nil
        } catch {
            indexDate = nil
        }

        if let csvURL {
            csvDate = (try? FileManager.default.attributesOfItem(atPath: csvURL.path)[.modificationDate] as? Date) ?? nil
        } else {
            csvDate = nil
        }

        return CacheSignature(indexDate: indexDate, csvDate: csvDate, csvPath: csvURL?.path)
    }

    func rebuildIndexFromCSV() throws -> [String: [DeckItem.PrevCompletion]] {
        guard let csvURL = resolveCsvURL() else {
            return [:]
        }

        let content = try String(contentsOf: csvURL, encoding: .utf8)
        let lines = content.split(whereSeparator: \.isNewline)
        guard let headerLine = lines.first else {
            return [:]
        }

        let headers = parseCSVRow(String(headerLine))
        guard headers.contains("ex_code") else { return [:] }

        var scratch: [String: [(completion: DeckItem.PrevCompletion, sortDate: Date?)]] = [:]

        for slice in lines.dropFirst() {
            let line = String(slice)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            let values = parseCSVRow(line)
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
                let weight = Double(weightString)
            else { continue }

            let reps = row["reps"].flatMap { Int($0) }
            let effortRaw = row["effort_1to5"].flatMap { Int($0) }

            let dateString = row["date"] ?? ""
            let timeString = row["time"] ?? ""
            let sortDate = CsvDateFormatter.date(from: dateString, timeString: timeString)

            let completion = DeckItem.PrevCompletion(
                date: sortDate ?? Date(),
                weight: weight,
                reps: reps,
                effort: effortRaw.flatMap(DeckItem.Effort.init(rawValue:))
            )

            scratch[exCode, default: []].append((completion, sortDate))
        }

        var result: [String: [DeckItem.PrevCompletion]] = [:]
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
            let trimmed = sorted.prefix(2).map { $0.completion }
            if !trimmed.isEmpty {
                result[code] = Array(trimmed)
            }
        }

        try dataStore.writeIndex(result)
        return result
    }

    func resolveCsvURL() -> URL? {
        if let url = try? fileSystem.globalCsvURL(), FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let fallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("lifts.csv", isDirectory: false)
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        return nil
    }

    func parseCSVRow(_ line: String) -> [String] {
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
}

