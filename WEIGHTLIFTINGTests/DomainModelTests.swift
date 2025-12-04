import XCTest
@testable import WEIGHTLIFTING

@MainActor
final class DomainModelTests: XCTestCase {

    func testTimeRangeMappings() {
        XCTAssertEqual(TimeRange.fourWeeks.days, 28)
        XCTAssertEqual(TimeRange.threeMonths.days, 90)
        XCTAssertEqual(TimeRange.sixMonths.days, 180)
        XCTAssertEqual(TimeRange.oneYear.days, 365)
        XCTAssertNil(TimeRange.allTime.days)

        XCTAssertEqual(TimeRange.fourWeeks.displayName, "4 Weeks")
        XCTAssertEqual(TimeRange.oneYear.displayName, "1 Year")
        XCTAssertEqual(TimeRange.allTime.displayName, "All Time")
    }

    func testSetRecordTonnageAndEstimated1RM() {
        let record = SetRecord(
            sessionID: "SID",
            segmentID: 1,
            supersetID: nil,
            exerciseCode: "PRESS.DB.FLAT",
            setNumber: 1,
            reps: "10",
            weight: 100,
            unit: .pounds,
            isWarmup: false,
            effort: 3,
            isAdlib: false
        )

        XCTAssertEqual(record.tonnage, 1000)
        XCTAssertEqual(record.estimated1RM ?? 0, 133.33333333333334, accuracy: 0.0001)

        let bodyweightRecord = SetRecord(
            sessionID: "SID",
            segmentID: 1,
            supersetID: nil,
            exerciseCode: "PU",
            setNumber: 1,
            reps: "BW",
            weight: nil,
            unit: .pounds,
            isWarmup: false,
            effort: 3,
            isAdlib: false
        )

        XCTAssertNil(bodyweightRecord.tonnage)
        XCTAssertNil(bodyweightRecord.estimated1RM)
    }

    func testExerciseFormatting() {
        XCTAssertEqual(Exercise.formatExerciseCode("PRESS_DB_FLAT"), "Press Db Flat")
        XCTAssertEqual(Exercise.formatExerciseCode("row-cable"), "Row Cable")

        let exercise = Exercise(code: "PRESS.DB.FLAT", displayName: nil, unit: .pounds, altGroup: "A")
        XCTAssertEqual(exercise.displayName, "Press.db.flat")
        XCTAssertEqual(exercise.unit, .pounds)
        XCTAssertEqual(exercise.altGroup, "A")
    }

    func testRepetitionRangeDisplayText() throws {
        XCTAssertEqual(PlanV03.RepetitionRange(min: 8, max: 8, text: nil).displayText, "8")
        XCTAssertEqual(PlanV03.RepetitionRange(min: 8, max: 12, text: nil).displayText, "8-12")
        XCTAssertEqual(PlanV03.RepetitionRange(min: 10, max: nil, text: nil).displayText, "10+")
        XCTAssertEqual(PlanV03.RepetitionRange(min: nil, max: 12, text: nil).displayText, "≤12")
        XCTAssertEqual(PlanV03.RepetitionRange(min: nil, max: nil, text: "10-12").displayText, "10-12")
    }

    func testWeightUnitParsingFromCSV() {
        XCTAssertEqual(WeightUnit.fromCSV("lb"), .pounds)
        XCTAssertEqual(WeightUnit.fromCSV("kg"), .kilograms)
        XCTAssertNil(WeightUnit.fromCSV("stone"))
    }

    func testLatestWeightDisplayHelpers() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: "2025-10-10")!
        let weight = LatestWeight(weight: 185, unit: "lb", reps: 5, date: date)

        XCTAssertEqual(LatestWeight.displayDateFormatter.string(from: date), "2025-10-10")
        XCTAssertEqual(weight.displayString, "Prev: 185 lb × 5 (2025-10-10)")
        let formattedInt = await MainActor.run { SessionViewModel.format(weight: 200) }
        let formattedDecimal = await MainActor.run { SessionViewModel.format(weight: 200.5) }
        XCTAssertEqual(formattedInt, "200")
        XCTAssertEqual(formattedDecimal, "200.5")
    }
}
