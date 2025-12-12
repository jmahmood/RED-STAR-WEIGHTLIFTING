//
//  PlanStore.swift
//  WEIGHTLIFTING
//
//  Created by Claude Code on 2025-12-10.
//

import CryptoKit
import Foundation

// MARK: - Configuration

public struct PlanStoreConfig {
    public let baseURL: URL
    public let maxSnapshotsPerPlan: Int

    public init(baseURL: URL, maxSnapshotsPerPlan: Int) {
        self.baseURL = baseURL
        self.maxSnapshotsPerPlan = maxSnapshotsPerPlan
    }

    public static var `default`: PlanStoreConfig {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.jawaadmahmood.WEIGHTLIFTING_SHARED"
        ) else {
            fatalError("AppGroup container not accessible. Check entitlements.")
        }
        let baseURL = container.appendingPathComponent("Plans", isDirectory: true)
        return PlanStoreConfig(baseURL: baseURL, maxSnapshotsPerPlan: 10)
    }
}

// MARK: - Errors

public enum PlanStoreError: Error {
    case planNotFound(String)
    case cannotLoadPlan(String, underlying: Error)
    case cannotWritePlan(String, underlying: Error)
    case cannotSnapshot(String, underlying: Error)
    case invalidSnapshot(String, file: URL, underlying: Error)
    case snapshotNotFound(String, file: URL)
    case storageUnavailable
    case activePlanNotSet
}

// MARK: - Snapshot Metadata

public struct SnapshotMetadata: Identifiable {
    public let url: URL
    public let filename: String
    public let timestamp: Date?
    public let fileSize: Int64?

    public var id: URL { url }
}

// MARK: - Plan Store

public final class PlanStore {
    public static let shared = PlanStore(config: .default)

    private let config: PlanStoreConfig
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()

    public init(config: PlanStoreConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.queue = DispatchQueue(label: "com.jawaadmahmood.WEIGHTLIFTING.PlanStore", qos: .userInitiated)
        self.queue.setSpecific(key: queueKey, value: ())

        // Automatically migrate on initialization
        queue.async { [weak self] in
            self?.migrateIfNeeded()
        }
    }

    // MARK: - Private Helpers

    private func planDirectory(for id: String) -> URL {
        config.baseURL.appendingPathComponent(id, isDirectory: true)
    }

    private func planURL(id: String) -> URL {
        planDirectory(for: id).appendingPathComponent("plan.json", isDirectory: false)
    }

    private func snapshotsDirectory(planID: String) -> URL {
        planDirectory(for: planID).appendingPathComponent("snapshots", isDirectory: true)
    }

    private func activePlanIDURL() -> URL {
        config.baseURL.appendingPathComponent("active_plan_id.txt", isDirectory: false)
    }

    private static let snapshotDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()

    private func atomicWrite(_ data: Data, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let tempURL = dir.appendingPathComponent(url.lastPathComponent + ".tmp")

        try data.write(to: tempURL, options: .atomic)

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }

