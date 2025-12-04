import Foundation

/// Default starter programs packaged in the app bundle.
enum ProgramDefaults {
    private static let bundleSubdirectory = "DefaultPrograms"
    private static let embeddedJSON: [String: String] = [
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
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return appSupport.appendingPathComponent("WeightWatch/Plans", isDirectory: true)
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
        return directory.appendingPathComponent("\(resolvedName).json")
    }
}
