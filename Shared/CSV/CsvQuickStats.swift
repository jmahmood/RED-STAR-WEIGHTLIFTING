//
//  CsvQuickStats.swift
//  Shared
//
//  Computes quick metadata (row count, size, hash) for CSV exports.
//

import CryptoKit
import Foundation

public struct CsvQuickStats: Codable, Equatable {
    public let schema: String
    public let rows: Int
    public let sizeBytes: Int
    public let sha256: String

    public var sizeKilobytes: Double {
        Double(sizeBytes) / 1024.0
    }

    public static func compute(url: URL, schema: String) throws -> CsvQuickStats {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0

        var hasher = SHA256()
        var newlineCount = 0
        var lastByte: UInt8 = 0
        var sawBytes = false

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        while true {
            let optionalChunk = try handle.read(upToCount: 64 * 1024)
            guard let chunk = optionalChunk, !chunk.isEmpty else { break }
            sawBytes = true
            hasher.update(data: chunk)
            newlineCount += chunk.reduce(into: 0) { count, byte in
                if byte == 0x0A { count += 1 }
            }
            if let finalByte = chunk.last {
                lastByte = finalByte
            }
        }

        let sizeBytes = fileSize
        let totalLines: Int
        if !sawBytes {
            totalLines = 0
        } else if lastByte == 0x0A {
            totalLines = newlineCount
        } else {
            totalLines = newlineCount + 1
        }

        let rowCount = max(0, totalLines - 1)
        let digest = hasher.finalize()
        let sha256 = digest.map { String(format: "%02x", $0) }.joined()

        return CsvQuickStats(schema: schema, rows: rowCount, sizeBytes: sizeBytes, sha256: sha256)
    }

    public func writeJSON(to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}
