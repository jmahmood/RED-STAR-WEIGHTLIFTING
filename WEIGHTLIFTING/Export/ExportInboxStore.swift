//
//  ExportInboxStore.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-30.
//

import Combine
import Foundation
import SwiftUI
import UserNotifications
import WatchConnectivity

enum TransferKind: String {
    case globalCSV = "ios.global_csv.v1"
    case planV03 = "ios.plan_v03.v1"
}

struct TransferStatus: Equatable {
    enum Phase: Equatable {
        case idle
        case preparing
        case queued(Date)
        case inProgress
        case completed(Date)
        case failed(String)
    }

    var phase: Phase = .idle
    var lastSuccessAt: Date?
}

struct LiftsLibraryState: Equatable {
    var fileURL: URL?
    var stats: CsvQuickStats?
    var lastImportedAt: Date?
    var importError: String?
    var transferStatus = TransferStatus()

    var isReadyForTransfer: Bool {
        fileURL != nil && stats != nil && importError == nil
    }
}

struct UserFacingError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

struct PlanLibraryState: Equatable {
    var fileURL: URL?
    var summary: PlanSummary?
    var lastImportedAt: Date?
    var importError: String?
    var transferStatus = TransferStatus()

    var isReadyForTransfer: Bool {
        fileURL != nil && summary != nil && importError == nil
    }
}

final class ExportInboxStore: NSObject, ObservableObject {
    @Published private(set) var latestFile: ExportedSnapshot?
    @Published private(set) var history: [ExportedSnapshot] = []
    @Published private(set) var liftsLibrary = LiftsLibraryState()
    @Published private(set) var planLibrary = PlanLibraryState()
    @Published private(set) var insights = InsightsSnapshot(
        personalRecords: .loading,
        nextWorkout: .loading,
        latestDayLabel: nil,
        generatedAt: nil
    )

    private let fileManager: FileManager
    private let inboxURL: URL
    private let globalDirectory: URL
    private let planDirectory: URL
    private let notificationCenter: UNUserNotificationCenter
    private var session: WCSession?
    private var isAppActive = true
    private var notificationAuthorizationRequested = false
    private let processingQueue = DispatchQueue(label: "ExportInboxStore.processing", qos: .utility)
    private var activeTransfers: [ObjectIdentifier: TransferKind] = [:]
    private let metadataDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let insightsEngine: InsightsEngine

