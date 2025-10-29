import Foundation

@main
struct IndexServiceTests {
    static func main() async throws {
        try testLatestWeightHappyPath()
        try testLatestWeightIgnoresIncompleteRows()
        try testLatestWeightNilWhenNoData()
        try await testSessionViewModelPrefill()
        try testRecentExercisesFiltering()
        print("IndexServiceTests passed")
    }

    static func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IndexServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func makeRow(exCode: String, date: String, time: String, weight: String, unit: String, reps: String) -> String {
        [
            "session-\(UUID().uuidString.prefix(8))",
            date,
            time,
            "Plan",
            "Day",
            "1",
            "",
            exCode,
            "0",
            "1",
            reps,
            "",
            weight,
            unit,
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

    static func makeService(withRows rows: [String]) throws -> (IndexService, URL, URL) {
        let directory = try makeTempDirectory()
        let csvURL = directory.appendingPathComponent("all_time.csv")
        let indexURL = directory.appendingPathComponent("index_last_by_ex.json")

        let header = "session_id,date,time,plan_name,day_label,segment_id,superset_id,ex_code,adlib,set_num,reps,time_sec,weight,unit,is_warmup,rpe,rir,tempo,rest_sec,effort_1to5,tags,notes,pr_types"
        let payload = ([header] + rows).joined(separator: "\n")
        try payload.write(to: csvURL, atomically: true, encoding: .utf8)

        let service = IndexService(fileManager: .default, indexURL: indexURL, csvURL: csvURL)
        return (service, csvURL, indexURL)
    }

    static func testLatestWeightHappyPath() throws {
        let rows = [
            makeRow(exCode: "BENCH.PRESS.BB", date: "2025-10-25", time: "18:12:00", weight: "200", unit: "lb", reps: "5"),
            makeRow(exCode: "BENCH.PRESS.BB", date: "2025-10-27", time: "18:35:09", weight: "205", unit: "lb", reps: "5")
        ]
        let (service, _, indexURL) = try makeService(withRows: rows)

        guard let latest = service.latestWeight(exCode: "BENCH.PRESS.BB") else {
            throw TestFailure("Expected non-nil LatestWeight")
        }
        assert(abs(latest.weight - 205.0) < 0.001)
        assert(latest.unit == "lb")
        assert(latest.reps == 5)

        // Index should have been materialised to disk.
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw TestFailure("Expected index file to exist after rebuild")
        }
    }

    static func testLatestWeightIgnoresIncompleteRows() throws {
        let rows = [
            makeRow(exCode: "ROW.CABLE", date: "2025-10-27", time: "18:12:00", weight: "", unit: "lb", reps: "12"),
            makeRow(exCode: "ROW.CABLE", date: "2025-10-20", time: "18:12:00", weight: "180", unit: "lb", reps: "10")
        ]
        let (service, _, _) = try makeService(withRows: rows)
        guard let latest = service.latestWeight(exCode: "ROW.CABLE") else {
            throw TestFailure("Expected fallback to second entry")
        }
        assert(abs(latest.weight - 180.0) < 0.001)
    }

    static func testLatestWeightNilWhenNoData() throws {
        let rows = [
            makeRow(exCode: "SQUAT", date: "2025-10-20", time: "18:12:00", weight: "", unit: "lb", reps: "")
        ]
        let (service, _, _) = try makeService(withRows: rows)
        guard service.latestWeight(exCode: "DEADLIFT") == nil else {
            throw TestFailure("Expected nil for missing exercise")
        }
        guard service.latestWeight(exCode: "SQUAT") == nil else {
            throw TestFailure("Expected nil for incomplete rows")
        }
    }

    static func testSessionViewModelPrefill() async throws {
        let rows = [
            makeRow(exCode: "BENCH.PRESS.BB", date: "2025-10-27", time: "18:35:09", weight: "205", unit: "lb", reps: "5")
        ]
        let (service, _, _) = try makeService(withRows: rows)
        let initialSet = SessionSet(
            exerciseName: "Bench Press",
            exCode: "BENCH.PRESS.BB",
            weight: nil,
            unit: "lb",
            reps: nil
        )
        let viewModel = await MainActor.run {
            SessionViewModel(currentSet: initialSet, indexService: service)
        }
        await MainActor.run {
            viewModel.prefillWeight()
        }
        let snapshot = await MainActor.run {
            (viewModel.currentSet, viewModel.previousEntries, viewModel.latestWeightLabel)
        }
        guard let weight = snapshot.0.weight, abs(weight - 205.0) < 0.001 else {
            throw TestFailure("ViewModel did not prefill weight")
        }
        guard let reps = snapshot.0.reps, reps == 5 else {
            throw TestFailure("ViewModel did not prefill reps")
        }
        guard !snapshot.1.isEmpty else {
            throw TestFailure("ViewModel previous entries should not be empty")
        }
        guard let label = snapshot.2, label.contains("205") else {
            throw TestFailure("Latest weight label missing or incorrect")
        }
    }

    static func testRecentExercisesFiltering() throws {
        let rows = [
            makeRow(exCode: "PRESS.DB.FLAT", date: "2025-10-27", time: "18:35:09", weight: "205", unit: "lb", reps: "5"),
            makeRow(exCode: "PRESS.DB.INCL", date: "2025-10-10", time: "08:11:00", weight: "60", unit: "lb", reps: "10"),
            makeRow(exCode: "ROW.CABLE", date: "2025-10-01", time: "12:00:00", weight: "150", unit: "lb", reps: "12")
        ]
        let (service, _, _) = try makeService(withRows: rows)
        let recents = service.recentExercises(inLast: 14, limit: 10)
        guard recents.count == 1 else {
            throw TestFailure("Expected only recent entries within 14 days")
        }
        guard recents.first?.exerciseCode == "PRESS.DB.FLAT" else {
            throw TestFailure("Unexpected recent exercise code")
        }
    }

    struct TestFailure: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }
}
