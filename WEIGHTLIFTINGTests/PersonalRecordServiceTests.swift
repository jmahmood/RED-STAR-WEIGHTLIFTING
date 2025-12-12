import XCTest
@testable import WEIGHTLIFTING

@MainActor
final class PersonalRecordServiceTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeCSV(_ contents: String, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("all_time.csv")
        let data = contents.data(using: .utf8)!
        try data.write(to: url)
        return url
    }

    func testMissingCSVThrows() throws {
        let tempDir = try makeTempDirectory()
        let service = PersonalRecordService(globalDirectory: tempDir)

        do {
            _ = try service.summary()
            XCTFail("Expected summary() to throw when CSV is missing")
        } catch let error as InsightsError {
            XCTAssertEqual(error, .csvMissing)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidHeaderThrows() throws {
        let tempDir = try makeTempDirectory()
        _ = try writeCSV("date,time,wrong,columns\n", to: tempDir)

        let service = PersonalRecordService(globalDirectory: tempDir)
        XCTAssertThrowsError(try service.summary()) { error in
            XCTAssertEqual(error as? InsightsError, .invalidCSV)
        }
    }

    func testValidCSVParsesMetrics() throws {
        let tempDir = try makeTempDirectory()
        let csv = """
        date,time,ex_code,reps,weight,unit,is_warmup,day_label
        2024-01-01,10:00:00,SQ.SSB,5,100,lb,0,Day 1
        2024-01-02,10:00:00,SQ.SSB,3,110,lb,0,Day 2
        2024-01-02,10:05:00,SQ.SSB,5,45,lb,1,Day 2 Warmup
        """
        _ = try writeCSV(csv, to: tempDir)

        let service = PersonalRecordService(globalDirectory: tempDir)
        let summary = try service.summary()

        XCTAssertEqual(summary.rowCount, 3, "Row count should include warmups even if ignored later")
        XCTAssertEqual(summary.entries.count, 1)

        let entry = try XCTUnwrap(summary.entries.first)
        XCTAssertEqual(entry.exerciseCode, "SQ.SSB")
        XCTAssertEqual(entry.unit, "lb")
        XCTAssertEqual(entry.volume?.value, 500) // 100 * 5 beats 110 * 3
        XCTAssertEqual(entry.load?.weight, 110)
        XCTAssertEqual(entry.load?.reps, 3)
        XCTAssertEqual(summary.latestDayLabel, "Day 2")
        XCTAssertNotNil(summary.sha256)
    }
}
