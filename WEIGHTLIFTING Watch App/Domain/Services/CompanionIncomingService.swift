//
//  CompanionIncomingService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-31.
//

import Foundation
import UserNotifications
import WatchConnectivity

final class CompanionIncomingService {
    private enum IncomingError: Error {
        case invalidCSV
        case invalidPlan
    }

    private enum TransferKind: String {
        case globalCSV = "ios.global_csv.v1"
        case planV03 = "ios.plan_v03.v1"
    }

    private let fileSystem: FileSystem
    private let sessionManager: SessionManager
    private let indexService: IndexService
    private let complicationService: ComplicationService
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "CompanionIncomingService.queue", qos: .utility)

    init(
        fileSystem: FileSystem,
        sessionManager: SessionManager,
        indexService: IndexService,
        complicationService: ComplicationService,
        fileManager: FileManager = .default
    ) {
        self.fileSystem = fileSystem
        self.sessionManager = sessionManager
        self.indexService = indexService
        self.complicationService = complicationService
        self.fileManager = fileManager
    }

    func handle(file: WCSessionFile) {
        #if DEBUG
        print("CompanionIncomingService: ===== HANDLE FILE CALLED =====")
        print("CompanionIncomingService: File: \(file.fileURL.lastPathComponent)")
        print("CompanionIncomingService: Metadata: \(String(describing: file.metadata))")
        #endif

        let workingURL: URL
        do {
            workingURL = try makeWorkingCopy(of: file.fileURL)
            #if DEBUG
            print("CompanionIncomingService: Working copy created at: \(workingURL.path)")
            #endif
        } catch {
            #if DEBUG
            print("CompanionIncomingService: failed to stage incoming file \(error)")
            #endif
            return
        }

        queue.async { [weak self] in
            defer { try? FileManager.default.removeItem(at: workingURL) }
            guard let self else { return }

            let kind = self.resolveKind(from: file)
            #if DEBUG
            print("CompanionIncomingService: Resolved kind: \(String(describing: kind))")
            #endif

            do {
                switch kind {
                case .globalCSV:
                    #if DEBUG
                    print("CompanionIncomingService: Processing as globalCSV")
                    #endif
                    try self.applyGlobalCSV(from: workingURL)
                    self.resetAfterDataChange()
                    #if DEBUG
                    print("CompanionIncomingService: globalCSV applied successfully")
                    #endif
                case .planV03:
                    #if DEBUG
                    print("CompanionIncomingService: Processing as planV03")
                    #endif
                    try self.applyPlan(from: workingURL)
                    self.resetAfterDataChange()
                    #if DEBUG
                    print("CompanionIncomingService: planV03 applied successfully")
                    #endif
                case nil:
                    #if DEBUG
                    print("CompanionIncomingService: ignoring file with unknown kind: \(file.fileURL.lastPathComponent)")
                    #endif
                }
            } catch {
                self.reportFailure(kind: kind, file: file, error: error)
            }
        }
    }
}

private extension CompanionIncomingService {
    private func makeWorkingCopy(of sourceURL: URL) throws -> URL {
        let tempDirectory = fileManager.temporaryDirectory
        let extensionComponent = sourceURL.pathExtension.isEmpty ? "tmp" : sourceURL.pathExtension
        let destination = tempDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(extensionComponent)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    private func resolveKind(from file: WCSessionFile) -> TransferKind? {
        if let raw = file.metadata?["kind"] as? String, let kind = TransferKind(rawValue: raw) {
            return kind
        }
        let ext = file.fileURL.pathExtension.lowercased()
        switch ext {
        case "csv":
            return .globalCSV
        case "json":
            return .planV03
        default:
            return nil
        }
    }

    private func applyGlobalCSV(from url: URL) throws {
        try validateCSV(at: url)
        let destination = try fileSystem.globalCsvURL()
        let directory = destination.deletingLastPathComponent()
        try fileSystem.ensureDirectoryExists(at: directory)

        let temp = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("csv")
        if fileManager.fileExists(atPath: temp.path) {
            try fileManager.removeItem(at: temp)
        }
        try fileManager.copyItem(at: url, to: temp)

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temp)
        } else {
            try fileManager.moveItem(at: temp, to: destination)
        }

        fileSystem.fsyncDirectory(containing: destination)

        if let indexURL = try? fileSystem.indexURL(), fileManager.fileExists(atPath: indexURL.path) {
            try? fileManager.removeItem(at: indexURL)
        }
        indexService.rebuildFromCSV()
    }

    private func applyPlan(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let validation = try PlanValidator.validate(data: data)
        let plan = validation.plan
        guard !plan.days.isEmpty else {
            throw IncomingError.invalidPlan
        }

        // Use PlanStore for saving
        let planID = PlanStore.generatePlanID(from: plan.planName)
        try PlanStore.shared.savePlan(plan, id: planID)
        try PlanStore.shared.setActivePlan(id: planID)
    }

    private func validateCSV(at url: URL) throws {
        // Read first 8KB to validate CSV header
        // Using Data instead of FileHandle to avoid Swift 6.2 concurrency issues
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        let readSize = min(fileSize, 8 * 1024)

        let data: Data
        if readSize == fileSize {
            data = try Data(contentsOf: url)
        } else {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            data = try handle.read(upToCount: readSize) ?? Data()
        }

        guard let snippet = String(data: data, encoding: .utf8),
              let header = snippet.split(whereSeparator: \.isNewline).first else {
            throw IncomingError.invalidCSV
        }
        let columns = header
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard columns.contains("ex_code"), columns.contains("weight") else {
            throw IncomingError.invalidCSV
        }
    }

    private func resetAfterDataChange() {
        do {
            try fileSystem.removeDirectoryContents(.sessions)
        } catch {
            #if DEBUG
            print("CompanionIncomingService: failed clearing sessions \(error)")
            #endif
        }

        DispatchQueue.main.async {
            self.complicationService.clearNextUp()
            self.sessionManager.loadInitialSession()
        }
    }

    private func reportFailure(kind: TransferKind?, file: WCSessionFile, error: Error) {
        let message = "Failed to import \(kind?.rawValue ?? file.fileURL.lastPathComponent): \(error.localizedDescription)"
        print("CompanionIncomingService: \(message)")

        switch kind {
        case .planV03:
            notifyPlanFailure(message: message)
        default:
            break
        }
    }

    private func notifyPlanFailure(message: String) {
        let center = UNUserNotificationCenter.current()

        let sendNotification = {
            let content = UNMutableNotificationContent()
            content.title = "Plan import failed"
            content.body = message
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request, withCompletionHandler: nil)
        }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                sendNotification()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { sendNotification() }
                }
            default:
                break
            }
        }
    }
}
