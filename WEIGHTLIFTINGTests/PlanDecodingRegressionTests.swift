//
//  PlanDecodingRegressionTests.swift
//  WEIGHTLIFTINGTests
//
//  Created by Codex on 2025-12-10.
//

import XCTest
@testable import WEIGHTLIFTING

final class PlanDecodingRegressionTests: XCTestCase {

    func testBoringButBigSamplePlanDecodes() throws {
        let json = """
        {
          "name": "5/3/1 - Boring But Big (Sample v0.4)",
          "author": "Sample",
          "source_url": "https://example.com/531-bbb-sample",
          "license_note": "Sample program for Weightlifting app",
          "unit": "kg",
          "dictionary": {
            "SQ.BB.BACK": "Back Squat (High Bar)",
            "SQ.SSB.BACK": "Safety Squat Bar Back Squat",
            "SQ.BB.FRONT": "Front Squat",
            "DL.BB.CONV": "Conventional Deadlift",
            "DL.TB.CONV": "Trap Bar Deadlift",
            "BP.BB.FLAT": "Barbell Bench Press",
            "BP.DB.INCL": "Incline Dumbbell Bench",
            "BP.SWISS.FLAT": "Swiss Bar Bench Press",
            "OHP.BB.STND": "Standing Overhead Press",
            "OHP.DB.SEAT": "Seated Dumbbell Overhead Press",
            "LEG.PRESS.45": "45 Degree Leg Press",
            "ROW.BB.BENT": "Bent-Over Barbell Row",
            "ROW.CBL.SEAT": "Seated Cable Row",
            "PULLUP.BW.NEU": "Neutral-Grip Pull-Up",
            "CORE.BW.PLNK": "Plank"
          },
          "groups": {
            "GROUP_SQ_MAIN": ["SQ.BB.BACK", "SQ.SSB.BACK", "SQ.BB.FRONT"],
            "GROUP_BP_MAIN": ["BP.BB.FLAT", "BP.DB.INCL", "BP.SWISS.FLAT"],
            "GROUP_DL_MAIN": ["DL.BB.CONV", "DL.TB.CONV"],
            "GROUP_OHP_MAIN": ["OHP.BB.STND", "OHP.DB.SEAT"],
            "GROUP_SQ_BBB": ["SQ.BB.BACK", "LEG.PRESS.45", "SQ.BB.FRONT"],
            "GROUP_BP_BBB": ["BP.BB.FLAT", "BP.DB.INCL", "BP.SWISS.FLAT"],
            "GROUP_DL_BBB": ["DL.BB.CONV", "DL.TB.CONV"],
            "GROUP_OHP_BBB": ["OHP.BB.STND", "OHP.DB.SEAT"]
          },
          "exercise_meta": {
            "LEG.PRESS.45": {
              "equipment": ["machine"],
              "home_friendly": false,
              "load_axes": {
                "pin_hole": { "kind": "ordinal", "values": ["1","2","3","4","5","6","7","8"] }
              }
            },
            "SQ.BB.BACK": { "equipment": ["barbell"], "home_friendly": false },
            "BP.BB.FLAT": { "equipment": ["barbell"], "home_friendly": false },
            "DL.BB.CONV": { "equipment": ["barbell"], "home_friendly": false },
            "OHP.BB.STND": { "equipment": ["barbell"], "home_friendly": true }
          },
          "phase": { "index": 1, "weeks": [1,2,3,4] },
          "progression": { "mode": "double_progression", "reps_first": true, "load_increment_kg": 2.5, "cap_rpe": 9.0 },
          "warmup": {
            "pattern": "percent_of_top",
            "stages": [
              { "pct_1rm": 0.30, "reps": 8 },
              { "pct_1rm": 0.50, "reps": 5 },
              { "pct_1rm": 0.70, "reps": 3 }
            ],
            "round_to": 2.5,
            "merge_after_rounding": true
          },
          "group_variants": {
            "GROUP_SQ_BBB": {
              "volume": {
                "SQ.BB.BACK": { "sets": 5, "reps": { "min": 10, "max": 10 }, "rest_sec": 90 },
                "LEG.PRESS.45": { "sets": 5, "reps": { "min": 10, "max": 15 }, "rest_sec": 90 },
                "SQ.BB.FRONT": { "sets": 4, "reps": { "min": 8, "max": 10 }, "rest_sec": 120 }
              }
            },
            "GROUP_BP_BBB": {
              "volume": {
                "BP.BB.FLAT": { "sets": 5, "reps": { "min": 10, "max": 10 }, "rest_sec": 90 },
                "BP.DB.INCL": { "sets": 4, "reps": { "min": 10, "max": 12 }, "rest_sec": 90 },
                "BP.SWISS.FLAT": { "sets": 4, "reps": { "min": 8, "max": 10 }, "rest_sec": 120 }
              }
            },
            "GROUP_DL_BBB": {
              "volume": {
                "DL.BB.CONV": { "sets": 5, "reps": { "min": 10, "max": 10 }, "rest_sec": 120 },
                "DL.TB.CONV": { "sets": 4, "reps": { "min": 8, "max": 10 }, "rest_sec": 120 }
              }
            },
            "GROUP_OHP_BBB": {
              "volume": {
                "OHP.BB.STND": { "sets": 5, "reps": { "min": 10, "max": 10 }, "rest_sec": 90 },
                "OHP.DB.SEAT": { "sets": 4, "reps": { "min": 10, "max": 12 }, "rest_sec": 90 }
              }
            }
          },
          "schedule": [
            {
              "day": 1,
              "label": "Day 1 - Squat 5/3/1 + BBB",
              "goal": "Squat strength + lower body volume",
              "segments": [
                {
                  "type": "percentage",
                  "ex": "SQ.BB.BACK",
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
                    },
                    "4": {
                      "prescriptions": [
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.40 },
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.50 },
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.60 }
                      ]
                    }
                  }
                },
                {
                  "type": "straight",
                  "ex": "SQ.BB.BACK",
                  "alt_group": "GROUP_SQ_BBB",
                  "group_role": "volume",
                  "sets": 5,
                  "reps": { "min": 10, "max": 10 },
                  "rest_sec": 90,
                  "rir": 2
                }
              ]
            },
            {
              "day": 2,
              "label": "Day 2 - Bench 5/3/1 + BBB",
              "goal": "Bench strength + chest/press volume",
              "segments": [
                {
                  "type": "percentage",
                  "ex": "BP.BB.FLAT",
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
                    },
                    "4": {
                      "prescriptions": [
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.40 },
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.50 },
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.60 }
                      ]
                    }
                  }
                },
                {
                  "type": "straight",
                  "ex": "BP.BB.FLAT",
                  "alt_group": "GROUP_BP_BBB",
                  "group_role": "volume",
                  "sets": 5,
                  "reps": { "min": 10, "max": 10 },
                  "rest_sec": 90,
                  "rir": 2
                }
              ]
            },
            {
              "day": 3,
              "label": "Day 3 - Deadlift 5/3/1 + BBB",
              "goal": "Deadlift strength + posterior chain volume",
              "segments": [
                {
                  "type": "percentage",
                  "ex": "DL.BB.CONV",
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
                    },
                    "4": {
                      "prescriptions": [
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.40 },
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.50 },
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.60 }
                      ]
                    }
                  }
                },
                {
                  "type": "straight",
                  "ex": "DL.BB.CONV",
                  "alt_group": "GROUP_DL_BBB",
                  "group_role": "volume",
                  "sets": 5,
                  "reps": { "min": 10, "max": 10 },
                  "rest_sec": 120,
                  "rir": 2
                },
                {
                  "type": "straight",
                  "ex": "LEG.PRESS.45",
                  "alt_group": "GROUP_SQ_BBB",
                  "group_role": "volume",
                  "sets": 5,
                  "reps": { "min": 10, "max": 15 },
                  "rest_sec": 90,
                  "load_axis_target": { "axis": "pin_hole", "target": "5" }
                }
              ]
            },
            {
              "day": 4,
              "label": "Day 4 - Press 5/3/1 + BBB",
              "goal": "Overhead press strength + shoulder volume",
              "segments": [
                {
                  "type": "percentage",
                  "ex": "OHP.BB.STND",
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
                    },
                    "4": {
                      "prescriptions": [
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.40 },
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.50 },
                        { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.60 }
                      ]
                    }
                  }
                },
                {
                  "type": "straight",
                  "ex": "OHP.BB.STND",
                  "alt_group": "GROUP_OHP_BBB",
                  "group_role": "volume",
                  "sets": 5,
                  "reps": { "min": 10, "max": 10 },
                  "rest_sec": 90,
                  "rir": 2
                }
              ]
            }
          ]
        }
        """

        guard let data = json.data(using: .utf8) else {
            XCTFail("Could not build JSON data")
            return
        }

        let result = try PlanValidator.validate(data: data)
        XCTAssertEqual(result.plan.planName, "5/3/1 - Boring But Big (Sample v0.4)")
        XCTAssertEqual(result.plan.days.count, 4)
        XCTAssertTrue(result.summary.warnings.isEmpty, "Expected no warnings, got \(result.summary.warnings)")
    }

    func testMissingPct1RmFails() {
        let json = """
        {
          "name": "PctMissing",
          "unit": "kg",
          "dictionary": { "SQ.BB.BACK": "Back Squat" },
          "groups": {},
          "schedule": [{
            "label": "Day 1",
            "segments": [{
              "type": "percentage",
              "ex": "SQ.BB.BACK",
              "prescriptions": [
                { "sets": 1, "reps": 5 }
              ]
            }]
          }]
        }
        """

        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try PlanValidator.validate(data: data)) { error in
            guard case PlanValidationError.decodingFailed(let underlying) = error else {
                XCTFail("Expected decodingFailed, got \(error)")
                return
            }
            XCTAssertTrue("\(underlying)".contains("pct_1rm"), "Unexpected underlying error: \(underlying)")
        }
    }
}
