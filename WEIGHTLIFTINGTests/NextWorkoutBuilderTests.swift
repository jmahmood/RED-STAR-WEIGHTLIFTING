import XCTest
@testable import WEIGHTLIFTING

final class NextWorkoutBuilderTests: XCTestCase {
    func testNextWorkoutBuilderAdvancesSchedule() throws {
        let plan = makePlan()
        let builder = NextWorkoutBuilder()
        let display = try builder.makeNextWorkout(plan: plan, currentDayLabel: "Day A")

        XCTAssertEqual(display.dayLabel, "Day B")
        XCTAssertEqual(display.planName, "Test Plan")
        XCTAssertEqual(display.lines.count, 3)
        XCTAssertFalse(display.timedSetsSkipped) // Day B has no timed segments
        XCTAssertEqual(display.remainingCount, 0)

        let firstBadges = try XCTUnwrap(display.lines.first?.badges)
        XCTAssertTrue(firstBadges.contains("dropset"))
        XCTAssertTrue(display.lines[1].badges.contains("zero-rest"))
    }
}

private extension NextWorkoutBuilderTests {
    func makePlan() -> PlanV03 {
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
}