        try fileManager.moveItem(at: tempURL, to: url)
    }

    // MARK: - Plan ID Generation

    public static func generatePlanID(from planName: String) -> String {
        let sanitized = planName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-z0-9_-]", with: "", options: .regularExpression)

        return sanitized.isEmpty ? "plan_\(UUID().uuidString.prefix(8))" : sanitized
    }

    // MARK: - CRUD Operations

    public func loadPlan(id: String) throws -> PlanV03 {
        return try sync {
            let url = planURL(id: id)

            guard fileManager.fileExists(atPath: url.path) else {
                throw PlanStoreError.planNotFound(id)
            }

            do {
                let data = try Data(contentsOf: url)
                return try decoder.decode(PlanV03.self, from: data)
            } catch {
                throw PlanStoreError.cannotLoadPlan(id, underlying: error)
            }
        }
    }

    public func savePlan(_ plan: PlanV03, id: String, snapshotIfExists: Bool = false) throws {
        try sync {
            do {
                let data = try encoder.encode(plan)
                let url = planURL(id: id)

                if snapshotIfExists, fileManager.fileExists(atPath: url.path) {
                    try createSnapshot(planID: id)
                }

                try atomicWrite(data, to: url)
            } catch {
                throw PlanStoreError.cannotWritePlan(id, underlying: error)
            }
        }
    }

    public func deletePlan(id: String) throws {
        try sync {
            let dir = planDirectory(for: id)
            guard fileManager.fileExists(atPath: dir.path) else {
                throw PlanStoreError.planNotFound(id)
            }
            try fileManager.removeItem(at: dir)
        }
    }

    public func listPlans() throws -> [String: PlanSummary] {
        return try sync {
            var result: [String: PlanSummary] = [:]

            guard fileManager.fileExists(atPath: config.baseURL.path) else {
                return result
            }

            let contents = try fileManager.contentsOfDirectory(
                at: config.baseURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            for dir in contents where dir.hasDirectoryPath {
                let planID = dir.lastPathComponent
                guard planID != "active_plan_id.txt" else { continue }

                let planFileURL = dir.appendingPathComponent("plan.json")
                guard fileManager.fileExists(atPath: planFileURL.path) else { continue }

                do {
                    let data = try Data(contentsOf: planFileURL)
                    let validation = try PlanValidator.validate(data: data)
                    result[planID] = validation.summary
                } catch {
                    // Skip invalid plans
                    continue
                }
            }

            return result
        }
    }

    // MARK: - Active Plan Management

    public func getActivePlanID() throws -> String? {
        return try sync {
            let url = activePlanIDURL()
            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }
            let data = try Data(contentsOf: url)
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public func setActivePlan(id: String) throws {
        try sync {
            // Verify plan exists
            let planFileURL = planURL(id: id)
            guard fileManager.fileExists(atPath: planFileURL.path) else {
                throw PlanStoreError.planNotFound(id)
            }

            // Write active plan ID
            let url = activePlanIDURL()
            let data = id.data(using: .utf8)!
            try atomicWrite(data, to: url)
        }
    }

    public func loadActivePlan() throws -> PlanV03? {
        guard let activePlanID = try getActivePlanID() else {
            return nil
        }
        return try loadPlan(id: activePlanID)
    }

    // MARK: - Snapshot Management

    private func snapshotURL(for planID: String, timestamp: Date = Date()) -> URL {
        let dir = snapshotsDirectory(planID: planID)
        let filename = Self.snapshotDateFormatter.string(from: timestamp) + ".json"
        return dir.appendingPathComponent(filename, isDirectory: false)
    }

    private func parseSnapshotTimestamp(from filename: String) -> Date? {
        let datePart = filename.replacingOccurrences(of: ".json", with: "")
        return Self.snapshotDateFormatter.date(from: datePart)
    }

    private func planID(fromSnapshotURL url: URL) -> String {
        url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
    }

    /// Executes work on the serial queue, allowing reentrancy when already on the queue.
    private func sync<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return try work()
        } else {
            return try queue.sync(execute: work)
        }
    }

    private func createSnapshot(planID: String) throws {
        let planFileURL = planURL(id: planID)
        guard fileManager.fileExists(atPath: planFileURL.path) else {
            // No plan to snapshot (first save)
            return
        }

        let snapshotsDir = snapshotsDirectory(planID: planID)
        try fileManager.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        let snapshotURL = self.snapshotURL(for: planID)

        do {
            try fileManager.copyItem(at: planFileURL, to: snapshotURL)
        } catch {
            throw PlanStoreError.cannotSnapshot(planID, underlying: error)
        }
    }

    private func pruneSnapshots(planID: String) {
        let dir = snapshotsDirectory(planID: planID)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        let jsonFiles = contents.filter { $0.pathExtension == "json" }
        guard jsonFiles.count > config.maxSnapshotsPerPlan else { return }

        let sorted = jsonFiles.sorted { $0.lastPathComponent > $1.lastPathComponent }
        let toDelete = sorted.dropFirst(config.maxSnapshotsPerPlan)

        for url in toDelete {
            try? fileManager.removeItem(at: url)
        }
    }

    public func listSnapshots(planID: String) throws -> [SnapshotMetadata] {
        return sync {
            let dir = snapshotsDirectory(planID: planID)
            guard let contents = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            return contents
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
                .compactMap { url in
                    let filename = url.lastPathComponent
                    let timestamp = parseSnapshotTimestamp(from: filename)

                    var size: Int64?
                    if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                       let s = values.fileSize {
                        size = Int64(s)
                    }

                    return SnapshotMetadata(url: url, filename: filename, timestamp: timestamp, fileSize: size)
                }
        }
    }

    public func restoreSnapshot(planID: String, snapshotURL: URL) throws {
        try sync {
            guard fileManager.fileExists(atPath: snapshotURL.path) else {
                throw PlanStoreError.snapshotNotFound(planID, file: snapshotURL)
            }

            // 1. Validate snapshot content
            let data = try Data(contentsOf: snapshotURL)
            let validation: PlanValidationResult
            do {
                validation = try PlanValidator.validate(data: data)
            } catch {
                throw PlanStoreError.invalidSnapshot(planID, file: snapshotURL, underlying: error)
            }

            // 2. Safety backup of current plan
            try createSnapshot(planID: planID)

            // 3. Write validated snapshot as current plan
            try savePlan(validation.plan, id: planID, snapshotIfExists: false)

            // 4. Prune old snapshots
            pruneSnapshots(planID: planID)
        }
    }

    public func getSnapshotDetail(snapshotURL: URL) throws -> (metadata: SnapshotMetadata, plan: PlanV03) {
        try sync {
            let planID = planID(fromSnapshotURL: snapshotURL)

            guard fileManager.fileExists(atPath: snapshotURL.path) else {
                throw PlanStoreError.snapshotNotFound(planID, file: snapshotURL)
            }

            let data = try Data(contentsOf: snapshotURL)
            let validation: PlanValidationResult
            do {
                validation = try PlanValidator.validate(data: data)
            } catch {
                throw PlanStoreError.invalidSnapshot(planID, file: snapshotURL, underlying: error)
            }

            let fileSize = try? snapshotURL.resourceValues(forKeys: [.fileSizeKey]).fileSize

            let metadata = SnapshotMetadata(
                url: snapshotURL,
                filename: snapshotURL.lastPathComponent,
                timestamp: parseSnapshotTimestamp(from: snapshotURL.lastPathComponent),
                fileSize: fileSize.map { Int64($0) }
            )

            return (metadata, validation.plan)
        }
    }

    // MARK: - Unified Edit Entry Point

    public func editPlan(id: String, _ mutation: (inout PlanV03) throws -> Void) throws {
        try sync {
            var plan = try loadPlan(id: id)

            // 1. Snapshot before modifying
            try createSnapshot(planID: id)

            // 2. Apply mutation
            try mutation(&plan)

            // 3. Validate
            let data = try encoder.encode(plan)
            _ = try PlanValidator.validate(data: data)

            // 4. Save
            try savePlan(plan, id: id, snapshotIfExists: false)

            // 5. Prune snapshots (best-effort)
            pruneSnapshots(planID: id)
        }
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        // Skip if already migrated
        guard (try? getActivePlanID()) == nil else { return }

        // Check old location (legacy Application Support path).
        let legacyOldURL = StoragePaths.makeDefault(fileManager: fileManager).legacyActivePlanURL

        guard fileManager.fileExists(atPath: legacyOldURL.path) else { return }

        // Migrate to AppGroup
        do {
            let data = try Data(contentsOf: legacyOldURL)
            let plan = try decoder.decode(PlanV03.self, from: data)
            let planID = Self.generatePlanID(from: plan.planName)
            try savePlan(plan, id: planID)
            try setActivePlan(id: planID)
            print("PlanStore: Successfully migrated plan '\(plan.planName)' to AppGroup")
        } catch {
            print("PlanStore: Migration failed: \(error)")
        }
    }
}

