import SwiftUI

/// Displays details of a workout program
struct ProgramDetailView: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    @EnvironmentObject private var exportStore: ExportInboxStore
    let programName: String

    @State private var program: PlanV03?
    @State private var isActive: Bool = false
    @State private var programData: Data?
    @State private var loadError: String?
    @State private var showingConfirmation = false

    var body: some View {
        Group {
            if let program = program {
                List {
                    Section("Program Info") {
                        LabeledContent("Name", value: program.planName)
                        LabeledContent("Unit", value: program.unit.rawValue.uppercased())
                        LabeledContent("Days", value: "\(program.days.count)")
                        LabeledContent("Schedule", value: program.scheduleOrder.joined(separator: " → "))
                    }

                    Section("Days") {
                        ForEach(program.days, id: \.label) { day in
                            DayRow(day: day)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    coordinator.programsNavPath.append(
                                        ProgramsDestination.programDayDetail(programName, day.label)
                                    )
                                }
                        }
                    }

                    Section {
                        if isActive {
                            Button {
                                sendToWatch()
                            } label: {
                                Label("Send to Watch", systemImage: "applewatch")
                            }
                        } else {
                            Button {
                                showingConfirmation = true
                            } label: {
                                Label("Set as Active Program", systemImage: "checkmark.circle")
                            }
                        }
                    }
                }
                .navigationTitle(program.planName)
                .navigationBarTitleDisplayMode(.large)
                .confirmationDialog("Set as Active Program", isPresented: $showingConfirmation) {
                    Button("Set as Active") {
                        setAsActive()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will replace your current active program.")
                }
            } else {
                if let loadError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.title)
                        Text(loadError)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            loadProgram()
        }
    }

    private func loadProgram() {
        // Check if this is the active program
        isActive = exportStore.activePlan?.planName == programName

        // Load the program
        if isActive, let activePlan = exportStore.activePlan {
            program = activePlan
            if let activePlanURL = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).appendingPathComponent("WeightWatch/Plans/active_plan.json") {
                programData = try? Data(contentsOf: activePlanURL)
            }
            return
        }

        // Load from file
        guard let planDirectory = ProgramDefaults.plansDirectory() else {
            return
        }

        let fileURL = planDirectory.appendingPathComponent("\(programName).json")
        do {
            let data = try Data(contentsOf: fileURL)
            let plan = try JSONDecoder().decode(PlanV03.self, from: data)
            program = plan
            programData = data
            loadError = nil
        } catch {
            print("ProgramDetailView: failed to load \(fileURL.lastPathComponent): \(error)")
            loadError = "Failed to open \(fileURL.lastPathComponent)"
        }

    }

    private func setAsActive() {
        guard let data = programData else { return }

        Task {
            do {
                guard let planDirectory = try? FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ).appendingPathComponent("WeightWatch/Plans") else {
                    return
                }

                try FileManager.default.createDirectory(at: planDirectory, withIntermediateDirectories: true)
                let activePlanURL = planDirectory.appendingPathComponent("active_plan.json")
                try data.write(to: activePlanURL, options: .atomic)

                // Refresh ExportInboxStore
                exportStore.refreshInsightsFromUI()

                isActive = true
            } catch {
                print("Failed to set active program: \(error)")
            }
        }
    }

    private func sendToWatch() {
        do {
            try exportStore.transferPlanToWatch()
        } catch {
            print("Failed to send to watch: \(error)")
        }
    }
}

