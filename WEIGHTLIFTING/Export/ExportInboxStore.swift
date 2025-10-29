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

final class ExportInboxStore: NSObject, ObservableObject {
    @Published private(set) var latestFile: ExportedSnapshot?
    @Published private(set) var history: [ExportedSnapshot] = []

    private let fileManager: FileManager
    private let inboxURL: URL
    private let notificationCenter: UNUserNotificationCenter
    private var session: WCSession?
    private var isAppActive = true
    private var notificationAuthorizationRequested = false
    private let processingQueue = DispatchQueue(label: "ExportInboxStore.processing", qos: .utility)

    override init() {
        self.fileManager = .default
        self.notificationCenter = .current()
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let exportDirectory = applicationSupport.appendingPathComponent("ExportInbox", isDirectory: true)
        self.inboxURL = exportDirectory
        super.init()
        try? fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        loadExistingSnapshots()
        configureSession()
    }

    func updateScenePhase(_ phase: ScenePhase) {
        isAppActive = phase == .active
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

    private func configureSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        self.session = session
        session.activate()
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
}