// MARK: - Mutation Methods

extension PlanStore {
    // MARK: Exercise Mutations

    public func renameExercise(planID: String, from oldCode: String, to newCode: String) throws {
        try editPlan(id: planID) { plan in
            // Update exerciseNames dictionary
            var names = plan.exerciseNames
            if let name = names[oldCode] {
                names.removeValue(forKey: oldCode)
                names[newCode] = name
}

            // Update altGroups
            var altGroups = plan.altGroups
            if let group = altGroups[oldCode] {
                altGroups.removeValue(forKey: oldCode)
                altGroups[newCode] = group
            }
            for (key, value) in altGroups {
                altGroups[key] = value.map { $0 == oldCode ? newCode : $0 }
            }

            // Update all segment references
            var updatedDays = plan.days
            for (dayIndex, day) in updatedDays.enumerated() {
                var updatedSegments = day.segments
                for (segIndex, segment) in updatedSegments.enumerated() {
                    updatedSegments[segIndex] = updateSegmentExerciseCode(segment, from: oldCode, to: newCode)
                }
                updatedDays[dayIndex] = PlanV03.Day(label: day.label, segments: updatedSegments, dayNumber: day.dayNumber)
            }

            plan = plan
                .withExerciseNames(names)
                .withAltGroups(altGroups)
                .withDays(updatedDays)
        }
    }

