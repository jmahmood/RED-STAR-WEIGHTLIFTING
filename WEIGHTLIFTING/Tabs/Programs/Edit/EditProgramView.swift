//
//  EditProgramView.swift
//  WEIGHTLIFTING
//
//  Created by Claude Code on 2025-12-11.
//

import SwiftUI

struct EditProgramView: View {
    @EnvironmentObject private var exportStore: ExportInboxStore
    @Environment(\.dismiss) private var dismiss

    @State private var plan: PlanV03?
    @State private var planID: String?
    @State private var programName: String = ""
    @State private var dayLabels: [String: String] = [:]

    @State private var showingAddTemplate = false
    @State private var addExerciseSheet: DayContext?

    @State private var errorMessage: String?
    @State private var showingError = false

    struct DayContext: Identifiable {
        let id = UUID()
        let dayLabel: String
        let exerciseNames: [String: String]
    }

    var body: some View {
        Group {
            if let plan = plan, let planID = planID {
                Form {
                    Section("Program Details") {
                        HStack {
                            TextField("Program Name", text: $programName)

                            Button("Save") {
                                saveProgramName()
                            }
                            .disabled(programName == plan.planName || programName.isEmpty)
                        }
                    }

                    Section {
                        Button {
                            showingAddTemplate = true
                        } label: {
                            Label("Add Day from Template", systemImage: "plus.circle.fill")
                        }
                    }

                    Section("Days") {
                        ForEach(plan.scheduleOrder, id: \.self) { dayLabel in
                            if let day = plan.day(named: dayLabel) {
                                DayEditCard(
                                    day: day,
                                    dayLabel: dayLabels[dayLabel] ?? dayLabel,
                                    onLabelChange: { newLabel in
                                        dayLabels[dayLabel] = newLabel
                                    },
                                    onSaveLabel: {
                                        saveDayLabel(old: dayLabel, new: dayLabels[dayLabel] ?? dayLabel)
                                    },
                                    onAddExercise: {
                                        addExerciseSheet = DayContext(
                                            dayLabel: dayLabel,
                                            exerciseNames: plan.exerciseNames
                                        )
                                    },
                                    exerciseNames: plan.exerciseNames
                                )
                            }
                        }
                    }
                }
                .navigationTitle("Edit Program")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showingAddTemplate) {
                    NavigationStack {
                        AddDayFromTemplateView(
                            planID: planID,
                            onComplete: {
                                reloadPlan()
                            }
                        )
                    }
                }
                .sheet(item: $addExerciseSheet) { context in
                    NavigationStack {
                        AddExerciseFlow(
                            planID: planID,
                            dayLabel: context.dayLabel,
                            exerciseNames: context.exerciseNames,
                            onComplete: {
                                reloadPlan()
                            }
                        )
                    }
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK") {}
                } message: {
                    Text(errorMessage ?? "An error occurred")
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            loadPlan()
        }
        .onDisappear {
            // Ensure export store is synced when leaving edit view
            exportStore.reloadPlanLibrary()
        }
    }

    private func loadPlan() {
        do {
            guard let id = try PlanStore.shared.getActivePlanID() else {
                errorMessage = "No active plan found"
                showingError = true
                return
            }

            planID = id
            let loadedPlan = try PlanStore.shared.loadPlan(id: id)
            plan = loadedPlan
            programName = loadedPlan.planName

            // Initialize day labels
            for dayLabel in loadedPlan.scheduleOrder {
                dayLabels[dayLabel] = dayLabel
            }
        } catch {
            errorMessage = "Failed to load plan: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func reloadPlan() {
        guard let id = planID else { return }

        do {
            let loadedPlan = try PlanStore.shared.loadPlan(id: id)
            plan = loadedPlan
            programName = loadedPlan.planName

            // Update day labels for new days
            for dayLabel in loadedPlan.scheduleOrder {
                if dayLabels[dayLabel] == nil {
                    dayLabels[dayLabel] = dayLabel
                }
            }

            // Refresh export store on main thread with a small delay to ensure file system sync
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                exportStore.reloadPlanLibrary()
            }
        } catch {
            errorMessage = "Failed to reload plan: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func saveProgramName() {
        guard let id = planID else { return }

        do {
            try PlanStore.shared.updatePlanName(planID: id, newName: programName)
            reloadPlan()
        } catch {
            errorMessage = "Failed to save program name: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func saveDayLabel(old: String, new: String) {
        guard let id = planID, old != new else { return }

        do {
            try PlanStore.shared.renameDay(planID: id, from: old, to: new)
            reloadPlan()
        } catch {
            errorMessage = "Failed to rename day: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Day Edit Card

struct DayEditCard: View {
    let day: PlanV03.Day
    let dayLabel: String
    let onLabelChange: (String) -> Void
    let onSaveLabel: () -> Void
    let onAddExercise: () -> Void
    let exerciseNames: [String: String]

    @State private var isEditingLabel = false
    @FocusState private var labelFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if isEditingLabel {
                    TextField("Day Name", text: Binding(
                        get: { dayLabel },
                        set: { onLabelChange($0) }
                    ))
                    .focused($labelFieldFocused)
                    .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        isEditingLabel = false
                        labelFieldFocused = false
                        onSaveLabel()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Text(dayLabel)
                        .font(.headline)

                    Spacer()

                    Button {
                        isEditingLabel = true
                        labelFieldFocused = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if !day.segments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(day.segments.enumerated()), id: \.offset) { index, segment in
                        SegmentRow(segment: segment, exerciseNames: exerciseNames)
                    }
                }
            }

            Button {
                onAddExercise()
            } label: {
                Label("Add Exercise", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Segment Row

struct SegmentRow: View {
    let segment: PlanV03.Segment
    let exerciseNames: [String: String]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exerciseName)
                    .font(.body)

                Text(setsRepsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var exerciseName: String {
        switch segment {
        case .straight(let s):
            return exerciseNames[s.exerciseCode] ?? s.exerciseCode
        case .scheme(let s):
            return exerciseNames[s.exerciseCode] ?? s.exerciseCode
        case .superset(let s):
            return s.items.compactMap { exerciseNames[$0.exerciseCode] }.joined(separator: " + ")
        case .percentage(let s):
            return exerciseNames[s.exerciseCode] ?? s.exerciseCode
        case .unsupported:
            return "Unsupported"
        }
    }

    private var setsRepsText: String {
        switch segment {
        case .straight(let s):
            let repsText = s.reps?.displayText ?? "?"
            return "\(s.sets) × \(repsText)"
        case .scheme(let s):
            let totalSets = s.entries.reduce(0) { $0 + $1.sets }
            return "\(totalSets) sets (scheme)"
        case .superset(let s):
            return "\(s.rounds) rounds"
        case .percentage(let s):
            let totalSets = s.prescriptions.reduce(0) { $0 + $1.sets }
            return "\(totalSets) sets (% based)"
        case .unsupported:
            return ""
        }
    }
}
