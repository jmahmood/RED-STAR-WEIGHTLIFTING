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

    func testCSVIndexBuilderReturnsLastTwoPerExercise() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("all_time.csv")
        let contents = """
        session_id,date,time,ex_code,weight,unit,reps
        A,2025-10-30,10:00:00,EX.A,100,lb,5
        B,2025-10-31,10:00:00,EX.A,120,lb,3
        C,2025-11-01,10:00:00,EX.A,110,lb,8
        D,2025-10-30,10:00:00,EX.B,200,lb,2
        """
        try contents.write(to: url, atomically: true, encoding: .utf8)

        let index = try CSVIndexBuilder.buildLastTwoByExercise(from: url)
        let rowsA = try XCTUnwrap(index["EX.A"])
        XCTAssertEqual(rowsA.count, 2)
        XCTAssertEqual(rowsA[0].weight, 110)
        XCTAssertEqual(rowsA[0].reps, 8)
        XCTAssertEqual(rowsA[1].weight, 120)

        let rowsB = try XCTUnwrap(index["EX.B"])
        XCTAssertEqual(rowsB.count, 1)
        XCTAssertEqual(rowsB[0].weight, 200)
    }
}

private extension ExportAndCSVTests {
    func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
