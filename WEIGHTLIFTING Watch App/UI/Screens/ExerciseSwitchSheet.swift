//
//  ExerciseSwitchSheet.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-28.
//

import SwiftUI

struct ExerciseSwitchOption: Identifiable, Hashable {
    enum Source {
        case altGroup
        case recent
    }

    let code: String
    let title: String
    let subtitle: String?
    let source: Source

    var id: String { code }
}

struct ExerciseSwitchSheet: View {
    let currentName: String
    let currentCode: String
    let altOptions: [ExerciseSwitchOption]
    let recentOptions: [ExerciseSwitchOption]
    let onApply: (String, ExerciseSwitchScope) -> Void
    let onCancel: () -> Void

    @State private var selection: String

    init(
        currentName: String,
        currentCode: String,
        altOptions: [ExerciseSwitchOption],
        recentOptions: [ExerciseSwitchOption],
        onApply: @escaping (String, ExerciseSwitchScope) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.currentName = currentName
        self.currentCode = currentCode
        self.altOptions = altOptions
        self.recentOptions = recentOptions
        self.onApply = onApply
        self.onCancel = onCancel
        _selection = State(initialValue: currentCode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if altOptions.isEmpty && recentOptions.isEmpty {
                    Text("No alternates or recent history available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    if !altOptions.isEmpty {
                        section(title: "Alt Group", options: altOptions)
                    }

                    if !recentOptions.isEmpty {
                        section(title: "Recents", options: recentOptions)
                    }
                }

                actionButtons
                cancelButton
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Switch Exercise")
                .font(.headline)
            Text(currentName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                onApply(selection, .remaining)
            } label: {
                Text("Apply to Remaining")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                onApply(selection, .thisSet)
            } label: {
                Text("This set only")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var cancelButton: some View {
        Button("Cancel", role: .cancel, action: onCancel)
            .buttonStyle(.plain)
            .padding(.bottom, 4)
    }

    private func section(title: String, options: [ExerciseSwitchOption]) -> some View {
        let rows = options.enumerated().map(OptionEntry.init)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(rows) { entry in
                row(for: entry.option)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(for option: ExerciseSwitchOption) -> some View {
        Button {
            selection = option.code
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selection == option.code {
                    Image(systemName: "checkmark")
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selection == option.code ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }

    private struct OptionEntry: Identifiable {
        let index: Int
        let option: ExerciseSwitchOption
        var id: Int { index }
    }
}

#Preview {
    let alt = ExerciseSwitchOption(code: "PRESS.MACH.CHEST", title: "Machine Chest Press", subtitle: nil, source: .altGroup)
    let recent = ExerciseSwitchOption(code: "PRESS.DB.FLAT", title: "Flat Dumbbell Press", subtitle: "Prev 50 lb × 8 • Sep 12", source: .recent)
    return ExerciseSwitchSheet(
        currentName: "Flat Dumbbell Press",
        currentCode: "PRESS.DB.FLAT",
        altOptions: [alt],
        recentOptions: [recent],
        onApply: { _, _ in },
        onCancel: {}
    )
}