    private func updateSegmentExerciseCode(_ segment: PlanV03.Segment, from oldCode: String, to newCode: String) -> PlanV03.Segment {
        switch segment {
        case .straight(var s):
            if s.exerciseCode == oldCode {
                s = PlanV03.StraightSegment(
                    exerciseCode: newCode,
                    altGroup: s.altGroup,
                    sets: s.sets,
                    reps: s.reps,
                    restSec: s.restSec,
                    rpe: s.rpe,
                    intensifier: s.intensifier,
                    timeSec: s.timeSec,
                    tags: s.tags,
                    perWeek: s.perWeek,
                    groupRole: s.groupRole,
                    loadAxisTarget: s.loadAxisTarget
                )
            }
            return .straight(s)

        case .scheme(var s):
            if s.exerciseCode == oldCode {
                s = PlanV03.SchemeSegment(
                    exerciseCode: newCode,
                    altGroup: s.altGroup,
                    entries: s.entries,
                    restSec: s.restSec,
                    intensifier: s.intensifier,
                    perWeek: s.perWeek,
                    groupRole: s.groupRole,
                    loadAxisTarget: s.loadAxisTarget
                )
            }
            return .scheme(s)

        case .superset(var s):
            let updatedItems = s.items.map { item -> PlanV03.SupersetSegment.Item in
                if item.exerciseCode == oldCode {
                    return PlanV03.SupersetSegment.Item(
                        exerciseCode: newCode,
                        altGroup: item.altGroup,
                        sets: item.sets,
                        reps: item.reps,
                        restSec: item.restSec,
                        intensifier: item.intensifier,
                        perWeek: item.perWeek,
                        groupRole: item.groupRole,
                        loadAxisTarget: item.loadAxisTarget
                    )
                }
                return item
            }
            s = PlanV03.SupersetSegment(
                label: s.label,
                rounds: s.rounds,
                items: updatedItems,
                restSec: s.restSec,
                restBetweenRoundsSec: s.restBetweenRoundsSec
            )
            return .superset(s)

        case .percentage(var s):
            if s.exerciseCode == oldCode {
                s = PlanV03.PercentageSegment(
                    exerciseCode: newCode,
                    prescriptions: s.prescriptions,
                    perWeek: s.perWeek
                )
            }
            return .percentage(s)

        case .unsupported:
            return segment
        }
    }

