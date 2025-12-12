//
//  StoragePaths.swift
//  Shared
//
//  Canonical file locations for all targets (iOS, watchOS, extensions).
//

import Foundation

public struct StoragePaths: Sendable {
    public let rootURL: URL
    public let globalDirectory: URL
    public let plansDirectory: URL
    public let exportInboxDirectory: URL

    public let globalCSVURL: URL
    public let globalIndexURL: URL

    /// Legacy (pre-AppGroup) active plan JSON location.
    public let legacyActivePlanURL: URL

    public static let defaultAppGroupIDs: [String] = [
        "group.com.jawaadmahmood.WEIGHTLIFTING_SHARED",
        "group.com.jawaadmahmood.WEIGHTLIFTING"
    ]

    public static func makeDefault(
        fileManager: FileManager = .default,
        appGroupIDs: [String] = StoragePaths.defaultAppGroupIDs
    ) -> StoragePaths {
        let root = resolveRootURL(fileManager: fileManager, appGroupIDs: appGroupIDs)
        let legacyRoot = legacyWeightWatchRoot(fileManager: fileManager) ?? root

        let globalDirectory = root.appendingPathComponent("Global", isDirectory: true)
        let plansDirectory = root.appendingPathComponent("Plans", isDirectory: true)
        let exportInboxDirectory = root
            .deletingLastPathComponent()
            .appendingPathComponent("ExportInbox", isDirectory: true)

        return StoragePaths(
            rootURL: root,
            globalDirectory: globalDirectory,
            plansDirectory: plansDirectory,
            exportInboxDirectory: exportInboxDirectory,
            globalCSVURL: globalDirectory.appendingPathComponent("all_time.csv"),
            globalIndexURL: globalDirectory.appendingPathComponent("index_last_by_ex.json"),
            legacyActivePlanURL: legacyRoot.appendingPathComponent("Plans/active_plan.json")
        )
    }

    public func planFileURL(planID: String) -> URL {
        plansDirectory
            .appendingPathComponent(planID, isDirectory: true)
            .appendingPathComponent("plan.json")
    }
}

private extension StoragePaths {
    static func resolveRootURL(fileManager: FileManager, appGroupIDs: [String]) -> URL {
        for id in appGroupIDs {
            if let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: id) {
                return container.appendingPathComponent("WeightWatch", isDirectory: true)
            }
        }

        if let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            return appSupport.appendingPathComponent("WeightWatch", isDirectory: true)
        }

        return fileManager.temporaryDirectory.appendingPathComponent("WeightWatch", isDirectory: true)
    }

    static func legacyWeightWatchRoot(fileManager: FileManager) -> URL? {
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }
        return appSupport.appendingPathComponent("WeightWatch", isDirectory: true)
    }
}

