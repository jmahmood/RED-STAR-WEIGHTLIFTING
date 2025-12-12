//
//  AddDayFromTemplateView.swift
//  WEIGHTLIFTING
//
//  Created by Claude Code on 2025-12-11.
//

import SwiftUI

struct AddDayFromTemplateView: View {
    let planID: String
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var templateRepository: TemplateRepository?
    @State private var searchText = ""
    @State private var selectedTemplate: TemplateDay?

    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        Group {
            if let repo = templateRepository {
                let grouped = repo.templatesByCategory()

                if grouped.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("No Templates Available")
                            .font(.headline)

                        Text("Template file is empty or could not be loaded.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(Array(grouped.keys.sorted()), id: \.self) { category in
                            Section(category) {
                                ForEach(filteredTemplates(grouped[category] ?? []), id: \.templateID) { template in
                                    TemplateRow(
                                        template: template,
                                        isSelected: selectedTemplate?.templateID == template.templateID,
                                        onSelect: {
                                            selectedTemplate = template
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView("Loading templates...")
            }
        }
        .searchable(text: $searchText, prompt: "Search templates")
        .navigationTitle("Add Day from Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Day") {
                    addTemplate()
                }
                .disabled(selectedTemplate == nil)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            loadTemplates()
        }
    }

    private func loadTemplates() {
        // Try multiple paths to find the CSV file
        var csvURL: URL?

        // Try 1: In root of bundle
        csvURL = Bundle.main.url(forResource: "day_templates", withExtension: "csv")

        // Try 2: In Resources/Templates subdirectory
        if csvURL == nil {
            csvURL = Bundle.main.url(
                forResource: "day_templates",
                withExtension: "csv",
                subdirectory: "Resources/Templates"
            )
        }

        // Try 3: In just Templates subdirectory
        if csvURL == nil {
            csvURL = Bundle.main.url(
                forResource: "day_templates",
                withExtension: "csv",
                subdirectory: "Templates"
            )
        }

        guard let url = csvURL else {
            errorMessage = "Template file not found in bundle"
            showingError = true
            return
        }

        do {
            templateRepository = try TemplateRepository(csvURL: url)
        } catch {
            errorMessage = "Failed to load templates: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func filteredTemplates(_ templates: [TemplateDay]) -> [TemplateDay] {
        if searchText.isEmpty {
            return templates
        } else {
            return templates.filter { template in
                template.displayName.localizedCaseInsensitiveContains(searchText) ||
                template.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func addTemplate() {
        guard let template = selectedTemplate else { return }

        do {
            try PlanStore.shared.appendDayFromTemplate(planID: planID, template: template)
            onComplete()
            dismiss()
        } catch {
            errorMessage = "Failed to add template: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: TemplateDay
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Button(action: onSelect) {
                        Text(template.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(isSelected ? .blue : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }

                if let videoURL = template.videoURL {
                    Link(destination: URL(string: videoURL)!) {
                        Label("Open Video", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.top, -2)
                }

                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("\(template.segments.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let source = template.sourceName {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(source)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Show exercise list
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(template.segments.enumerated()), id: \.offset) { index, segment in
                                HStack(spacing: 4) {
                                    Text("\(index + 1).")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)

                                    Text(exerciseName(from: segment.exerciseCode))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text("•")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)

                                    Text("\(segment.sets) × \(segment.repsMin)-\(segment.repsMax)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    private func exerciseName(from code: String) -> String {
        // Convert exercise code to readable name
        // ROW.BB.BENT -> Barbell Bent-Over Row
        let parts = code.split(separator: ".")
        return parts.reversed().joined(separator: " ").capitalized
    }
}
