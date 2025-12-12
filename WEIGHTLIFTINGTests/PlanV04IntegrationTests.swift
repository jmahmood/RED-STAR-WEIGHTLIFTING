//
//  PlanV04IntegrationTests.swift
//  WEIGHTLIFTINGTests
//
//  Created by Claude on 2025-12-10.
//  V0.4: Integration tests for complete V0.4 feature set
//

import XCTest
@testable import WEIGHTLIFTING

final class PlanV04IntegrationTests: XCTestCase {

    // MARK: - Backwards Compatibility Tests

    func testV03PlanStillWorks() throws {
        let v03PlanJSON = """
        {
          "name": "Reddit PPL",
          "unit": "lb",
          "dictionary": {
            "SQUAT.BB": "Back Squat",
            "BENCH.BB": "Bench Press"
          },
          "groups": {
            "legs": ["SQUAT.BB", "PRESS.LEG"]
          },
          "schedule": [{
            "label": "Push Day",
            "segments": [{
              "type": "straight",
              "ex": "BENCH.BB",
              "sets": 3,
              "reps": 8,
              "rest_sec": 120
            }]
          }]
        }
        """

        guard let data = v03PlanJSON.data(using: .utf8) else {
            XCTFail("Could not build V0.3 JSON data")
            return
        }

        // Should decode successfully
        let result = try PlanValidator.validate(data: data)

        XCTAssertEqual(result.plan.planName, "Reddit PPL")
        XCTAssertEqual(result.plan.days.count, 1)
        XCTAssertEqual(result.plan.exerciseMeta.count, 0, "V0.3 plans should have empty exerciseMeta")
        XCTAssertEqual(result.plan.groupVariants.count, 0, "V0.3 plans should have empty groupVariants")
    }

    // MARK: - Full V0.4 Plan Tests

    func testFullV04PlanDecoding() throws {
        let v04PlanJSON = """
        {
          "name": "Wendler 5-3-1 Template",
          "unit": "lb",
          "dictionary": {
            "SQUAT.BB": "Back Squat",
            "PRESS.LEG": "Leg Press Machine",
            "BENCH.BB": "Bench Press"
          },
          "groups": {
            "legs": ["SQUAT.BB", "PRESS.LEG"]
          },
          "phase": {
            "index": 1,
            "weeks": [1, 2, 3, 4]
          },
          "exercise_meta": {
            "PRESS.LEG": {
              "load_axes": {
                "pin_hole": {
                  "kind": "ordinal",
                  "values": ["1", "2", "3", "4", "5", "6", "7", "8"]
                }
              }
            }
          },
          "group_variants": {
            "legs": {
              "heavy": {
                "SQUAT.BB": { "sets": 3, "reps": { "min": 3, "max": 5 }, "rest_sec": 240 },
                "PRESS.LEG": { "sets": 4, "reps": { "min": 8, "max": 12 }, "rest_sec": 120 }
              }
            }
          },
          "schedule": [{
            "label": "Squat Day",
            "segments": [{
              "type": "percentage",
              "ex": "SQUAT.BB",
              "prescriptions": [
                { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.65 },
                { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.75 },
                { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.85, "intensifier": { "kind": "amrap", "when": "last_set" } }
              ],
              "per_week": {
                "2": {
                  "prescriptions": [
                    { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.70 },
                    { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.80 },
                    { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.90, "intensifier": { "kind": "amrap", "when": "last_set" } }
                  ]
                },
                "3": {
                  "prescriptions": [
                    { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.75 },
                    { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.85 },
                    { "sets": 1, "reps": { "min": 1, "max": 1 }, "pct_1rm": 0.95, "intensifier": { "kind": "amrap", "when": "last_set" } }
                  ]
                }
              }
            }, {
              "type": "straight",
              "ex": "PRESS.LEG",
              "alt_group": "legs",
              "group_role": "heavy",
              "sets": 3,
              "reps": { "min": 8, "max": 12 },
              "rest_sec": 120,
              "load_axis_target": { "axis": "pin_hole", "target": "5" }
            }]
          }]
        }
        """

        guard let data = v04PlanJSON.data(using: .utf8) else {
            XCTFail("Could not build V0.4 JSON data")
            return
        }

        let result = try PlanValidator.validate(data: data)

        // Verify plan decoding
        XCTAssertEqual(result.plan.planName, "Wendler 5-3-1 Template")
        XCTAssertEqual(result.plan.exerciseMeta.count, 1, "Should have exercise_meta for PRESS.LEG")
        XCTAssertNotNil(result.plan.phase, "Should have phase")
        XCTAssertEqual(result.plan.phase?.weeks, [1, 2, 3, 4], "Should have correct week array")

        // Verify group_variants
        XCTAssertEqual(result.plan.groupVariants.count, 1, "Should have group_variants")
        let legsVariants = result.plan.groupVariants["legs"]
        XCTAssertNotNil(legsVariants, "Should have legs group_variants")
        XCTAssertNotNil(legsVariants?["heavy"]?["SQUAT.BB"], "Should have heavy variant for SQUAT.BB")

        // Verify segments
        let day = result.plan.days[0]
        XCTAssertEqual(day.segments.count, 2, "Should have 2 segments")

        // Verify percentage segment
        if case .percentage(let percentage) = day.segments[0] {
            XCTAssertEqual(percentage.exerciseCode, "SQUAT.BB")
            XCTAssertEqual(percentage.prescriptions.count, 3, "Should have 3 base prescriptions")
            XCTAssertNotNil(percentage.perWeek, "Should have per_week overlay")
            XCTAssertEqual(percentage.perWeek?["2"]?.prescriptions?.count, 3, "Week 2 should have 3 prescriptions")
        } else {
            XCTFail("First segment should be percentage type")
        }

        // Verify straight segment with V0.4 fields
        if case .straight(let straight) = day.segments[1] {
            XCTAssertEqual(straight.exerciseCode, "PRESS.LEG")
            XCTAssertEqual(straight.altGroup, "legs")
            XCTAssertEqual(straight.groupRole, "heavy")
            XCTAssertNotNil(straight.loadAxisTarget, "Should have load_axis_target")
            XCTAssertEqual(straight.loadAxisTarget?.axis, "pin_hole")
            XCTAssertEqual(straight.loadAxisTarget?.target, "5")
        } else {
            XCTFail("Second segment should be straight type")
        }

        // Verify no validation warnings
        XCTAssertTrue(result.summary.warnings.isEmpty, "Valid V0.4 plan should have no warnings. Got: \(result.summary.warnings)")
    }

