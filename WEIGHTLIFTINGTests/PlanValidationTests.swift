
import XCTest
@testable import WEIGHTLIFTING

final class PlanValidationTests: XCTestCase {
    func testInvalidPlanFailsValidation() throws {
        let invalidJSON = """
        { "name": "Broken Plan", "unit": "lb", "dictionary": {} }
        """
        guard let data = invalidJSON.data(using: .utf8) else {
            XCTFail("Could not build invalid JSON data")
            return
        }

        do {
            _ = try PlanValidator.validate(data: data)
            XCTFail("Expected validation to throw for malformed plan")
        } catch PlanValidationError.decodingFailed, PlanValidationError.missingDays {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - V0.4 Validation Tests

    func testValidatePerWeekWithNonNumericKeys() throws {
        let planJSON = """
        {
          "name": "Test Plan",
          "unit": "lb",
          "dictionary": { "SQUAT.BB": "Back Squat" },
          "groups": {},
          "schedule": [{
            "label": "Day A",
            "segments": [{
              "type": "straight",
              "ex": "SQUAT.BB",
              "sets": 3,
              "reps": 5,
              "rest_sec": 120,
              "per_week": {
                "week_one": { "sets": 5 }
              }
            }]
          }]
        }
        """

        guard let data = planJSON.data(using: .utf8) else {
            XCTFail("Could not build JSON data")
            return
        }

        let result = try PlanValidator.validate(data: data)
        XCTAssertTrue(result.summary.warnings.contains { $0.contains("per_week key 'week_one'") && $0.contains("not numeric") },
                      "Should warn about non-numeric per_week key")
    }

    func testValidatePerWeekWithNumericKeys() throws {
        let planJSON = """
        {
          "name": "Test Plan",
          "unit": "lb",
          "dictionary": { "SQUAT.BB": "Back Squat" },
          "groups": {},
          "schedule": [{
            "label": "Day A",
            "segments": [{
              "type": "straight",
              "ex": "SQUAT.BB",
              "sets": 3,
              "reps": 5,
              "rest_sec": 120,
              "per_week": {
                "1": { "sets": 3 },
                "2": { "sets": 4 },
                "3": { "sets": 5 }
              }
            }]
          }]
        }
        """

        guard let data = planJSON.data(using: .utf8) else {
            XCTFail("Could not build JSON data")
            return
        }

        let result = try PlanValidator.validate(data: data)
        let hasPerWeekWarnings = result.summary.warnings.contains { $0.contains("per_week") && $0.contains("not numeric") }
        XCTAssertFalse(hasPerWeekWarnings, "Should not warn about numeric per_week keys")
    }

    func testValidateGroupVariantsWithUnknownGroup() throws {
        let planJSON = """
        {
          "name": "Test Plan",
          "unit": "lb",
          "dictionary": { "SQUAT.BB": "Back Squat" },
          "groups": { "legs": ["SQUAT.BB"] },
          "group_variants": {
            "chest": {
              "heavy": {
                "BENCH.BB": { "sets": 5 }
              }
            }
          },
          "schedule": [{
            "label": "Day A",
            "segments": [{
              "type": "straight",
              "ex": "SQUAT.BB",
              "sets": 3,
              "reps": 5
            }]
          }]
        }
        """

        guard let data = planJSON.data(using: .utf8) else {
            XCTFail("Could not build JSON data")
            return
        }

        let result = try PlanValidator.validate(data: data)
        XCTAssertTrue(result.summary.warnings.contains { $0.contains("group_variants references unknown group 'chest'") },
                      "Should warn about unknown group in group_variants")
    }

    func testValidateLoadAxisTargetWithoutExerciseMeta() throws {
        let planJSON = """
        {
          "name": "Test Plan",
          "unit": "lb",
          "dictionary": { "PRESS.LEG": "Leg Press" },
          "groups": {},
          "schedule": [{
            "label": "Day A",
            "segments": [{
              "type": "straight",
              "ex": "PRESS.LEG",
              "sets": 3,
              "reps": 10,
              "load_axis_target": {
                "axis": "pin_hole",
                "target": "5"
              }
            }]
          }]
        }
        """

        guard let data = planJSON.data(using: .utf8) else {
            XCTFail("Could not build JSON data")
            return
        }

        let result = try PlanValidator.validate(data: data)
        XCTAssertTrue(result.summary.warnings.contains { $0.contains("PRESS.LEG") && $0.contains("no exercise_meta defined") },
                      "Should warn about missing exercise_meta for load_axis_target")
    }

    func testValidateLoadAxisTargetWithUnknownAxis() throws {
        let planJSON = """
        {
          "name": "Test Plan",
          "unit": "lb",
          "dictionary": { "PRESS.LEG": "Leg Press" },
          "groups": {},
          "exercise_meta": {
            "PRESS.LEG": {
              "load_axes": {
                "pin_hole": {
                  "kind": "ordinal",
                  "values": ["1", "2", "3"]
                }
              }
            }
          },
          "schedule": [{
            "label": "Day A",
            "segments": [{
              "type": "straight",
              "ex": "PRESS.LEG",
              "sets": 3,
              "reps": 10,
              "load_axis_target": {
                "axis": "band_color",
                "target": "red"
              }
            }]
          }]
        }
        """

        guard let data = planJSON.data(using: .utf8) else {
            XCTFail("Could not build JSON data")
            return
        }

        let result = try PlanValidator.validate(data: data)
        XCTAssertTrue(result.summary.warnings.contains { $0.contains("PRESS.LEG") && $0.contains("unknown axis 'band_color'") },
                      "Should warn about unknown axis in load_axis_target")
    }

    func testValidV04PlanPassesValidation() throws {
        let planJSON = """
        {
          "name": "5-3-1 Test",
          "unit": "lb",
          "dictionary": { "SQUAT.BB": "Back Squat", "PRESS.LEG": "Leg Press" },
          "groups": { "legs": ["SQUAT.BB", "PRESS.LEG"] },
          "phase": {
            "index": 1,
            "weeks": [1, 2, 3]
          },
          "exercise_meta": {
            "PRESS.LEG": {
              "load_axes": {
                "pin_hole": {
                  "kind": "ordinal",
                  "values": ["1", "2", "3", "4", "5"]
                }
              }
            }
          },
          "group_variants": {
            "legs": {
              "heavy": {
                "SQUAT.BB": { "sets": 5, "reps": { "min": 3, "max": 5 } }
              }
            }
          },
          "schedule": [{
            "label": "Day A",
            "segments": [{
              "type": "straight",
              "ex": "SQUAT.BB",
              "alt_group": "legs",
              "group_role": "heavy",
              "sets": 3,
              "reps": 5,
              "per_week": {
                "1": { "sets": 3 },
                "2": { "sets": 4 },
                "3": { "sets": 5 }
              }
            }, {
              "type": "straight",
              "ex": "PRESS.LEG",
              "sets": 3,
              "reps": 10,
              "load_axis_target": {
                "axis": "pin_hole",
                "target": "3"
              }
            }]
          }]
        }
        """

        guard let data = planJSON.data(using: .utf8) else {
            XCTFail("Could not build JSON data")
            return
        }

        let result = try PlanValidator.validate(data: data)

        // Should have no warnings
        let v04Warnings = result.summary.warnings.filter { warning in
            warning.contains("per_week") || warning.contains("group_variants") || warning.contains("load_axis")
        }
        XCTAssertTrue(v04Warnings.isEmpty, "Valid V0.4 plan should have no V0.4 warnings. Got: \(v04Warnings)")
    }
}
