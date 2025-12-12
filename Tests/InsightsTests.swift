import Foundation

@main
struct InsightsTests {
    static func main() throws {
        try testPersonalRecordStreaming()
        try testNextWorkoutBuilder()
        try testPlanValidationFailure()
        print("InsightsTests passed")
    }

    static func testPersonalRecordStreaming() throws {
        let tempDir = try makeTempDirectory()
        let csvURL = tempDir.appendingPathComponent("all_time.csv")
        let header = CsvRow.header
        let rows = [
            makeRow(date: "2025-10-01", time: "08:00:00", code: "BP.DB.FLAT", weight: "180", reps: "8", unit: "lb", day: "Upper A"),
            makeRow(date: "2025-10-05", time: "09:00:00", code: "BP.DB.FLAT", weight: "200", reps: "5", unit: "lb", day: "Upper B"),
            // tie on load but later timestamp should win
            makeRow(date: "2025-10-06", time: "09:30:00", code: "BP.DB.FLAT", weight: "200", reps: "5", unit: "lb", day: "Upper B"),
            // warmup row should be ignored
            makeRow(date: "2025-10-07", time: "07:00:00", code: "BP.DB.FLAT", weight: "50", reps: "10", unit: "lb", day: "Upper C", isWarmup: "1"),
            // bodyweight volume with negative (assisted) load
            makeRow(date: "2025-10-10", time: "06:15:00", code: "PU.RING", weight: "-30", reps: "8", unit: "bw", day: "Upper C"),
            // invalid weight row
            makeRow(date: "2025-10-11", time: "06:45:00", code: "ROW.CABLE", weight: "", reps: "12", unit: "lb", day: "Upper C")
        ]
        let payload = ([header] + rows).joined(separator: "\n")
        try payload.write(to: csvURL, atomically: true, encoding: .utf8)

        let service = PersonalRecordService(globalDirectory: tempDir)
        let summary = try service.summary()

        guard let bench = summary.entries.first(where: { $0.exerciseCode == "BP.DB.FLAT" && $0.unit == "lb" }) else {
            throw Failure("Missing bench press entry")
        }
        guard let epley = bench.epley else {
            throw Failure("Expected 1RM metric")
        }
        guard abs(epley.value - 233.33) < 0.1 else {
            throw Failure("Unexpected epley value \(epley.value)")
        }
        guard summary.latestDayLabel == "Upper C" else {
            throw Failure("Latest day label mismatch \(String(describing: summary.latestDayLabel))")
        }

        guard let pullUp = summary.entries.first(where: { $0.exerciseCode == "PU.RING" && $0.unit == "bw" }) else {
            throw Failure("Missing pull-up entry")
        }
        guard let volume = pullUp.volume, abs(volume.value - 240.0) < 0.1 else {
            throw Failure("Volume calculation incorrect \(String(describing: pullUp.volume))")
        }
    }

    static func testNextWorkoutBuilder() throws {
        let plan = makePlan()
        let builder = NextWorkoutBuilder()
        let display = try builder.makeNextWorkout(plan: plan, currentDayLabel: "Day A")
        guard display.dayLabel == "Day B" else {
            throw Failure("Next day mismatch \(display.dayLabel)")
        }
        guard display.lines.count == 3 else {
            throw Failure("Expected three exercises, found \(display.lines.count)")
        }
        guard display.timedSetsSkipped else {
            throw Failure("Timed set skip flag not set")
        }
        guard display.lines.first?.badges.contains("dropset") == true else {
            throw Failure("Dropset badge missing \(String(describing: display.lines.first?.badges))")
        }
        guard display.lines[1].badges.contains("zero-rest") else {
            throw Failure("Zero-rest badge missing for superset item")
        }
        guard display.remainingCount == 0 else {
            throw Failure("Unexpected remaining count \(display.remainingCount)")
        }
    }

    static func testPlanValidationFailure() throws {
        let invalidJSON = """
        { "name": "Broken Plan", "unit": "lb", "dictionary": {} }
        """
        guard let data = invalidJSON.data(using: .utf8) else {
            throw Failure("Unable to build invalid plan data")
        }

        do {
            _ = try PlanValidator.validate(data: data)
            throw Failure("Expected validation to fail for malformed plan")
        } catch PlanValidationError.decodingFailed {
            // expected
        } catch {
            throw Failure("Unexpected error type: \(error)")
        }
    }

    static func makePlan() -> PlanV03 {
        let timed = PlanV03.Segment.straight(
            .init(
                exerciseCode: "EX.TIMED",
                altGroup: nil,
                sets: 2,
                reps: PlanV03.RepetitionRange(min: 10, max: 10, text: nil),
                restSec: 60,
                rpe: nil,
                intensifier: nil,
                timeSec: 30,
                tags: nil
            )
        )

        let scheme = PlanV03.Segment.scheme(
            .init(
                exerciseCode: "EX.SCHEME",
                altGroup: nil,
                entries: [
                    .init(label: nil, sets: 2, reps: PlanV03.RepetitionRange(min: 8, max: 10, text: nil), restSec: 90, intensifier: .init(kind: .dropset, when: nil, dropPct: nil, steps: nil)),
                    .init(label: nil, sets: 1, reps: PlanV03.RepetitionRange(min: nil, max: nil, text: "12-15"), restSec: nil, intensifier: nil)
                ],
                restSec: 120,
                intensifier: nil
            )
        )

        let superset = PlanV03.Segment.superset(
            .init(
                label: "SS1",
                rounds: 2,
                items: [
                    .init(exerciseCode: "EX.SUP.A", altGroup: nil, sets: 1, reps: PlanV03.RepetitionRange(min: 12, max: 12, text: nil), restSec: 0, intensifier: nil),
                    .init(exerciseCode: "EX.SUP.B", altGroup: nil, sets: 1, reps: PlanV03.RepetitionRange(min: 15, max: 15, text: nil), restSec: nil, intensifier: nil)
                ],
                restSec: 45,
                restBetweenRoundsSec: 60
            )
        )

        let dayA = PlanV03.Day(label: "Day A", segments: [timed])
        let dayB = PlanV03.Day(label: "Day B", segments: [scheme, superset])

        return PlanV03(
            planName: "Test Plan",
            unit: .kilograms,
            exerciseNames: [
                "EX.TIMED": "Timed Move",
                "EX.SCHEME": "Incline Press",
                "EX.SUP.A": "Cable Row",
                "EX.SUP.B": "Lateral Raise"
            ],
            altGroups: [:],
            days: [dayA, dayB],
            scheduleOrder: ["Day A", "Day B"]
        )
    }

    static func makeRow(
        date: String,
        time: String,
        code: String,
        weight: String,
        reps: String,
        unit: String,
        day: String,
        isWarmup: String = "0"
    ) -> String {
        return [
            "session-\(UUID().uuidString)",
            date,
            time,
            "Plan",
            day,
            "1",
            "",
            code,
            "0",
            "1",
            reps,
            "",
            weight,
            unit,
            isWarmup,
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

    static func makeTempDirectory() throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("InsightsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    struct Failure: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }
}
