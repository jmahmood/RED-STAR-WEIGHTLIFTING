import XCTest
import CryptoKit
@testable import WEIGHTLIFTING

final class ExportAndCSVTests: XCTestCase {
    func testCsvQuickStatsComputesRowsAndHash() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("all_time.csv")
        let contents = """
        session_id,date,time
        A,2025-10-30,10:00:00
        B,2025-10-30,10:00:01
        C,2025-10-30,10:00:02
        """
        try contents.write(to: url, atomically: true, encoding: .utf8)

        let stats = try CsvQuickStats.compute(url: url, schema: "v0.3")
        XCTAssertEqual(stats.rows, 3)

        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        let expected = digest.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(stats.sha256, expected)
    }

    func testExportedSnapshotSizeLabel() {
        let url = URL(fileURLWithPath: "/tmp/sample.csv")
        let snapshot = ExportedSnapshot(fileURL: url, rows: 5, sizeBytes: 0, receivedAt: Date(), schema: "v0.3", sha256: nil)
        XCTAssertEqual(snapshot.fileName, "sample.csv")
        XCTAssertEqual(snapshot.sizeLabel, "0 KB")
    }
}

private extension ExportAndCSVTests {
    func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
