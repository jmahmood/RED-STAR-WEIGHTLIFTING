//
//  ResourceSeeder.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

struct ResourceSeeder {
    private let bundle: Bundle
    private let fileSystem: FileSystem

    init(bundle: Bundle, fileSystem: FileSystem) {
        self.bundle = bundle
        self.fileSystem = fileSystem
    }

    func seedPlanIfNeeded(resourceName: String = "minimalist_4x_plan_block_1") {
        guard let sourceURL = resolveURL(resourceName: resourceName, fileExtension: "json") else {
            return
        }

        do {
            let destination = try fileSystem.planURL(named: "active_plan.json")
            try fileSystem.copyIfMissing(from: sourceURL, to: destination)
        } catch {
            #if DEBUG
            print("ResourceSeeder plan seed failed: \(error)")
            #endif
        }
    }

    func seedGlobalCsvIfNeeded() {
        guard let seedURL = resolveURL(resourceName: "seed_all_time", fileExtension: "csv") else {
            return
        }

        do {
            let destination = try fileSystem.globalCsvURL()
            try fileSystem.copyIfMissing(from: seedURL, to: destination)
        } catch {
            #if DEBUG
            print("ResourceSeeder seed failed: \(error)")
            #endif
        }
    }

    private func resolveURL(resourceName: String, fileExtension: String) -> URL? {
        if let url = bundle.url(forResource: resourceName, withExtension: fileExtension) {
            return url
        }

        #if DEBUG
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fallback = cwd.appendingPathComponent(resourceName).appendingPathExtension(fileExtension)
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        #endif

        return nil
    }
}
