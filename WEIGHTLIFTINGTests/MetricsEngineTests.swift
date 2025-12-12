import XCTest
@testable import WEIGHTLIFTING

final class MetricsEngineTests: XCTestCase {
    func testComputeMetricsAggregatesExercisesAndGlobal() throws {
        let adapter = try makeAdapter(rows: [
            makeRow(sessionID: "S1", date: daysAgo(2), exCode: "BENCH", weight: 100, reps: "5"),
            makeRow(sessionID: "S1", date: daysAgo(2), exCode: "SQUAT", weight: 200, reps: "5"),
            makeRow(sessionID: "S2", date: daysAgo(1), exCode: "BENCH", weight: 110, reps: "5")
        ])
        let universe = try makeUniverse()
        let engine = MetricsEngine(adapter: adapter, exerciseUniverse: universe)

        let summary = try engine.computeMetrics(for: .allTime)

        XCTAssertEqual(summary.globalMetrics.totalSessions, 2)
        XCTAssertEqual(summary.globalMetrics.totalSets, 3)
        XCTAssertEqual(summary.globalMetrics.totalWorkingSets, 3)
        XCTAssertEqual(summary.globalMetrics.totalVolume, 2050, accuracy: 0.001)
        XCTAssertEqual(summary.globalMetrics.averageVolumePerSession, 1025, accuracy: 0.001)
        XCTAssertEqual(summary.globalMetrics.sessionsPerWeek, 2, accuracy: 0.001)

        let bench = try XCTUnwrap(summary.exerciseMetrics["BENCH"])
        XCTAssertEqual(bench.totalVolume, 1050, accuracy: 0.001)
        XCTAssertEqual(bench.sessionCount, 2)
        XCTAssertEqual(bench.volumePerSession.count, 2)
        XCTAssertEqual(bench.frequencyPerWeek, 2, accuracy: 0.001)
        XCTAssertEqual(bench.best1RM?.value ?? 0, 128.3333, accuracy: 0.001)

        let top = try XCTUnwrap(summary.topExercises.first)
        XCTAssertEqual(top.exerciseCode, "BENCH")
    }

    func testVolumeAndFrequencyChanges() throws {
        let adapter = try makeAdapter(rows: [
            makeRow(sessionID: "RECENT", date: daysAgo(7), exCode: "BENCH", weight: 100, reps: "5"),
            makeRow(sessionID: "PREV", date: daysAgo(40), exCode: "BENCH", weight: 80, reps: "5")
        ])
        let universe = try makeUniverse()
        let engine = MetricsEngine(adapter: adapter, exerciseUniverse: universe)

        let volumeChange = try engine.volumeChange(for: .fourWeeks)
        XCTAssertEqual(volumeChange ?? 0, 25, accuracy: 0.001)

        let frequencyChange = try engine.sessionsPerWeekChange(for: .fourWeeks)
        XCTAssertEqual(frequencyChange ?? 0, 0, accuracy: 0.001)
    }

    func testStrengthChangeForTopExercises() throws {
        let adapter = try makeAdapter(rows: [
            makeRow(sessionID: "RECENT", date: daysAgo(3), exCode: "BENCH", weight: 100, reps: "5"),
            makeRow(sessionID: "PREV", date: daysAgo(50), exCode: "BENCH", weight: 80, reps: "5"),
            makeRow(sessionID: "RECENT2", date: daysAgo(2), exCode: "SQUAT", weight: 200, reps: "5")
        ])
        let universe = try makeUniverse()
        let engine = MetricsEngine(adapter: adapter, exerciseUniverse: universe)

        let change = try engine.strengthChange(for: .fourWeeks)
        XCTAssertEqual(change ?? 0, 25, accuracy: 0.01)
    }
}

private extension MetricsEngineTests {
    func makeAdapter(rows: [String]) throws -> WorkoutSessionAdapter {
        let directory = try temporaryDirectory()
        let csvURL = directory.appendingPathComponent("all_time.csv")
        let header = "session_id,date,time,plan_name,day_label,segment_id,superset_id,ex_code,adlib,set_num,reps,time_sec,weight,unit,is_warmup,rpe,rir,tempo,rest_sec,effort_1to5,tags,notes,pr_types"
        let payload = ([header] + rows).joined(separator: "\n")
        try payload.write(to: csvURL, atomically: true, encoding: .utf8)
        return WorkoutSessionAdapter(csvURL: csvURL)
    }

    func makeUniverse() throws -> ExerciseUniverse {
        let directory = try temporaryDirectory()
        let csvURL = directory.appendingPathComponent("empty.csv")
        try "".write(to: csvURL, atomically: true, encoding: .utf8)
        let planURL = directory.appendingPathComponent("plan.json")
        try "{\"name\":\"Plan\",\"unit\":\"lb\",\"dictionary\":{},\"schedule\":[]}".write(to: planURL, atomically: true, encoding: .utf8)
        return ExerciseUniverse(csvURL: csvURL, activePlanURL: planURL)
    }

    func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func makeRow(sessionID: String, date: Date, exCode: String, weight: Double, reps: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = Calendar(identifier: .gregorian)
        timeFormatter.dateFormat = "HH:mm:ss"

        return [
            sessionID,
            dateFormatter.string(from: date),
            timeFormatter.string(from: date),
            "Plan",
            "Day",
            "1",
            "",
            exCode,
            "0",
            "1",
            reps,
            "",
            String(weight),
            "lb",
            "0",
            "",
            "",
            "",
            "",
            "3",
            "",
            "",
            ""
        ].joined(separator: ",")
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}
