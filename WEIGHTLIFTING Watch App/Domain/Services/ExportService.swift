//
//  ExportService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-30.
//

import Combine
import Foundation
import WatchConnectivity

final class ExportService: NSObject {
    struct SnapshotSummary: Equatable {
        let fileName: String
        let url: URL
        let rows: Int
    }

    enum ExportEvent {
        case queued(SnapshotSummary)
        case delivered(SnapshotSummary)
        case failed(SnapshotSummary?, ExportError)
    }

    enum ExportError: Error {
        case sessionUnsupported
        case notPaired
        case snapshotCreation(Error)
        case transfer(Error)
        case activationFailed(Error)
        case unknown

        var displayMessage: String {
            switch self {
            case .sessionUnsupported:
                return "Export unavailable on this device."
            case .notPaired:
                return "No paired iPhone."
            case .snapshotCreation:
                return "Could not create export snapshot."
            case .transfer:
                return "Export failed."
            case .activationFailed:
                return "WatchConnectivity activation failed."
            case .unknown:
                return "Unexpected export error."
            }
        }
    }

    private struct SnapshotRecord {
        let summary: SnapshotSummary
        let metaURL: URL
    }

    private enum SnapshotCreationError: Error {
        case missingSource
    }

    private let schemaVersion = "v0.3"
    private let fileSystem: FileSystem
    private let globalCsv: GlobalCsv
    private let fileManager: FileManager
    private let timestampFormatter: DateFormatter
    private let eventsSubject = PassthroughSubject<ExportEvent, Never>()
    private let queue = DispatchQueue(label: "ExportService.queue")
    private var session: WCSession?
    private var pendingSnapshots: [SnapshotRecord] = []
    private var activeSnapshots: [String: SnapshotRecord] = [:]
    private let prunerKeepCount = 5
    private let incomingHandler: ((WCSessionFile) -> Void)?

    var eventsPublisher: AnyPublisher<ExportEvent, Never> {
        eventsSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(
        fileSystem: FileSystem,
        globalCsv: GlobalCsv,
        fileManager: FileManager = .default,
        dateFormatter: DateFormatter? = nil,
        incomingHandler: ((WCSessionFile) -> Void)? = nil
    ) {
        self.fileSystem = fileSystem
        self.globalCsv = globalCsv
        self.fileManager = fileManager
        let formatter = dateFormatter ?? DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss-SSS"
        self.timestampFormatter = formatter
        self.incomingHandler = incomingHandler
        super.init()
        configureSession()
    }

    func exportSnapshotToPhone() {
        queue.async {
            do {
                let record = try self.createSnapshot()
                guard let session = self.session else {
                    self.discardSnapshot(record)
                    self.emit(.failed(record.summary, .sessionUnsupported))
                    return
                }

                guard session.isCompanionAppInstalled else {
                    self.discardSnapshot(record)
                    self.emit(.failed(record.summary, .notPaired))
                    return
                }

                self.pendingSnapshots.append(record)
                self.emit(.queued(record.summary))
                self.flushPendingTransfers()
            } catch {
                self.emit(.failed(nil, .snapshotCreation(error)))
            }
        }
    }

    func handleScenePhaseChange() {
        queue.async {
            self.flushPendingTransfers()
        }
    }

    private func configureSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        self.session = session
        session.activate()
    }

    private func createSnapshot() throws -> SnapshotRecord {
        try globalCsv.sync()
        let sourceURL = try fileSystem.globalCsvURL()

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw SnapshotCreationError.missingSource
        }

        let directory = sourceURL.deletingLastPathComponent()
        let timestamp = timestampFormatter.string(from: Date())
        let temporaryURL = directory.appendingPathComponent("AllTime-\(timestamp)-pending.csv")

        if fileManager.fileExists(atPath: temporaryURL.path) {
            try fileManager.removeItem(at: temporaryURL)
        }
        try fileManager.copyItem(at: sourceURL, to: temporaryURL)

        let stats = try CsvQuickStats.compute(url: temporaryURL, schema: schemaVersion)
        let finalFileName = "AllTime-\(timestamp)-rows~\(stats.rows)-\(schemaVersion).csv"
        let finalURL = directory.appendingPathComponent(finalFileName)
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: finalURL)

        let metaURL = finalURL.appendingPathExtension("meta.json")
        try stats.writeJSON(to: metaURL)
        fileSystem.fsyncDirectory(containing: finalURL)

        let summary = SnapshotSummary(fileName: finalFileName, url: finalURL, rows: stats.rows)
        return SnapshotRecord(summary: summary, metaURL: metaURL)
    }

    private func discardSnapshot(_ record: SnapshotRecord) {
        try? fileManager.removeItem(at: record.summary.url)
        try? fileManager.removeItem(at: record.metaURL)
    }

    private func flushPendingTransfers() {
        guard let session = session else { return }
        guard session.activationState == .activated else { return }

        guard session.isCompanionAppInstalled else {
            for record in pendingSnapshots {
                discardSnapshot(record)
                emit(.failed(record.summary, .notPaired))
            }
            pendingSnapshots.removeAll()
            return
        }

        let metadataFormatter = ISO8601DateFormatter()

        for record in pendingSnapshots {
            let filePath = record.summary.url.path
            guard activeSnapshots[filePath] == nil else { continue }
            let metadata: [String: Any] = [
                "kind": "csv.\(schemaVersion)",
                "rows": record.summary.rows,
                "filename": record.summary.fileName,
                "queued_at": metadataFormatter.string(from: Date())
            ]
            _ = session.transferFile(record.summary.url, metadata: metadata)
            activeSnapshots[filePath] = record
        }

        pendingSnapshots.removeAll()
    }

    private func emit(_ event: ExportEvent) {
        eventsSubject.send(event)
    }

    private func pruneSnapshotsIfNeeded() {
        queue.async {
            let directory: URL
            do {
                directory = try self.fileSystem.globalCsvURL().deletingLastPathComponent()
            } catch {
                return
            }
            let pruner = ExportPruner(
                directory: directory,
                keepLast: self.prunerKeepCount,
                fileManager: self.fileManager
            )
            pruner.prune()
        }
    }
}

extension ExportService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        queue.async {
            if let error {
                self.emit(.failed(nil, .activationFailed(error)))
            }
            if activationState == .activated {
                self.flushPendingTransfers()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        queue.async {
            self.flushPendingTransfers()
        }
    }

    func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        queue.async {
            let key = fileTransfer.file.fileURL.path
            let record = self.activeSnapshots.removeValue(forKey: key)
            if let error {
                if let record {
                    self.pendingSnapshots.append(record)
                    self.emit(.failed(record.summary, .transfer(error)))
                    self.flushPendingTransfers()
                } else {
                    self.emit(.failed(nil, .transfer(error)))
                }
            } else if let record {
                self.emit(.delivered(record.summary))
                self.pruneSnapshotsIfNeeded()
            }
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        incomingHandler?(file)
    }
}
