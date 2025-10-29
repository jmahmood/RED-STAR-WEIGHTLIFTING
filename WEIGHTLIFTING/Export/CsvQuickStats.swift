//
//  CsvQuickStats.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-30.
//

#if !os(watchOS)
import CryptoKit
import Foundation

struct CsvQuickStats: Codable {
    let schema: String
    let rows: Int
    let sizeBytes: Int
    let sha256: String

    var sizeKilobytes: Double {
        Double(sizeBytes) / 1024.0
    }

    static func compute(url: URL, schema: String) throws -> CsvQuickStats {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        var newlineCount = 0
        var lastByte: UInt8 = 0
        var sawBytes = false

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

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let sizeBytes = (attributes[.size] as? NSNumber)?.intValue ?? 0

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
}
#endif
