//
//  AddExerciseFlow.swift
//  WEIGHTLIFTING
//
//  Created by Claude Code on 2025-12-11.
//

import SwiftUI

struct AddExerciseFlow: View {
    let planID: String
    let dayLabel: String
    let exerciseNames: [String: String]
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var configurationSheet: ExerciseContext?
    @State private var searchText = ""

    struct ExerciseContext: Identifiable {
        let id = UUID()
        let code: String
        let name: String
    }

    var body: some View {
        Group {
            if filteredExercises.isEmpty {
                VStack(spacing: 16) {
                    Text("No Exercises Found")
                        .font(.headline)
                    if !searchText.isEmpty {
                        Text("No exercises match '\(searchText)'")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("This program has no exercises defined.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else {
                List {
                    ForEach(filteredExercises, id: \.key) { code, name in
                        Button {
                            configurationSheet = ExerciseContext(code: code, name: name)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Text(code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search exercises")
            }
        }
        .navigationTitle("Select Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(item: $configurationSheet) { context in
            NavigationStack {
                ExerciseConfigurationView(
                    planID: planID,
                    dayLabel: dayLabel,
                    exerciseCode: context.code,
                    exerciseName: context.name,
                    onComplete: {
                        onComplete()
                        dismiss()
                    }
                )
            }
        }
    }

    private var filteredExercises: [(key: String, value: String)] {
        let sorted = exerciseNames.sorted { $0.value < $1.value }

        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { code, name in
                name.localizedCaseInsensitiveContains(searchText) ||
                code.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Exercise Configuration View

struct ExerciseConfigurationView: View {
    let planID: String
    let dayLabel: String
    let exerciseCode: String
    let exerciseName: String
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sets: Int = 3
    @State private var repsMin: Int = 6
    @State private var repsMax: Int = 12

    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        Form {
            Section("Exercise") {
                Text(exerciseName)
                    .font(.headline)

                Text(exerciseCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Configuration") {
                HStack {
                    Text("Sets")
                    Spacer()
                    Picker("Sets", selection: $sets) {
                        ForEach(1...20, id: \.self) { num in
                            Text("\(num)").tag(num)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 100)
                    .clipped()
                }

                HStack {
                    Text("Reps")
                    Spacer()
                    Picker("Min", selection: $repsMin) {
                        ForEach(1...20, id: \.self) { num in
                            Text("\(num)").tag(num)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 100)
                    .clipped()

                    Text("–")
                        .padding(.horizontal, 4)

                    Picker("Max", selection: $repsMax) {
                        ForEach(5...30, id: \.self) { num in
                            Text("\(num)").tag(num)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 100)
                    .clipped()
                }
            }

            Section {
                Button {
                    addExercise()
                } label: {
                    Text("Add to Day")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .navigationTitle("Configure Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onChange(of: repsMin) { newMin in
            if newMin > repsMax {
                repsMax = newMin
            }
        }
        .onChange(of: repsMax) { newMax in
            if newMax < repsMin {
                repsMin = newMax
            }
        }
    }

    private var isValid: Bool {
        sets > 0 && repsMin >= 1 && repsMax >= 1 && repsMin <= repsMax
    }

    private func addExercise() {
        guard isValid else { return }

        do {
            try PlanStore.shared.appendStraightSegment(
                planID: planID,
                dayLabel: dayLabel,
                exerciseCode: exerciseCode,
                sets: sets,
                repsMin: repsMin,
                repsMax: repsMax
            )
            onComplete()
        } catch {
            errorMessage = "Failed to add exercise: \(error.localizedDescription)"
            showingError = true
        }
    }
}
