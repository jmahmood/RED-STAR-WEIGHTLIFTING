//
//  ExportPruner.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-30.
//

import Foundation

struct ExportPruner {
    let directory: URL
    let keepLast: Int
    let fileManager: FileManager

    func prune() {
        guard keepLast > 0 else { return }
        let csvFiles: [URL]
        do {
            csvFiles = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.lastPathComponent.hasPrefix("AllTime-") && $0.pathExtension == "csv" }
        } catch {
            return
        }

        guard csvFiles.count > keepLast else { return }

        let sorted = csvFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let excess = max(0, sorted.count - keepLast)
        guard excess > 0 else { return }

        for url in sorted.prefix(excess) {
            try? fileManager.removeItem(at: url)
            let metaURL = url.appendingPathExtension("meta.json")
            try? fileManager.removeItem(at: metaURL)
        }
    }
}
