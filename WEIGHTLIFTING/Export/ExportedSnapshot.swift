//
//  ExportedSnapshot.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-30.
//

import Foundation

struct ExportedSnapshot: Identifiable, Equatable {
    let id: String
    let fileURL: URL
    let rows: Int
    let sizeBytes: Int
    let receivedAt: Date
    let schema: String
    let sha256: String?

    init(fileURL: URL, rows: Int, sizeBytes: Int, receivedAt: Date, schema: String, sha256: String?) {
        self.id = fileURL.lastPathComponent
        self.fileURL = fileURL
        self.rows = rows
        self.sizeBytes = sizeBytes
        self.receivedAt = receivedAt
        self.schema = schema
        self.sha256 = sha256
    }

    var fileName: String {
        fileURL.lastPathComponent
    }

    var sizeLabel: String {
        if sizeBytes == 0 { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeBytes))
    }
}
