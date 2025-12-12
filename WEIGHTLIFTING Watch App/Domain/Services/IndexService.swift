//
//  IndexService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-28.
//

import Foundation
import os.signpost

struct IndexEntry: Codable, Equatable {
    let date: String
    let time: String
    let weight: Double?
    let unit: String
    let reps: Int?
    let effort: Int?

    var signature: String { "\(date)|\(time)" }
}

typealias Last2 = [IndexEntry]

extension IndexEntry {
    init(from row: CsvRow) {
        self.date = row.dateString
        self.time = row.timeString
        self.weight = Double(row.weight).flatMap { $0 > 0 ? $0 : nil }
        self.unit = row.unit
        self.reps = Int(row.reps).flatMap { $0 > 0 ? $0 : nil }
        self.effort = row.effort == 0 ? nil : row.effort
    }

    static func maybeFrom(_ row: CsvRow) -> IndexEntry? {
        guard !row.exerciseCode.isEmpty, let _ = Double(row.weight) else { return nil }
        return IndexEntry(from: row)
    }

    init(from indexRow: CSVIndexRow) {
        self.date = indexRow.dateString
        self.time = indexRow.timeString
        self.weight = indexRow.weight
        self.unit = indexRow.unit
        self.reps = indexRow.reps
        self.effort = indexRow.effort
    }
}

protocol IndexRepositorying {
    func applyCommit(_ row: CsvRow) throws
    func fetchLastTwo(for exerciseCode: String) throws -> [DeckItem.PrevCompletion]
    func latestCompletion(for exerciseCode: String) throws -> DeckItem.PrevCompletion?
    func recentExercises(inLast days: Int, limit: Int) throws -> [IndexService.RecentExercise]
    func ensureValidAgainstCSV()
    func rebuildFromCSV()
}

final class IndexService: IndexRepositorying {
    struct RecentExercise: Equatable {
        let exerciseCode: String
        let latest: DeckItem.PrevCompletion
    }

    private let dataStore: IndexDataStore
    private let fileSystem: FileSystem
    private let queue = DispatchQueue(label: "IndexService.queue", qos: .utility)

    private var cache: [String: Last2] = [:]
    private var persistScheduled = false
    private var csvSizeAtPersist: UInt64 = 0

    init(dataStore: IndexDataStore, fileSystem: FileSystem) {
        self.dataStore = dataStore
        self.fileSystem = fileSystem
        // Load existing index
        if let loaded = try? dataStore.readIndex() {
            cache = loaded
            csvSizeAtPersist = (try? fileSystem.fileSize(at: fileSystem.globalCsvURL())) ?? 0
        }
    }

    func applyCommit(_ row: CsvRow) throws {
        queue.async {
            let e = IndexEntry(from: row)
            var l2 = self.cache[row.exerciseCode] ?? []
            l2.removeAll { $0.signature == e.signature }
            l2.insert(e, at: 0)
            if l2.count > 2 { l2.removeLast() }
            self.cache[row.exerciseCode] = l2
            self.schedulePersist()
            os_signpost(.event, log: .default, name: "index.applyCommit.coalescedWrite")
        }
    }

    func fetchLastTwo(for exerciseCode: String) throws -> [DeckItem.PrevCompletion] {
        queue.sync {
            return cache[exerciseCode]?.compactMap { makeCompletion(from: $0) } ?? []
        }
    }

    func latestCompletion(for exerciseCode: String) throws -> DeckItem.PrevCompletion? {
        queue.sync {
            return cache[exerciseCode]?.first.flatMap { makeCompletion(from: $0) }
        }
    }

    func recentExercises(inLast days: Int = 7, limit: Int = 8) throws -> [RecentExercise] {
        queue.sync {
            let threshold = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
            let candidates = cache.compactMap { pair -> RecentExercise? in
                let (code, completions) = pair
                guard let latest = completions.first, let completion = makeCompletion(from: latest), completion.date >= threshold else {
                    return nil
                }
                return RecentExercise(exerciseCode: code, latest: completion)
            }
            let sorted = candidates.sorted { lhs, rhs in
                lhs.latest.date > rhs.latest.date
            }
            return Array(sorted.prefix(limit))
        }
    }

    func ensureValidAgainstCSV() {
        queue.sync {
            let csvSize = (try? self.fileSystem.fileSize(at: self.fileSystem.globalCsvURL())) ?? 0
            guard self.cache.isEmpty || csvSize < self.csvSizeAtPersist else { return }
            self.rebuildFromCSVLocked()
        }
    }

    func rebuildFromCSV() {
        queue.sync {
            self.rebuildFromCSVLocked()
        }
    }
}

// MARK: - Private helpers

private extension IndexService {
    func makeCompletion(from entry: IndexEntry) -> DeckItem.PrevCompletion? {
        guard let weight = entry.weight else { return nil }
        let timestamp = CsvDateFormatter.date(from: entry.date, timeString: entry.time) ?? Date()
        return DeckItem.PrevCompletion(date: timestamp, weight: weight, reps: entry.reps, effort: entry.effort.flatMap(DeckItem.Effort.init(rawValue:)))
    }

    func schedulePersist() {
        guard !persistScheduled else { return }
        persistScheduled = true
        queue.asyncAfter(deadline: .now() + 0.5) { [self] in
            persistScheduled = false
            do { try persistLocked() } catch { /* log */ }
        }
    }

    func persistLocked() throws {
        let url = try fileSystem.indexURL()
        let data = try JSONEncoder().encode(cache)
        try data.write(to: url, options: .atomic)
        csvSizeAtPersist = try fileSystem.fileSize(at: fileSystem.globalCsvURL())
    }

    func rebuildFromCSVLocked() {
        os_signpost(.event, log: .default, name: "index.rebuild.full")
        do {
            let index = try CSVIndexBuilder.buildLastTwoByExercise(from: fileSystem.globalCsvURL())
            cache = index.mapValues { rows in rows.map { IndexEntry(from: $0) } }
            try persistLocked()
        } catch CSVIndexBuilderError.fileMissing {
            cache = [:]
        } catch {
            cache = [:]
        }
    }
}