    override init() {
        self.fileManager = .default
        self.notificationCenter = .current()
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let exportDirectory = applicationSupport.appendingPathComponent("ExportInbox", isDirectory: true)
        let weightWatchRoot = applicationSupport.appendingPathComponent("WeightWatch", isDirectory: true)
        let globalDirectory = weightWatchRoot.appendingPathComponent("Global", isDirectory: true)
        let planDirectory = weightWatchRoot.appendingPathComponent("Plans", isDirectory: true)
        self.inboxURL = exportDirectory
        self.globalDirectory = globalDirectory
        self.planDirectory = planDirectory
        self.insightsEngine = InsightsEngine(globalDirectory: globalDirectory, planDirectory: planDirectory, fileManager: fileManager)
        super.init()
        try? fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: globalDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: planDirectory, withIntermediateDirectories: true)
        loadExistingSnapshots()
        loadLocalLibraries()
        configureSession()
        refreshInsights()
    }

    func updateScenePhase(_ phase: ScenePhase) {
        isAppActive = phase == .active
        if isAppActive {
            refreshInsights()
        }
    }

    func requestNotificationAuthorization() {
        guard !notificationAuthorizationRequested else { return }
        notificationAuthorizationRequested = true
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func loadExistingSnapshots() {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let files: [URL]
            do {
                files = try self.fileManager.contentsOfDirectory(
                    at: self.inboxURL,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                .filter { $0.pathExtension.lowercased() == "csv" }
            } catch {
                print("ExportInboxStore: failed to load existing snapshots: \(error)")
                return
            }

            var snapshots: [ExportedSnapshot] = []
            for url in files {
                let schema = "v0.3"
                let stats = try? CsvQuickStats.compute(url: url, schema: schema)
                let modificationDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                let snapshot = ExportedSnapshot(
                    fileURL: url,
                    rows: stats?.rows ?? 0,
                    sizeBytes: stats?.sizeBytes ?? 0,
                    receivedAt: modificationDate,
                    schema: schema,
                    sha256: stats?.sha256
                )
                snapshots.append(snapshot)
            }

            snapshots.sort { $0.receivedAt > $1.receivedAt }

            DispatchQueue.main.async {
                self.history = snapshots
                self.latestFile = snapshots.first
            }
        }
    }

    private func loadLocalLibraries() {
        processingQueue.async { [weak self] in
            guard let self else { return }

            var liftsState = LiftsLibraryState()
            let liftsURL = self.globalDirectory.appendingPathComponent("all_time.csv")
            if self.fileManager.fileExists(atPath: liftsURL.path) {
                let stats = try? CsvQuickStats.compute(url: liftsURL, schema: "v0.3")
                liftsState.fileURL = liftsURL
                liftsState.stats = stats
                if let modificationDate = try? liftsURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    liftsState.lastImportedAt = modificationDate
                }
            }

            var planState = PlanLibraryState()
            let planURL = self.planDirectory.appendingPathComponent("active_plan.json")
            if self.fileManager.fileExists(atPath: planURL.path) {
                do {
                    let data = try Data(contentsOf: planURL)
                    let result = try PlanValidator.validate(data: data)
                    planState.fileURL = planURL
                    planState.summary = result.summary
                    if let modificationDate = try? planURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                        planState.lastImportedAt = modificationDate
                    }
                } catch {
                    print("ExportInboxStore: failed to load active plan: \(error)")
                }
            }

            DispatchQueue.main.async {
                self.liftsLibrary = liftsState
                self.planLibrary = planState
            }
            self.refreshInsights()
        }
    }

    private func configureSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        self.session = session
        session.activate()
    }

    func importLiftsCSV(from sourceURL: URL) async throws {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            processingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: UserFacingError(message: "Store unavailable."))
                    return
                }

                do {
                    let destination = self.globalDirectory.appendingPathComponent("all_time.csv")
                    try self.copyReplacingItem(from: sourceURL, to: destination)
                    let stats = try CsvQuickStats.compute(url: destination, schema: "v0.3")
                    let now = Date()
                    DispatchQueue.main.async {
                        self.liftsLibrary.fileURL = destination
                        self.liftsLibrary.stats = stats
                        self.liftsLibrary.lastImportedAt = now
                        self.liftsLibrary.importError = nil
                        self.liftsLibrary.transferStatus.phase = .idle
                    }
                    IndexService.shared.reload()
                    self.refreshInsights()
                    continuation.resume()
                } catch {
                    let wrapped = UserFacingError(message: "Import failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.liftsLibrary.importError = wrapped.message
                        self.liftsLibrary.stats = nil
                        self.liftsLibrary.fileURL = nil
                        self.liftsLibrary.transferStatus.phase = .failed(wrapped.message)
                    }
                    continuation.resume(throwing: wrapped)
                }
            }
        }
    }

    func importWorkoutPlan(from sourceURL: URL) async throws {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            processingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: UserFacingError(message: "Store unavailable."))
                    return
                }

                do {
                    let data = try Data(contentsOf: sourceURL)
                    let validation = try PlanValidator.validate(data: data)
                    let planURL = self.planDirectory.appendingPathComponent("active_plan.json")
                    try self.writeAtomically(data, to: planURL)
                    let now = Date()

                    DispatchQueue.main.async {
                        self.planLibrary.fileURL = planURL
                        self.planLibrary.summary = validation.summary
                        self.planLibrary.lastImportedAt = now
                        self.planLibrary.importError = nil
                        self.planLibrary.transferStatus.phase = .idle
                    }
                    self.refreshInsights()
                    continuation.resume()
                } catch {
                    let message = self.makePlanErrorMessage(from: error)
                    print("ExportInboxStore: failed to import plan \(sourceURL.lastPathComponent): \(message)")
                    let wrapped = UserFacingError(message: message)
                    DispatchQueue.main.async {
                        self.planLibrary.importError = wrapped.message
                        self.planLibrary.summary = nil
                        self.planLibrary.fileURL = nil
                        self.planLibrary.transferStatus.phase = .failed(wrapped.message)
                    }
                    continuation.resume(throwing: wrapped)
                }
            }
        }
    }

    func transferLiftsToWatch() throws {
        let session = try prepareSessionForTransfer()
        guard liftsLibrary.isReadyForTransfer,
              let fileURL = liftsLibrary.fileURL,
              let stats = liftsLibrary.stats else {
            throw UserFacingError(message: "Import a valid lifts.csv file before syncing.")
        }

        DispatchQueue.main.async {
            self.liftsLibrary.transferStatus.phase = .preparing
        }

        let metadata: [String: Any] = [
            "kind": TransferKind.globalCSV.rawValue,
            "rows": stats.rows,
            "sha256": stats.sha256,
            "schema": stats.schema,
            "size_bytes": stats.sizeBytes,
            "queued_at": metadataDateFormatter.string(from: Date())
        ]

        let transfer = session.transferFile(fileURL, metadata: metadata)
        let identifier = ObjectIdentifier(transfer)
        processingQueue.sync {
            activeTransfers[identifier] = .globalCSV
        }
        DispatchQueue.main.async {
            self.liftsLibrary.transferStatus.phase = .queued(Date())
        }
    }

    func transferPlanToWatch() throws {
        let session = try prepareSessionForTransfer()
        guard planLibrary.isReadyForTransfer,
              let fileURL = planLibrary.fileURL,
              let summary = planLibrary.summary else {
            throw UserFacingError(message: "Import a workout plan JSON file before syncing.")
        }

        DispatchQueue.main.async {
            self.planLibrary.transferStatus.phase = .preparing
        }

        var metadata: [String: Any] = [
            "kind": TransferKind.planV03.rawValue,
            "plan_name": summary.planName,
            "unit": summary.unit.csvValue,
            "day_count": summary.dayCount,
            "sha256": summary.sha256,
            "queued_at": metadataDateFormatter.string(from: Date())
        ]
        if !summary.warnings.isEmpty {
            metadata["warnings"] = summary.warnings
        }

        let transfer = session.transferFile(fileURL, metadata: metadata)
        let identifier = ObjectIdentifier(transfer)
        processingQueue.sync {
            activeTransfers[identifier] = .planV03
        }
        DispatchQueue.main.async {
            self.planLibrary.transferStatus.phase = .queued(Date())
        }
    }

    func refreshInsightsFromUI() {
        refreshInsights()
    }

    private func prepareSessionForTransfer() throws -> WCSession {
        guard WCSession.isSupported() else {
            throw UserFacingError(message: "WatchConnectivity is not supported on this device.")
        }
        guard let session else {
            throw UserFacingError(message: "WatchConnectivity session is not ready yet. Try again in a moment.")
        }
        guard session.isPaired else {
            throw UserFacingError(message: "No paired Apple Watch detected.")
        }
        guard session.isWatchAppInstalled else {
            throw UserFacingError(message: "Install the Watch app before syncing.")
        }
        if session.activationState != .activated {
            session.activate()
            throw UserFacingError(message: "Connecting to your Apple Watch. Please try again shortly.")
        }
        return session
    }

    private func copyReplacingItem(from sourceURL: URL, to destination: URL) throws {
        let folder = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let tempExtension = destination.pathExtension.isEmpty ? "tmp" : destination.pathExtension
        let temp = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(tempExtension)
        if fileManager.fileExists(atPath: temp.path) {
            try fileManager.removeItem(at: temp)
        }
        try fileManager.copyItem(at: sourceURL, to: temp)

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temp)
        } else {
            try fileManager.moveItem(at: temp, to: destination)
        }
    }

    private func writeAtomically(_ data: Data, to destination: URL) throws {
        let folder = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let temp = folder.appendingPathComponent(UUID().uuidString)
        try data.write(to: temp, options: .atomic)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temp)
        } else {
            try fileManager.moveItem(at: temp, to: destination)
        }
    }

    private func makePlanErrorMessage(from error: Error) -> String {
        if let validationError = error as? PlanValidationError {
            switch validationError {
            case .emptyData:
                return "Plan file is empty."
            case .missingDays:
                return "Plan file does not include any days."
            case .decodingFailed(let underlying):
                return "Could not decode plan: \(underlying.localizedDescription)"
            }
        }
        return "Plan import failed: \(error.localizedDescription)"
    }

    private func persistFile(_ file: WCSessionFile) -> ExportedSnapshot? {
        let schemaCandidate = (file.metadata?["kind"] as? String)?
            .components(separatedBy: "csv.")
            .last ?? "v0.3"
        let destination = inboxURL.appendingPathComponent(file.fileURL.lastPathComponent)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
            try fileManager.moveItem(at: file.fileURL, to: destination)
            let stats = try? CsvQuickStats.compute(url: destination, schema: schemaCandidate)
            let rowsFromMetadata = file.metadata?["rows"] as? Int
            let snapshot = ExportedSnapshot(
                fileURL: destination,
                rows: stats?.rows ?? rowsFromMetadata ?? 0,
                sizeBytes: stats?.sizeBytes ?? 0,
                receivedAt: Date(),
                schema: schemaCandidate,
                sha256: stats?.sha256
            )
            return snapshot
        } catch {
            print("ExportInboxStore: failed to persist file (\(error))")
            return nil
        }
    }

    private func handleSnapshot(_ snapshot: ExportedSnapshot) {
        latestFile = snapshot
        history.removeAll { $0.id == snapshot.id }
        history.insert(snapshot, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        if !isAppActive {
            scheduleNotification(for: snapshot)
        }
    }

    private func scheduleNotification(for snapshot: ExportedSnapshot) {
        let content = UNMutableNotificationContent()
        content.title = "CSV Export Ready"
        content.body = snapshot.fileName
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        notificationCenter.add(request)
    }

    private func refreshInsights() {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.insightsEngine.computeSnapshot()
            DispatchQueue.main.async {
                self.insights = snapshot
            }
        }
    }
}

