import Foundation

/// Default starter programs packaged in the app bundle.
enum ProgramDefaults {
    private static let bundleSubdirectory = "DefaultPrograms"
    private static let embeddedJSON: [String: String] = [
        "531_bbb_sample": #"""
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
    "LEG.PRESS.45": "45-deg Leg Press",
    "ROW.BB.BENT": "Bent-Over Barbell Row",
    "ROW.CBL.SEAT": "Seated Cable Row",
    "PULLUP.BW.NEU": "Neutral-Grip Pull-Up",
    "CORE.BW.PLNK": "Plank"
  },

  "groups": {
    "GROUP_SQ_MAIN":  ["SQ.BB.BACK", "SQ.SSB.BACK", "SQ.BB.FRONT"],
    "GROUP_BP_MAIN":  ["BP.BB.FLAT", "BP.DB.INCL", "BP.SWISS.FLAT"],
    "GROUP_DL_MAIN":  ["DL.BB.CONV", "DL.TB.CONV"],
    "GROUP_OHP_MAIN": ["OHP.BB.STND", "OHP.DB.SEAT"],
    "GROUP_SQ_BBB":   ["SQ.BB.BACK", "LEG.PRESS.45", "SQ.BB.FRONT"],
    "GROUP_BP_BBB":   ["BP.BB.FLAT", "BP.DB.INCL", "BP.SWISS.FLAT"],
    "GROUP_DL_BBB":   ["DL.BB.CONV", "DL.TB.CONV"],
    "GROUP_OHP_BBB":  ["OHP.BB.STND", "OHP.DB.SEAT"]
  },

  "exercise_meta": {
    "LEG.PRESS.45": {
      "equipment": ["machine"],
      "home_friendly": false,
      "load_axes": {
        "pin_hole": {
          "kind": "ordinal",
          "values": ["1","2","3","4","5","6","7","8"]
        }
      }
    },
    "SQ.BB.BACK": {
      "equipment": ["barbell"],
      "home_friendly": false
    },
    "BP.BB.FLAT": {
      "equipment": ["barbell"],
      "home_friendly": false
    },
    "DL.BB.CONV": {
      "equipment": ["barbell"],
      "home_friendly": false
    },
    "OHP.BB.STND": {
      "equipment": ["barbell"],
      "home_friendly": true
    }
  },

  "phase": {
    "index": 1,
    "weeks": [1, 2, 3, 4]
  },

