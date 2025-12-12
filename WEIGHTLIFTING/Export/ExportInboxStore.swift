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
    @Published private(set) var lastWatchSyncDate: Date?
    @Published private(set) var iCloudAvailable: Bool = false
    @Published private(set) var lastICloudSyncDate: Date?
    @Published private(set) var lastICloudError: String?

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
    private let ubiquityContainerID = "iCloud.com.jawaadmahmood.WEIGHTLIFTING"

    override init() {
        self.fileManager = .default
        self.notificationCenter = .current()
        let paths = StoragePaths.makeDefault(fileManager: fileManager)
        self.inboxURL = paths.exportInboxDirectory
        self.globalDirectory = paths.globalDirectory
        self.planDirectory = paths.plansDirectory
        self.insightsEngine = InsightsEngine(globalDirectory: paths.globalDirectory, planDirectory: paths.plansDirectory, fileManager: fileManager)
        super.init()
        try? fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: globalDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: planDirectory, withIntermediateDirectories: true)
        loadExistingSnapshots()
        loadLocalLibraries()
        configureSession()
        refreshInsights()
        initializeICloud()
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

            // Use PlanStore to load active plan
            do {
                if let plan = try PlanStore.shared.loadActivePlan() {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(plan)
                    let result = try PlanValidator.validate(data: data)
                    planState.fileURL = nil  // Not needed with PlanStore
                    planState.summary = result.summary
                    planState.lastImportedAt = Date()
                }
            } catch {
                print("ExportInboxStore: failed to load active plan: \(error)")
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
        print("ExportInboxStore: activating WCSession (state: \(session.activationState.rawValue))")
        session.activate()
    }

    private func initializeICloud() {
        processingQueue.async { [weak self] in
            guard let self else { return }

            if let ubiquityRoot = self.fileManager.url(forUbiquityContainerIdentifier: self.ubiquityContainerID) {
                print("ExportInboxStore: iCloud container initialized at \(ubiquityRoot.path)")
                let documents = ubiquityRoot.appendingPathComponent("Documents", isDirectory: true)
                let destination = documents.appendingPathComponent("WeightWatch", isDirectory: false)

                do {
                    try self.fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                    DispatchQueue.main.async {
                        self.iCloudAvailable = true
                        self.lastICloudError = nil
                    }
                    print("ExportInboxStore: iCloud is available and ready")
                } catch {
                    print("ExportInboxStore: failed to create iCloud directory: \(error)")
                    DispatchQueue.main.async {
                        self.iCloudAvailable = false
                        self.lastICloudError = "Failed to initialize: \(error.localizedDescription)"
                    }
                }
            } else {
                print("ExportInboxStore: iCloud container unavailable (\(self.ubiquityContainerID))")
                print("ExportInboxStore: User may not be signed into iCloud or container not configured")
                DispatchQueue.main.async {
                    self.iCloudAvailable = false
                    self.lastICloudError = "iCloud unavailable. Please sign in to iCloud in Settings."
                }
            }
        }
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
                    // Also save to iCloud for manual imports
                    self.saveToICloudIfAvailable(from: destination)
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

                    // Use PlanStore for saving (reuse active plan ID to preserve history)
                    let planID = (try? PlanStore.shared.getActivePlanID())
                        ?? PlanStore.generatePlanID(from: validation.plan.planName)
                    try PlanStore.shared.savePlan(validation.plan, id: planID, snapshotIfExists: true)
                    try PlanStore.shared.setActivePlan(id: planID)

                    let now = Date()

                    DispatchQueue.main.async {
                        self.planLibrary.fileURL = nil  // Not needed with PlanStore
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
        print("ExportInboxStore: transferPlanToWatch called")
        let session = try prepareSessionForTransfer()

        // Log session state for diagnostics
        print("ExportInboxStore: Session state - activated: \(session.activationState == .activated), paired: \(session.isPaired), watchAppInstalled: \(session.isWatchAppInstalled), reachable: \(session.isReachable)")

        guard planLibrary.isReadyForTransfer,
              let fileURL = planLibrary.fileURL,
              let summary = planLibrary.summary else {
            let error = "Import a workout plan JSON file before syncing."
            print("ExportInboxStore: Plan not ready - fileURL: \(planLibrary.fileURL != nil), summary: \(planLibrary.summary != nil), error: \(planLibrary.importError ?? "none")")
            throw UserFacingError(message: error)
        }

        print("ExportInboxStore: Transferring plan '\(summary.planName)' from: \(fileURL.path)")
        print("ExportInboxStore: File exists: \(fileManager.fileExists(atPath: fileURL.path))")

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

        print("ExportInboxStore: Starting file transfer with metadata: \(metadata)")
        let transfer = session.transferFile(fileURL, metadata: metadata)
        print("ExportInboxStore: Transfer object created - isTransferring: \(transfer.isTransferring)")

        let identifier = ObjectIdentifier(transfer)
        processingQueue.sync {
            activeTransfers[identifier] = .planV03
        }
        DispatchQueue.main.async {
            self.planLibrary.transferStatus.phase = .queued(Date())
        }
        print("ExportInboxStore: Plan transfer queued, active transfers count: \(activeTransfers.count)")
    }

    private func transferPlanViaApplicationContext(session: WCSession, fileURL: URL, summary: PlanSummary) throws {
        let data = try Data(contentsOf: fileURL)
        let base64 = data.base64EncodedString()

        let context: [String: Any] = [
            "transfer_type": "plan_data",
            "kind": TransferKind.planV03.rawValue,
            "plan_name": summary.planName,
            "unit": summary.unit.csvValue,
            "day_count": summary.dayCount,
            "sha256": summary.sha256,
            "data": base64,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        try session.updateApplicationContext(context)
    }

    func refreshInsightsFromUI() {
        refreshInsights()
    }

    func reloadPlanLibrary() {
        processingQueue.async { [weak self] in
            guard let self else { return }

            var planState = PlanLibraryState()

            // Use PlanStore to load active plan
            do {
                if let plan = try PlanStore.shared.loadActivePlan() {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(plan)
                    let result = try PlanValidator.validate(data: data)
                    planState.fileURL = nil  // Not needed with PlanStore
                    planState.summary = result.summary
                    planState.lastImportedAt = Date()
                    print("ExportInboxStore: reloaded plan library - \(result.summary.planName)")
                } else {
                    print("ExportInboxStore: no active plan found")
                }
            } catch {
                print("ExportInboxStore: failed to reload active plan: \(error)")
            }

            DispatchQueue.main.async {
                self.planLibrary = planState
            }
            self.refreshInsights()
        }
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
            case .exerciseCodeNotInDictionary(let code, let dayLabel):
                return "Exercise '\(code)' on day '\(dayLabel)' is not defined in the exercise dictionary."
            case .invalidSets(let sets, let exerciseCode, let dayLabel):
                return "Invalid sets (\(sets)) for exercise '\(exerciseCode)' on day '\(dayLabel)'. Sets must be greater than 0."
            case .invalidReps(let exerciseCode, let dayLabel, let reason):
                return "Invalid reps for exercise '\(exerciseCode)' on day '\(dayLabel)': \(reason)"
            }
        }
        return "Plan import failed: \(error.localizedDescription)"
    }

    private func persistFile(_ file: WCSessionFile) -> ExportedSnapshot? {
        print("ExportInboxStore: didReceive file \(file.fileURL.lastPathComponent), metadata: \(String(describing: file.metadata))")
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

        // Mirror the newest snapshot into the local library and iCloud (if available)
        applySnapshotToLibrary(snapshot)
    }

    private func applySnapshotToLibrary(_ snapshot: ExportedSnapshot) {
        print("ExportInboxStore: applying snapshot to library \(snapshot.fileName)")
        processingQueue.async { [weak self] in
            guard let self else { return }
            do {
                let destination = self.globalDirectory.appendingPathComponent("all_time.csv")
                print("ExportInboxStore: copying snapshot to \(destination.path)")
                try self.copyReplacingItem(from: snapshot.fileURL, to: destination)
                let stats = try CsvQuickStats.compute(url: destination, schema: snapshot.schema)
                print("ExportInboxStore: copied snapshot rows=\(stats.rows) size=\(stats.sizeBytes)")
                let now = Date()
                DispatchQueue.main.async {
                    self.liftsLibrary.fileURL = destination
                    self.liftsLibrary.stats = stats
                    self.liftsLibrary.lastImportedAt = now
                    self.liftsLibrary.importError = nil
                }
                self.refreshInsights()
                self.saveToICloudIfAvailable(from: destination)
            } catch {
                print("ExportInboxStore: failed to apply snapshot to library (\(error))")
            }
        }
    }

    private func saveToICloudIfAvailable(from source: URL) {
        guard let ubiquityRoot = fileManager.url(forUbiquityContainerIdentifier: ubiquityContainerID) else {
            print("ExportInboxStore: iCloud container unavailable (\(ubiquityContainerID))")
            print("ExportInboxStore: Ensure user is signed into iCloud and container is configured")
            DispatchQueue.main.async {
                self.iCloudAvailable = false
                self.lastICloudError = "iCloud unavailable. Please sign in to iCloud in Settings."
            }
            return
        }
        let documents = ubiquityRoot.appendingPathComponent("Documents", isDirectory: true)
        let destination = documents.appendingPathComponent("WeightWatch/all_time.csv", isDirectory: false)

        do {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Always copy to avoid moving/removing the local source file.
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            print("ExportInboxStore: copying CSV to iCloud at \(destination.path)")
            try fileManager.copyItem(at: source, to: destination)
            let now = Date()
            DispatchQueue.main.async {
                self.iCloudAvailable = true
                self.lastICloudSyncDate = now
                self.lastICloudError = nil
            }
            print("ExportInboxStore: successfully saved CSV to iCloud")
        } catch {
            print("ExportInboxStore: failed to save snapshot to iCloud: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastICloudError = "Failed to save: \(error.localizedDescription)"
            }
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
        } else {
            print("ExportInboxStore: activation complete (state: \(activationState.rawValue))")

            // Seed an initial applicationContext to help establish connection on simulator
            if activationState == .activated {
                seedInitialApplicationContextIfNeeded(session)
            }
        }
    }

    private func seedInitialApplicationContextIfNeeded(_ session: WCSession) {
        // Send a minimal context to "prime" the WatchConnectivity connection
        // This helps file transfers work more reliably on simulator
        let context: [String: Any] = [
            "ready": true,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        do {
            try session.updateApplicationContext(context)
            print("ExportInboxStore: seeded initial applicationContext")
        } catch {
            print("ExportInboxStore: failed to seed applicationContext: \(error.localizedDescription)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("ExportInboxStore: didReceiveApplicationContext: \(applicationContext)")
        // We don't currently use applicationContext for data transfer, but implementing this
        // delegate method helps WatchConnectivity work more reliably on simulator
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("ExportInboxStore: didReceive file: \(file.fileURL.lastPathComponent)")
        // Persist synchronously inside the delegate; system cleans up the temp file
        // as soon as this method returns.
        guard let snapshot = persistFile(file) else {
            print("ExportInboxStore: Failed to persist file")
            return
        }
        print("ExportInboxStore: File persisted successfully, updating UI")
        DispatchQueue.main.async { [weak self] in
            self?.lastWatchSyncDate = Date()
            self?.handleSnapshot(snapshot)
        }
    }

    func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        let identifier = ObjectIdentifier(fileTransfer)
        let kind = processingQueue.sync { activeTransfers.removeValue(forKey: identifier) }

        guard let kind else {
            print("ExportInboxStore: didFinish fileTransfer - no matching active transfer")
            return
        }
        let now = Date()
        let errorMessage = error?.localizedDescription

        DispatchQueue.main.async {
            switch kind {
            case .globalCSV:
                if let errorMessage {
                    print("ExportInboxStore: CSV transfer failed: \(errorMessage)")
                    self.liftsLibrary.transferStatus.phase = .failed(errorMessage)
                } else {
                    print("ExportInboxStore: CSV transfer completed successfully")
                    self.liftsLibrary.transferStatus.lastSuccessAt = now
                    self.liftsLibrary.transferStatus.phase = .completed(now)
                }
            case .planV03:
                if let errorMessage {
                    print("ExportInboxStore: Plan transfer failed: \(errorMessage)")
                    self.planLibrary.transferStatus.phase = .failed(errorMessage)
                } else {
                    print("ExportInboxStore: Plan transfer completed successfully")
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
        // Use PlanStore to load active plan
        return try? PlanStore.shared.loadActivePlan()
    }

    var latestDayLabel: String? {
        insights.latestDayLabel
    }
}
