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
            #if DEBUG
            print("ExportService: exportSnapshotToPhone called")
            #endif
            do {
                let record = try self.createSnapshot()
                #if DEBUG
                print("ExportService: Snapshot created: \(record.summary.fileName), rows: \(record.summary.rows)")
                #endif
                guard let session = self.session else {
                    #if DEBUG
                    print("ExportService: Session is nil - WCSession not supported")
                    #endif
                    self.discardSnapshot(record)
                    self.emit(.failed(record.summary, .sessionUnsupported))
                    return
                }

//                #if DEBUG
//                print("ExportService: Session state: \(session.activationState.rawValue), isPaired: \(session.isPaired), isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
//                #endif

                guard session.isCompanionAppInstalled else {
                    #if DEBUG
                    print("ExportService: Companion app not installed")
                    #endif
                    self.discardSnapshot(record)
                    self.emit(.failed(record.summary, .notPaired))
                    return
                }

                self.pendingSnapshots.append(record)
                #if DEBUG
                print("ExportService: Snapshot added to pending queue, emitting queued event")
                #endif
                self.emit(.queued(record.summary))
                self.flushPendingTransfers()
            } catch {
                #if DEBUG
                print("ExportService: Snapshot creation failed: \(error)")
                #endif
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
        guard let session = session else {
            #if DEBUG
            print("ExportService: flushPendingTransfers - session is nil")
            #endif
            return
        }
        guard session.activationState == .activated else {
            #if DEBUG
            print("ExportService: flushPendingTransfers - session not activated (state: \(session.activationState.rawValue))")
            #endif
            return
        }

        guard session.isCompanionAppInstalled else {
            #if DEBUG
            print("ExportService: flushPendingTransfers - companion app not installed, discarding \(pendingSnapshots.count) snapshots")
            #endif
            for record in pendingSnapshots {
                discardSnapshot(record)
                emit(.failed(record.summary, .notPaired))
            }
            pendingSnapshots.removeAll()
            return
        }

        #if DEBUG
        print("ExportService: flushPendingTransfers - processing \(pendingSnapshots.count) pending snapshots")
        #endif

        let metadataFormatter = ISO8601DateFormatter()

        for record in pendingSnapshots {
            let filePath = record.summary.url.path
            guard activeSnapshots[filePath] == nil else {
                #if DEBUG
                print("ExportService: Skipping \(filePath) - already in activeSnapshots")
                #endif
                continue
            }
            let metadata: [String: Any] = [
                "kind": "csv.\(schemaVersion)",
                "rows": record.summary.rows,
                "filename": record.summary.fileName,
                "queued_at": metadataFormatter.string(from: Date())
            ]
            #if DEBUG
            print("ExportService: Transferring file: \(record.summary.fileName) with metadata: \(metadata)")
            #endif
            _ = session.transferFile(record.summary.url, metadata: metadata)
            activeSnapshots[filePath] = record
        }

        pendingSnapshots.removeAll()
        #if DEBUG
        print("ExportService: flushPendingTransfers complete, \(activeSnapshots.count) active transfers")
        #endif
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
        #if DEBUG
        print("ExportService: WCSession activation completed - state: \(activationState.rawValue), error: \(String(describing: error))")
        #endif
        queue.async {
            if let error {
                self.emit(.failed(nil, .activationFailed(error)))
            }
            if activationState == .activated {
                #if DEBUG
                print("ExportService: Session activated, flushing pending transfers")
                #endif
                self.flushPendingTransfers()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        #if DEBUG
        print("ExportService: Session reachability changed - isReachable: \(session.isReachable)")
        #endif
        queue.async {
            self.flushPendingTransfers()
        }
    }

    func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        #if DEBUG
        print("ExportService: File transfer finished - file: \(fileTransfer.file.fileURL.lastPathComponent), error: \(String(describing: error))")
        #endif
        queue.async {
            let key = fileTransfer.file.fileURL.path
            let record = self.activeSnapshots.removeValue(forKey: key)
            if let error {
                #if DEBUG
                print("ExportService: Transfer failed with error: \(error)")
                #endif
                if let record {
                    self.pendingSnapshots.append(record)
                    self.emit(.failed(record.summary, .transfer(error)))
                    self.flushPendingTransfers()
                } else {
                    self.emit(.failed(nil, .transfer(error)))
                }
            } else if let record {
                #if DEBUG
                print("ExportService: Transfer succeeded for \(record.summary.fileName)")
                #endif
                self.emit(.delivered(record.summary))
                self.pruneSnapshotsIfNeeded()
            }
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        #if DEBUG
        print("ExportService: Received file from companion: \(file.fileURL.lastPathComponent)")
        #endif
        incomingHandler?(file)
    }
}