  "progression": {
    "mode": "double_progression",
    "reps_first": true,
    "load_increment_kg": 2.5,
    "cap_rpe": 9.0
  },

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
        "SQ.BB.BACK": {
          "sets": 5,
          "reps": { "min": 10, "max": 10 },
          "rest_sec": 90
        },
        "LEG.PRESS.45": {
          "sets": 5,
          "reps": { "min": 10, "max": 15 },
          "rest_sec": 90
        },
        "SQ.BB.FRONT": {
          "sets": 4,
          "reps": { "min": 8, "max": 10 },
          "rest_sec": 120
        }
      }
    },
    "GROUP_BP_BBB": {
      "volume": {
        "BP.BB.FLAT": {
          "sets": 5,
          "reps": { "min": 10, "max": 10 },
          "rest_sec": 90
        },
        "BP.DB.INCL": {
          "sets": 4,
          "reps": { "min": 10, "max": 12 },
          "rest_sec": 90
        },
        "BP.SWISS.FLAT": {
          "sets": 4,
          "reps": { "min": 8, "max": 10 },
          "rest_sec": 120
        }
      }
    },
    "GROUP_DL_BBB": {
      "volume": {
        "DL.BB.CONV": {
          "sets": 5,
          "reps": { "min": 10, "max": 10 },
          "rest_sec": 120
        },
        "DL.TB.CONV": {
          "sets": 4,
          "reps": { "min": 8, "max": 10 },
          "rest_sec": 120
        }
      }
    },
    "GROUP_OHP_BBB": {
      "volume": {
        "OHP.BB.STND": {
          "sets": 5,
          "reps": { "min": 10, "max": 10 },
          "rest_sec": 90
        },
        "OHP.DB.SEAT": {
          "sets": 4,
          "reps": { "min": 10, "max": 12 },
          "rest_sec": 90
        }
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
            {
              "sets": 1,
              "reps": { "min": 5, "max": 5 },
              "pct_1rm": 0.85,
              "intensifier": { "kind": "amrap", "when": "last_set" }
            }
          ],
          "per_week": {
            "2": {
              "prescriptions": [
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.70 },
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.80 },
                {
                  "sets": 1,
                  "reps": { "min": 3, "max": 3 },
                  "pct_1rm": 0.90,
                  "intensifier": { "kind": "amrap", "when": "last_set" }
                }
              ]
            },
            "3": {
              "prescriptions": [
                { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.75 },
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.85 },
                {
                  "sets": 1,
                  "reps": { "min": 1, "max": 1 },
                  "pct_1rm": 0.95,
                  "intensifier": { "kind": "amrap", "when": "last_set" }
                }
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
            {
              "sets": 1,
              "reps": { "min": 5, "max": 5 },
              "pct_1rm": 0.85,
              "intensifier": { "kind": "amrap", "when": "last_set" }
            }
          ],
          "per_week": {
            "2": {
              "prescriptions": [
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.70 },
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.80 },
                {
                  "sets": 1,
                  "reps": { "min": 3, "max": 3 },
                  "pct_1rm": 0.90,
                  "intensifier": { "kind": "amrap", "when": "last_set" }
                }
              ]
            },
            "3": {
              "prescriptions": [
                { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.75 },
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.85 },
                {
                  "sets": 1,
                  "reps": { "min": 1, "max": 1 },
                  "pct_1rm": 0.95,
                  "intensifier": { "kind": "amrap", "when": "last_set" }
                }
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
            {
              "sets": 1,
              "reps": { "min": 5, "max": 5 },
              "pct_1rm": 0.85,
              "intensifier": { "kind": "amrap", "when": "last_set" }
            }
          ],
          "per_week": {
            "2": {
              "prescriptions": [
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.70 },
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.80 },
                {
                  "sets": 1,
                  "reps": { "min": 3, "max": 3 },
                  "pct_1rm": 0.90,
                  "intensifier": { "kind": "amrap", "when": "last_set" }
                }
              ]
            },
            "3": {
              "prescriptions": [
                { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.75 },
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.85 },
                {
                  "sets": 1,
                  "reps": { "min": 1, "max": 1 },
                  "pct_1rm": 0.95,
                  "intensifier": { "kind": "amrap", "when": "last_set" }
                }
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
            {
              "sets": 1,
              "reps": { "min": 5, "max": 5 },
              "pct_1rm": 0.85,
              "intensifier": { "kind": "amrap", "when": "last_set" }
            }
          ],
          "per_week": {
            "2": {
              "prescriptions": [
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.70 },
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.80 },
                {
                  "sets": 1,
                  "reps": { "min": 3, "max": 3 },
                  "pct_1rm": 0.90,
                  "intensifier": { "kind": "amrap", "when": "last_set" }
                }
              ]
            },
            "3": {
              "prescriptions": [
                { "sets": 1, "reps": { "min": 5, "max": 5 }, "pct_1rm": 0.75 },
                { "sets": 1, "reps": { "min": 3, "max": 3 }, "pct_1rm": 0.85 },
                {
                  "sets": 1,
                  "reps": { "min": 1, "max": 1 },
                  "pct_1rm": 0.95,
                  "intensifier": { "kind": "amrap", "when": "last_set" }
                }
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
"""#,
        "reddit_ppl": #"""
{
  "plan_name": "Reddit PPL",
  "unit": "lb",
  "exercise_names": {
    "BENCH.BB.FLAT": "Barbell Bench Press",
    "PRESS.BB.STAND": "Overhead Press",
    "PRESS.DB.INCLINE": "Incline Dumbbell Press",
    "FLY.CABLE": "Cable Flyes",
    "EXTENSION.CABLE.ROPE": "Rope Pushdowns",
    "EXTENSION.DB.OVERHEAD": "Overhead Dumbbell Extension",
    "DEADLIFT.BB.CONV": "Conventional Deadlift",
    "PULLUP.BW": "Pull-ups",
    "ROW.BB.BEND": "Barbell Rows",
    "ROW.CABLE.SEATED": "Seated Cable Rows",
    "CURL.BB": "Barbell Curls",
    "CURL.DB.HAMMER": "Hammer Curls",
    "SQUAT.BB.HIGH": "Barbell Squat",
    "PRESS.LEG": "Leg Press",
    "LUNGE.DB": "Dumbbell Lunges",
    "CURL.LEG.LYING": "Lying Leg Curls",
    "EXTENSION.LEG": "Leg Extensions",
    "RAISE.CALF.STANDING": "Standing Calf Raises"
  },
  "alt_groups": {},
  "days": [
    {
      "label": "Push Day A",
      "segments": [
        { "type": "straight", "exercise_code": "BENCH.BB.FLAT", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "PRESS.BB.STAND", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 120 },
        { "type": "straight", "exercise_code": "PRESS.DB.INCLINE", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "FLY.CABLE", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 },
        { "type": "straight", "exercise_code": "EXTENSION.CABLE.ROPE", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 },
        { "type": "straight", "exercise_code": "EXTENSION.DB.OVERHEAD", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 }
      ]
    },
    {
      "label": "Pull Day A",
      "segments": [
        { "type": "straight", "exercise_code": "DEADLIFT.BB.CONV", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "PULLUP.BW", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 120 },
        { "type": "straight", "exercise_code": "ROW.CABLE.SEATED", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "ROW.BB.BEND", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "CURL.BB", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 },
        { "type": "straight", "exercise_code": "CURL.DB.HAMMER", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 }
      ]
    },
    {
      "label": "Legs Day A",
      "segments": [
        { "type": "straight", "exercise_code": "SQUAT.BB.HIGH", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "PRESS.LEG", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 120 },
        { "type": "straight", "exercise_code": "LUNGE.DB", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "CURL.LEG.LYING", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "EXTENSION.LEG", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 },
        { "type": "straight", "exercise_code": "RAISE.CALF.STANDING", "sets": 5, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 }
      ]
    },
    {
      "label": "Push Day B",
      "segments": [
        { "type": "straight", "exercise_code": "PRESS.BB.STAND", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "BENCH.BB.FLAT", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 120 },
        { "type": "straight", "exercise_code": "PRESS.DB.INCLINE", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "FLY.CABLE", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 },
        { "type": "straight", "exercise_code": "EXTENSION.CABLE.ROPE", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 },
        { "type": "straight", "exercise_code": "EXTENSION.DB.OVERHEAD", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 }
      ]
    },
    {
      "label": "Pull Day B",
      "segments": [
        { "type": "straight", "exercise_code": "ROW.BB.BEND", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "PULLUP.BW", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 120 },
        { "type": "straight", "exercise_code": "ROW.CABLE.SEATED", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "DEADLIFT.BB.CONV", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 120 },
        { "type": "straight", "exercise_code": "CURL.DB.HAMMER", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 },
        { "type": "straight", "exercise_code": "CURL.BB", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 }
      ]
    },
    {
      "label": "Legs Day B",
      "segments": [
        { "type": "straight", "exercise_code": "SQUAT.BB.HIGH", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "PRESS.LEG", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 120 },
        { "type": "straight", "exercise_code": "LUNGE.DB", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "CURL.LEG.LYING", "sets": 3, "reps": { "min": 8, "max": 12 }, "rest_sec": 90 },
        { "type": "straight", "exercise_code": "EXTENSION.LEG", "sets": 3, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 },
        { "type": "straight", "exercise_code": "RAISE.CALF.STANDING", "sets": 5, "reps": { "min": 12, "max": 15 }, "rest_sec": 60 }
      ]
    }
  ],
  "schedule_order": [
    "Push Day A",
    "Pull Day A",
    "Legs Day A",
    "Push Day B",
    "Pull Day B",
    "Legs Day B"
  ]
}
"""#,
        "stronglifts_5x5": #"""
{
  "plan_name": "Stronglifts 5x5",
  "unit": "lb",
  "exercise_names": {
    "SQUAT.BB.HIGH": "Barbell Squat",
    "BENCH.BB.FLAT": "Barbell Bench Press",
    "ROW.BB.BEND": "Barbell Row",
    "PRESS.BB.STAND": "Overhead Press",
    "DEADLIFT.BB.CONV": "Deadlift"
  },
  "alt_groups": {},
  "days": [
    {
      "label": "Workout A",
      "segments": [
        { "type": "straight", "exercise_code": "SQUAT.BB.HIGH", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "BENCH.BB.FLAT", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "ROW.BB.BEND", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 }
      ]
    },
    {
      "label": "Workout B",
      "segments": [
        { "type": "straight", "exercise_code": "SQUAT.BB.HIGH", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "PRESS.BB.STAND", "sets": 5, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 },
        { "type": "straight", "exercise_code": "DEADLIFT.BB.CONV", "sets": 1, "reps": { "min": 5, "max": 5 }, "rest_sec": 180 }
      ]
    }
  ],
  "schedule_order": [
    "Workout A",
    "Workout B",
    "Workout A"
  ]
}
"""#
    ]

    private static var planNameCache: [String: String] = {
        var cache: [String: String] = [:]
        for program in programs {
            if let data = data(for: program),
               let decoded = try? JSONDecoder().decode(PlanV03.self, from: data) {
                cache[program.fileName] = decoded.planName
            }
        }
        return cache
    }()

    struct DefaultProgram: Identifiable {
        let id = UUID()
        let name: String
        let summary: String
        let fileName: String
    }

    static let programs: [DefaultProgram] = [
        .init(
            name: "5/3/1 - BBB (Sample)",
            summary: "4-day 5/3/1 with Boring But Big assistance (v0.4 features).",
            fileName: "531_bbb_sample"
        ),
        .init(
            name: "Reddit PPL",
            summary: "Push / Pull / Legs split from the Reddit FAQ.",
            fileName: "reddit_ppl"
        ),
        .init(
            name: "StrongLifts 5x5",
            summary: "3-day full-body strength with progressive 5x5 work.",
            fileName: "stronglifts_5x5"
        )
    ]

    /// Centralized Plans directory location.
    static func plansDirectory() -> URL? {
        StoragePaths.makeDefault().plansDirectory
    }

    /// Copy bundled defaults into the Plans directory, overwriting stale copies.
    static func seedDefaults(into directory: URL? = nil) {
        guard let dir = directory ?? plansDirectory() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for program in programs {
            guard let data = data(for: program) else {
                print("ProgramDefaults: missing bundled data for \(program.fileName)")
                continue
            }

            let validatedName: String?
            do {
                validatedName = try PlanValidator.validate(data: data).summary.planName
            } catch {
                print("ProgramDefaults: bundled program \(program.fileName) failed validation: \(error)")
                validatedName = nil
            }

            let destination = destinationURL(for: program, planName: validatedName, directory: dir)
            do {
                try data.write(to: destination, options: .atomic)
            } catch {
                print("ProgramDefaults: failed to write \(destination.lastPathComponent): \(error)")
            }
        }
    }

    /// Load the bundled data for a program.
    static func data(for program: DefaultProgram) -> Data? {
        if let url = bundleURL(for: program.fileName), let data = try? Data(contentsOf: url) {
            return data
        }
        if let fallback = embeddedJSON[program.fileName] {
            return fallback.data(using: .utf8)
        }
        return nil
    }

    private static func bundleURL(for fileName: String) -> URL? {
        // Try DefaultPrograms subdirectory (where we ship the files)
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: bundleSubdirectory) {
            return url
        }
        // Fallback to bundle root
        return Bundle.main.url(forResource: fileName, withExtension: "json")
    }

    /// Centralized destination path for a default program.
    static func destinationURL(for program: DefaultProgram, planName: String? = nil, directory: URL) -> URL {
        let cachedName = planNameCache[program.fileName]
        let resolvedName = ([planName, cachedName, program.name].compactMap { $0 }.first { !$0.isEmpty }) ?? program.name
        let safeComponent = sanitizedFileComponent(resolvedName)
        return directory.appendingPathComponent("\(safeComponent).json")
    }

    /// Replace filesystem-hostile characters with hyphens.
    static func sanitizedFileComponent(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        let replaced = raw.unicodeScalars.map { invalid.contains($0) ? "-" : Character($0) }
        // Collapse consecutive hyphens for tidier filenames
        let joined = String(replaced).replacingOccurrences(of: "--", with: "-")
        let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Program" : trimmed
    }
}