/// Day row in program detail
struct DayRow: View {
    let day: PlanV03.Day

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.label)
                    .font(.body)
                    .fontWeight(.medium)

                Text("\(day.segments.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// Program day detail view
struct ProgramDayDetailView: View {
    let programName: String
    let dayLabel: String

    @State private var program: PlanV03?
    @State private var day: PlanV03.Day?

    var body: some View {
        Group {
            if let day = day, let program = program {
                List {
                    ForEach(Array(day.segments.enumerated()), id: \.offset) { index, segment in
                        SegmentView(segment: segment, program: program)
                    }
                }
                .navigationTitle(day.label)
                .navigationBarTitleDisplayMode(.large)
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            loadDay()
        }
    }

    private func loadDay() {
        // Load the program
        guard let planDirectory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("WeightWatch/Plans") else {
            return
        }

        let fileURL = planDirectory.appendingPathComponent("active_plan.json")
        guard let data = try? Data(contentsOf: fileURL),
              let plan = try? JSONDecoder().decode(PlanV03.self, from: data) else {
            return
        }

        program = plan
        day = plan.days.first { $0.label == dayLabel }
    }
}

/// Segment view for displaying exercise prescriptions
struct SegmentView: View {
    let segment: PlanV03.Segment
    let program: PlanV03

    var body: some View {
        switch segment {
        case .straight(let straight):
            StraightSegmentView(segment: straight, program: program)
        case .scheme(let scheme):
            SchemeSegmentView(segment: scheme, program: program)
        case .superset(let superset):
            SupersetSegmentView(segment: superset, program: program)
        case .unsupported(let type):
            UnsupportedSegmentView(type: type)
        }
    }
}

/// Straight segment view
struct StraightSegmentView: View {
    let segment: PlanV03.StraightSegment
    let program: PlanV03

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exerciseName(for: segment.exerciseCode))
                .font(.body)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 4) {
                Text(prescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let intensifier = segment.intensifier {
                    Text(intensifierDescription(intensifier))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var prescription: String {
        var parts: [String] = []

        parts.append("\(segment.sets) sets")

        if let reps = segment.reps {
            parts.append("× \(reps.displayText)")
        }

        if let rpe = segment.rpe {
            parts.append("@ RPE \(String(format: "%.1f", rpe))")
        }

        if let restSec = segment.restSec {
            parts.append("(\(restSec)s rest)")
        }

        return parts.joined(separator: " ")
    }

    private func exerciseName(for code: String) -> String {
        program.exerciseNames[code] ?? Exercise.formatExerciseCode(code)
    }

    private func intensifierDescription(_ intensifier: PlanV03.Intensifier) -> String {
        switch intensifier.kind {
        case .dropset:
            if let dropPct = intensifier.dropPct {
                return "Dropset: -\(Int(dropPct * 100))%"
            }
            return "Dropset"
        case .amrap:
            return "AMRAP"
        case .unknown:
            return "Special technique"
        }
    }
}

/// Scheme segment view
struct SchemeSegmentView: View {
    let segment: PlanV03.SchemeSegment
    let program: PlanV03

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exerciseName(for: segment.exerciseCode))
                .font(.body)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 4) {
                Text("Scheme: \(segment.entries.count) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(segment.entries.enumerated()), id: \.offset) { index, entry in
                    Text("Set \(index + 1): \(entry.sets) × \(entry.reps?.displayText ?? "reps")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func exerciseName(for code: String) -> String {
        program.exerciseNames[code] ?? Exercise.formatExerciseCode(code)
    }
}

/// Superset segment view
struct SupersetSegmentView: View {
    let segment: PlanV03.SupersetSegment
    let program: PlanV03

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Superset (\(segment.rounds) rounds)")
                .font(.body)
                .fontWeight(.semibold)

            ForEach(Array(segment.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top) {
                    Text("\(Character(UnicodeScalar(65 + index)!))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.blue)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName(for: item.exerciseCode))
                            .font(.caption)
                            .fontWeight(.medium)

                        Text("\(item.sets) × \(item.reps?.displayText ?? "reps")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func exerciseName(for code: String) -> String {
        program.exerciseNames[code] ?? Exercise.formatExerciseCode(code)
    }
}

/// Unsupported segment view
struct UnsupportedSegmentView: View {
    let type: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)

            Text("Unsupported segment type: \(type)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
