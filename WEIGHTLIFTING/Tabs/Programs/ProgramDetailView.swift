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
    @State private var showingHistory = false

    @ViewBuilder
    private var actionButton: some View {
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

    var body: some View {
        Group {
            if let program = program {
                VStack(spacing: 16) {
                    actionButton
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.horizontal)

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
                    }
                    .listStyle(.insetGrouped)
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
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if isActive {
                                Button {
                                    sendToWatch()
                                } label: {
                                    Label("Send to Watch", systemImage: "applewatch")
                                }
                            }

                            Divider()

                            Button {
                                showingHistory = true
                            } label: {
                                Label("History & Restore...", systemImage: "clock.arrow.circlepath")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingHistory) {
                    NavigationStack {
                        ProgramHistoryView(
                            planID: currentPlanID(for: program.planName),
                            programName: program.planName
                        )
                        .environmentObject(exportStore)
                    }
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
            // Encode the active plan to JSON data for display
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            programData = try? encoder.encode(activePlan)
            return
        }

        // Load from file
        guard let planDirectory = ProgramDefaults.plansDirectory() else {
            return
        }

        let candidates: [URL] = [
            planDirectory.appendingPathComponent("\(programName).json"),
            planDirectory.appendingPathComponent("\(ProgramDefaults.sanitizedFileComponent(programName)).json")
        ]

        for candidate in candidates {
            if let data = try? Data(contentsOf: candidate),
               let plan = try? JSONDecoder().decode(PlanV03.self, from: data) {
                program = plan
                programData = data
                loadError = nil
                return
            }
        }

        // Fallback: scan directory for a matching planName in contents (handles renamed files)
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: planDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in contents where url.pathExtension == "json" && url.lastPathComponent != "active_plan.json" {
                if let data = try? Data(contentsOf: url),
                   let plan = try? JSONDecoder().decode(PlanV03.self, from: data),
                   plan.planName == programName {
                    program = plan
                    programData = data
                    loadError = nil
                    return
                }
            }
        }

        loadError = "Failed to open \(programName).json"
        print("ProgramDetailView: failed to load \(programName).json")

    }

    private func setAsActive() {
        guard let program = program else { return }

        Task {
            do {
                // Use PlanStore for saving
                let planID = (try? PlanStore.shared.getActivePlanID())
                    ?? PlanStore.generatePlanID(from: program.planName)
                try PlanStore.shared.savePlan(program, id: planID, snapshotIfExists: true)
                try PlanStore.shared.setActivePlan(id: planID)

                // Refresh ExportInboxStore and reload plan library so it can be synced to watch
                exportStore.reloadPlanLibrary()

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

    private func currentPlanID(for planName: String) -> String {
        (try? PlanStore.shared.getActivePlanID())
            ?? PlanStore.generatePlanID(from: planName)
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
        // Load the program using PlanStore
        guard let planID = try? PlanStore.shared.getActivePlanID(),
              let plan = try? PlanStore.shared.loadPlan(id: planID) else {
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
        case .percentage(let percentage):
            PercentageSegmentView(segment: percentage, program: program)
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

/// Percentage segment view (V0.4: 5-3-1 style)
struct PercentageSegmentView: View {
    let segment: PlanV03.PercentageSegment
    let program: PlanV03

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exerciseName(for: segment.exerciseCode))
                .font(.body)
                .fontWeight(.medium)

            ForEach(Array(segment.prescriptions.enumerated()), id: \.offset) { index, prescription in
                HStack {
                    Text("\(prescription.sets) × \(prescription.reps.displayText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("@ \(Int(prescription.pctRM * 100))% 1RM")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    if let intensifier = prescription.intensifier {
                        Text(intensifierDescription(intensifier))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func exerciseName(for code: String) -> String {
        program.exerciseNames[code] ?? Exercise.formatExerciseCode(code)
    }

    private func intensifierDescription(_ intensifier: PlanV03.Intensifier) -> String {
        switch intensifier.kind {
        case .amrap:
            return "AMRAP"
        case .dropset:
            return "Drop Set"
        case .unknown:
            return "Intensifier"
        }
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