    // MARK: - Feature Interaction Tests

    func testPerWeekAndGroupVariantsInteraction() throws {
        // Test that per_week applies first, then group_variants
        let planJSON = """
        {
          "name": "Test Plan",
          "unit": "lb",
          "dictionary": { "SQUAT.BB": "Back Squat" },
          "groups": { "legs": ["SQUAT.BB"] },
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
              "reps": 8,
              "per_week": {
                "1": { "sets": 4 }
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

        // Verify decoding worked
        XCTAssertEqual(result.plan.planName, "Test Plan")

        // Resolution order should be:
        // 1. Base: sets=3
        // 2. per_week: sets=4
        // 3. group_variants: sets=5 (overrides per_week)
        // This would be tested in SegmentResolver tests
    }

    func testAllSegmentTypesWithPerWeek() throws {
        let planJSON = """
        {
          "name": "All Segments Test",
          "unit": "lb",
          "dictionary": {
            "SQUAT.BB": "Back Squat",
            "CURL.DB": "Dumbbell Curl",
            "BENCH.BB": "Bench Press"
          },
          "groups": {},
          "schedule": [{
            "label": "Day A",
            "segments": [{
              "type": "straight",
              "ex": "SQUAT.BB",
              "sets": 3,
              "reps": 5,
              "per_week": {
                "1": { "sets": 3 },
                "2": { "sets": 4 }
              }
            }, {
              "type": "scheme",
              "ex": "CURL.DB",
              "entries": [
                { "sets": 1, "reps": 10 },
                { "sets": 2, "reps": 8 }
              ],
              "per_week": {
                "1": { "sets": 1 }
              }
            }, {
              "type": "superset",
              "rounds": 3,
              "items": [
                {
                  "ex": "BENCH.BB",
                  "sets": 1,
                  "reps": 8,
                  "per_week": {
                    "1": { "sets": 1 },
                    "2": { "sets": 2 }
                  }
                }
              ]
            }, {
              "type": "percentage",
              "ex": "SQUAT.BB",
              "prescriptions": [
                { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.75 }
              ],
              "per_week": {
                "2": {
                  "prescriptions": [
                    { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.85 }
                  ]
                }
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

        // Verify all segment types decoded with per_week
        let day = result.plan.days[0]
        XCTAssertEqual(day.segments.count, 4, "Should have 4 segments")

        // Check straight
        if case .straight(let straight) = day.segments[0] {
            XCTAssertNotNil(straight.perWeek, "Straight should have per_week")
            XCTAssertEqual(straight.perWeek?.keys.count, 2, "Should have 2 weeks")
        } else {
            XCTFail("First segment should be straight")
        }

        // Check scheme
        if case .scheme(let scheme) = day.segments[1] {
            XCTAssertNotNil(scheme.perWeek, "Scheme should have per_week")
        } else {
            XCTFail("Second segment should be scheme")
        }

        // Check superset
        if case .superset(let superset) = day.segments[2] {
            XCTAssertNotNil(superset.items[0].perWeek, "Superset item should have per_week")
        } else {
            XCTFail("Third segment should be superset")
        }

        // Check percentage
        if case .percentage(let percentage) = day.segments[3] {
            XCTAssertNotNil(percentage.perWeek, "Percentage should have per_week")
        } else {
            XCTFail("Fourth segment should be percentage")
        }

        // Should have no validation warnings
        XCTAssertTrue(result.summary.warnings.isEmpty, "Should have no warnings. Got: \(result.summary.warnings)")
    }

    // MARK: - Error Handling Tests

    func testInvalidV04FeaturesGenerateWarnings() throws {
        let planJSON = """
        {
          "name": "Invalid V0.4 Plan",
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
              "reps": 5,
              "per_week": {
                "week_one": { "sets": 4 }
              },
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

        // Should have multiple warnings
        XCTAssertGreaterThan(result.summary.warnings.count, 0, "Should have validation warnings")

        // Check for specific warnings
        let hasPerWeekWarning = result.summary.warnings.contains { $0.contains("per_week") && $0.contains("not numeric") }
        XCTAssertTrue(hasPerWeekWarning, "Should warn about non-numeric per_week key")

        let hasGroupWarning = result.summary.warnings.contains { $0.contains("group_variants") && $0.contains("unknown group") }
        XCTAssertTrue(hasGroupWarning, "Should warn about unknown group")

        let hasAxisWarning = result.summary.warnings.contains { $0.contains("load_axis_target") && $0.contains("no exercise_meta") }
        XCTAssertTrue(hasAxisWarning, "Should warn about missing exercise_meta")
    }
}
