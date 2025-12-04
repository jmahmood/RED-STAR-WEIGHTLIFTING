//
//  CompanionIncomingService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-31.
//

import Foundation
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
    private let decoder: JSONDecoder
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
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func handle(file: WCSessionFile) {
        let workingURL: URL
        do {
            workingURL = try makeWorkingCopy(of: file.fileURL)
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
            do {
                switch kind {
                case .globalCSV:
                    try self.applyGlobalCSV(from: workingURL)
                    self.resetAfterDataChange()
                case .planV03:
                    try self.applyPlan(from: workingURL)
                    self.resetAfterDataChange()
                case nil:
                    #if DEBUG
                    print("CompanionIncomingService: ignoring file with unknown kind: \(file.fileURL.lastPathComponent)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("CompanionIncomingService: failed to apply incoming file \(error)")
                #endif
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
        let plan = try decoder.decode(PlanV03.self, from: data)
        guard !plan.days.isEmpty else {
            throw IncomingError.invalidPlan
        }

        let destination = try fileSystem.planURL(named: "active_plan.json")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileSystem.ensureDirectoryExists(at: destination.deletingLastPathComponent())
        try data.write(to: destination, options: .atomic)
        fileSystem.fsyncDirectory(containing: destination)
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
}
