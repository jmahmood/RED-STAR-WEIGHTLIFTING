//
//  ExportService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

final class ExportService {
    private let fileSystem: FileSystem

    init(fileSystem: FileSystem) {
        self.fileSystem = fileSystem
    }

    func exportGlobalCsv() {
        // TODO: S1-T22 implement WatchConnectivity transfer.
        _ = try? fileSystem.globalCsvURL()
    }
}
