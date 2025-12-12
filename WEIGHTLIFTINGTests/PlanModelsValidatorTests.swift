import XCTest
@testable import WEIGHTLIFTING

@MainActor
final class PlanModelsValidatorTests: XCTestCase {
    func testValidatorProducesSummaryAndWarnings() throws {
        let json = """
        {
          "name": "Strength",
          "unit": "kg",
          "dictionary": {"SQ": "Squat"},
          "alt_groups": {},
          "schedule": [
            { "label": "Day 1", "segments": [ { "type": "straight", "ex": "SQ", "sets": 3, "reps": 5 } ] },
            { "label": "Day 2", "segments": [ { "type": "unsupported_type", "ex": "SQ", "sets": 1 } ] }
          ]
        }
        """
        let data = Data(json.utf8)
        let result = try PlanValidator.validate(data: data)

        XCTAssertEqual(result.summary.planName, "Strength")
        XCTAssertEqual(result.summary.unit, .kilograms)
        XCTAssertEqual(result.summary.dayCount, 2)
        XCTAssertEqual(result.summary.scheduleOrder, ["Day 1", "Day 2"])
        XCTAssertTrue(result.summary.unsupportedSegmentTypes.contains("unsupported_type"))
        XCTAssertFalse(result.summary.sha256.isEmpty)
        XCTAssertFalse(result.summary.warnings.isEmpty)
    }

    func testRepetitionRangeDecodesSingleValue() throws {
        let json = """
        { "label": "Day", "segments": [ { "type": "straight", "ex": "SQ", "sets": 3, "reps": 8 } ] }
        """
        let data = Data(json.utf8)
        let day = try JSONDecoder().decode(PlanV03.Day.self, from: data)
        guard case let .straight(segment) = day.segments.first else {
            return XCTFail("Expected straight segment")
        }
        XCTAssertEqual(segment.reps?.displayText, "8")
    }

    func testIntensifierDecodesUnknownKindAsUnknown() throws {
        let json = """
        { "type": "straight", "ex": "SQ", "sets": 3, "reps": 5, "intensifier": { "kind": "something" } }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let segment = try decoder.decode(PlanV03.Segment.self, from: data)
        guard case let .straight(straight) = segment, let intensifier = straight.intensifier else {
            return XCTFail("Expected intensifier")
        }
        XCTAssertEqual(intensifier.kind, .unknown)
    }
}