    public func updateExerciseName(planID: String, code: String, name: String) throws {
        try editPlan(id: planID) { plan in
            var names = plan.exerciseNames
            names[code] = name
            plan = plan.withExerciseNames(names)
        }
    }

    // MARK: Day Mutations

    public func duplicateDay(planID: String, dayLabel: String, newLabel: String) throws {
        try editPlan(id: planID) { plan in
            guard let sourceDay = plan.day(named: dayLabel) else {
                throw PlanStoreError.planNotFound("Day '\(dayLabel)' not found")
            }

            let newDay = PlanV03.Day(
                label: newLabel,
                segments: sourceDay.segments,
                dayNumber: nil
            )

            let updatedDays = plan.days + [newDay]
            let updatedOrder = plan.scheduleOrder + [newLabel]

            plan = plan
                .withDays(updatedDays)
                .withScheduleOrder(updatedOrder)
        }
    }

    public func deleteDay(planID: String, dayLabel: String) throws {
        try editPlan(id: planID) { plan in
            let updatedDays = plan.days.filter { $0.label != dayLabel }
            let updatedOrder = plan.scheduleOrder.filter { $0 != dayLabel }

            plan = plan
                .withDays(updatedDays)
                .withScheduleOrder(updatedOrder)
        }
    }

    public func renameDay(planID: String, from oldLabel: String, to newLabel: String) throws {
        try editPlan(id: planID) { plan in
            var updatedDays = plan.days
            if let index = updatedDays.firstIndex(where: { $0.label == oldLabel }) {
                let day = updatedDays[index]
                updatedDays[index] = PlanV03.Day(
                    label: newLabel,
                    segments: day.segments,
                    dayNumber: day.dayNumber
                )
            }

            let updatedOrder = plan.scheduleOrder.map { $0 == oldLabel ? newLabel : $0 }

            plan = plan
                .withDays(updatedDays)
                .withScheduleOrder(updatedOrder)
        }
    }

    public func reorderDays(planID: String, newOrder: [String]) throws {
        try editPlan(id: planID) { plan in
            plan = plan.withScheduleOrder(newOrder)
        }
    }

    // MARK: Metadata Mutations

    public func updatePlanName(planID: String, newName: String) throws {
        try editPlan(id: planID) { plan in
            plan = plan.withPlanName(newName)
        }
    }

    public func updateUnit(planID: String, newUnit: WeightUnit) throws {
        try editPlan(id: planID) { plan in
            plan = plan.withUnit(newUnit)
        }
    }

    // MARK: Tier 1 Editing Helpers

    /// Append a straight segment to an existing day
    public func appendStraightSegment(
        planID: String,
        dayLabel: String,
        exerciseCode: String,
        sets: Int,
        repsMin: Int,
        repsMax: Int
    ) throws {
        try editPlan(id: planID) { plan in
            guard let dayIndex = plan.days.firstIndex(where: { $0.label == dayLabel }) else {
                throw PlanStoreError.planNotFound("Day '\(dayLabel)' not found")
            }

            let day = plan.days[dayIndex]
            let reps = PlanV03.RepetitionRange(min: repsMin, max: repsMax, text: nil)

            let newSegment = PlanV03.Segment.straight(
                PlanV03.StraightSegment(
                    exerciseCode: exerciseCode,
                    altGroup: nil,
                    sets: sets,
                    reps: reps,
                    restSec: nil,
                    rpe: nil,
                    intensifier: nil,
                    timeSec: nil,
                    tags: nil,
                    perWeek: nil,
                    groupRole: nil,
                    loadAxisTarget: nil
                )
            )

            let updatedSegments = day.segments + [newSegment]
            var updatedDays = plan.days
            updatedDays[dayIndex] = PlanV03.Day(
                label: day.label,
                segments: updatedSegments,
                dayNumber: day.dayNumber
            )

            plan = plan.withDays(updatedDays)
        }
    }