extension ExportInboxStore: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("ExportInboxStore: activation failed with \(error)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self, let snapshot = self.persistFile(file) else { return }
            DispatchQueue.main.async {
                self.handleSnapshot(snapshot)
            }
        }
    }

    func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        let identifier = ObjectIdentifier(fileTransfer)
        let kind = processingQueue.sync { activeTransfers.removeValue(forKey: identifier) }

        guard let kind else { return }
        let now = Date()
        let errorMessage = error?.localizedDescription

        DispatchQueue.main.async {
            switch kind {
            case .globalCSV:
                if let errorMessage {
                    self.liftsLibrary.transferStatus.phase = .failed(errorMessage)
                } else {
                    self.liftsLibrary.transferStatus.lastSuccessAt = now
                    self.liftsLibrary.transferStatus.phase = .completed(now)
                }
            case .planV03:
                if let errorMessage {
                    self.planLibrary.transferStatus.phase = .failed(errorMessage)
                } else {
                    self.planLibrary.transferStatus.lastSuccessAt = now
                    self.planLibrary.transferStatus.phase = .completed(now)
                }
            }
        }
    }
}

// MARK: - Convenience Properties for Views

extension ExportInboxStore {
    var nextWorkout: NextWorkoutDisplay? {
        if case .ready(let workout) = insights.nextWorkout {
            return workout
        }
        return nil
    }

    var activePlan: PlanV03? {
        let planURL = planDirectory.appendingPathComponent("active_plan.json")
        guard fileManager.fileExists(atPath: planURL.path),
              let data = try? Data(contentsOf: planURL),
              let validation = try? PlanValidator.validate(data: data) else {
            return nil
        }
        return validation.plan
    }

    var latestDayLabel: String? {
        insights.latestDayLabel
    }
}
