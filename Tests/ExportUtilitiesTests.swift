import CryptoKit
import Foundation

@main
struct ExportUtilitiesTests {
    static func main() throws {
        try testCsvQuickStatsCountsRows()
        try testExportPrunerRemovesOldSnapshots()
        try testCsvQuickStatsWritesMetadata()
        print("ExportUtilitiesTests passed")
    }

    static func testCsvQuickStatsCountsRows() throws {
        let tempDir = try temporaryDirectory()
        let fileURL = tempDir.appendingPathComponent("all_time.csv")
        let contents = """
        session_id,date,time
        A,2025-10-30,10:00:00
        B,2025-10-30,10:00:01
        C,2025-10-30,10:00:02
        """
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)

        let stats = try CsvQuickStats.compute(url: fileURL, schema: "v0.3")
        guard stats.rows == 3 else {
            throw Failure("Expected 3 data rows, found \(stats.rows)")
        }

        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        guard stats.sha256 == hex else {
            throw Failure("SHA mismatch.\nExpected: \(hex)\nActual:   \(stats.sha256)")
        }
    }

    static func testCsvQuickStatsWritesMetadata() throws {
        let tempDir = try temporaryDirectory()
        let fileURL = tempDir.appendingPathComponent("sample.csv")
        let contents = """
        session_id,date,time
        X,2025-10-30,10:00:00
        Y,2025-10-30,10:00:01
        """
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)

        let stats = try CsvQuickStats.compute(url: fileURL, schema: "v0.3")
        let metaURL = tempDir.appendingPathComponent("sample.csv.meta.json")
        try stats.writeJSON(to: metaURL)
        let metaData = try Data(contentsOf: metaURL)
        guard let json = try JSONSerialization.jsonObject(with: metaData) as? [String: Any] else {
            throw Failure("Metadata is not a JSON dictionary")
        }
        guard (json["schema"] as? String) == "v0.3" else {
            throw Failure("Metadata schema missing or incorrect: \(String(describing: json["schema"]))")
        }
        guard (json["rows"] as? Int) == 2 else {
            throw Failure("Metadata rows expected 2, found \(String(describing: json["rows"]))")
        }
    }

    static func testExportPrunerRemovesOldSnapshots() throws {
        let tempDir = try temporaryDirectory()
        let fileManager = FileManager.default
        let snapshots = [
            "AllTime-2025-10-28T10-00-00-000-v0.3.csv",
            "AllTime-2025-10-29T10-00-00-000-v0.3.csv",
            "AllTime-2025-10-30T10-00-00-000-v0.3.csv",
            "AllTime-2025-10-31T10-00-00-000-v0.3.csv"
        ]
        for name in snapshots {
            let url = tempDir.appendingPathComponent(name)
            try "header\nrow".write(to: url, atomically: true, encoding: .utf8)
            let metaURL = url.appendingPathExtension("meta.json")
            try "{}".write(to: metaURL, atomically: true, encoding: .utf8)
        }

        let pruner = ExportPruner(directory: tempDir, keepLast: 2, fileManager: fileManager)
        pruner.prune()

        let remaining = try fileManager.contentsOfDirectory(atPath: tempDir.path)
        let expected = [
            "AllTime-2025-10-30T10-00-00-000-v0.3.csv",
            "AllTime-2025-10-31T10-00-00-000-v0.3.csv",
            "AllTime-2025-10-30T10-00-00-000-v0.3.csv.meta.json",
            "AllTime-2025-10-31T10-00-00-000-v0.3.csv.meta.json"
        ].sorted()
        guard remaining.sorted() == expected else {
            throw Failure("Pruner kept unexpected files: \(remaining)")
        }
    }

    static func temporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    struct Failure: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }
}