    /// Append a new day to the plan
    public func appendDay(planID: String, label: String, segments: [PlanV03.Segment]) throws {
        try editPlan(id: planID) { plan in
            let dayNumber = plan.days.count + 1
            let newDay = PlanV03.Day(label: label, segments: segments, dayNumber: dayNumber)

            let updatedDays = plan.days + [newDay]
            let updatedOrder = plan.scheduleOrder + [label]

            plan = plan
                .withDays(updatedDays)
                .withScheduleOrder(updatedOrder)
        }
    }

    /// Append a day from a template, automatically adding missing exercises
    #if os(iOS)
    public func appendDayFromTemplate(planID: String, template: TemplateDay) throws {
        try editPlan(id: planID) { plan in
            var exerciseNames = plan.exerciseNames

            // Add any missing exercises to the dictionary
            for segment in template.segments {
                if exerciseNames[segment.exerciseCode] == nil {
                    // Generate a human-readable name from the code
                    // e.g., "ROW.BB.BENT" -> "Bent Barbell Row"
                    let name = generateExerciseName(from: segment.exerciseCode)
                    exerciseNames[segment.exerciseCode] = name
                }
            }

            // Convert all template segments to plan segments
            let planSegments = template.segments.map { templateSegment in
                let reps = PlanV03.RepetitionRange(
                    min: templateSegment.repsMin,
                    max: templateSegment.repsMax,
                    text: nil
                )

                return PlanV03.Segment.straight(
                    PlanV03.StraightSegment(
                        exerciseCode: templateSegment.exerciseCode,
                        altGroup: nil,
                        sets: templateSegment.sets,
                        reps: reps,
                        restSec: nil,
                        rpe: nil,
                        intensifier: nil,
                        timeSec: nil,
                        tags: nil,
                        perWeek: nil,
                        groupRole: nil,
                        loadAxisTarget: nil
                    )
                )
            }

            let dayNumber = plan.days.count + 1
            let sanitizedLabel = template.dayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseLabel = sanitizedLabel.isEmpty ? "Day \(dayNumber)" : sanitizedLabel
            var uniqueLabel = baseLabel

            // Ensure label is unique within the schedule order
            if plan.scheduleOrder.contains(uniqueLabel) {
                var suffix = 2
                while plan.scheduleOrder.contains("\(baseLabel) \(suffix)") {
                    suffix += 1
                }
                uniqueLabel = "\(baseLabel) \(suffix)"
            }

            let newDay = PlanV03.Day(
                label: uniqueLabel,
                segments: planSegments,
                dayNumber: dayNumber
            )

            let updatedDays = plan.days + [newDay]
            let updatedOrder = plan.scheduleOrder + [uniqueLabel]

            plan = plan
                .withExerciseNames(exerciseNames)
                .withDays(updatedDays)
                .withScheduleOrder(updatedOrder)
        }
    }

    /// Generate a human-readable exercise name from a code
    /// e.g., "ROW.BB.BENT" -> "Bent Barbell Row"
    private func generateExerciseName(from code: String) -> String {
        let parts = code.split(separator: ".").map { String($0) }

        // Common abbreviation mappings
        let mappings: [String: String] = [
            "BB": "Barbell",
            "DB": "Dumbbell",
            "BW": "Bodyweight",
            "CABLE": "Cable",
            "MACHINE": "Machine",
            "STAND": "Standing",
            "SEATED": "Seated",
            "LYING": "Lying",
            "BENT": "Bent-Over",
            "FLAT": "Flat",
            "INCLINE": "Incline",
            "DECLINE": "Decline",
            "CONV": "Conventional",
            "SUMO": "Sumo",
            "HIGH": "High Bar",
            "LOW": "Low Bar"
        ]

        let expanded = parts.map { part in
            mappings[part.uppercased()] ?? part.capitalized
        }

        // Reverse order for exercise names (e.g., ROW.BB.BENT -> Bent Barbell Row)
        return expanded.reversed().joined(separator: " ")
    }
    #endif
}
