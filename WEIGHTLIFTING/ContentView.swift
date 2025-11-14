//
//  ContentView.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-30.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var inbox: ExportInboxStore
    @AppStorage("exportInbox.hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var shareItem: ShareItem?
    @State private var isImportingLifts = false
    @State private var isImportingPlan = false
    @State private var isImportSheetPresented = false
    @State private var showOnboardingOverlay = false
    @State private var alertItem: AlertItem?
    @State private var isSyncingAll = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    QuietHeaderView(
                        title: "Welcome back.",
                        subtitle: "Ready to sync your latest data or preview your next workout."
                    )

                    SyncCenterCard(
                        summary: syncSummary,
                        isSyncing: isSyncingAll || isAnyTransferBusy,
                        onSyncAll: syncAll,
                        onImport: { isImportSheetPresented = true },
                        onHelp: presentSyncHelp
                    )

                    ImportSectionView(
                        title: "Global CSV",
                        help: "Your watch uses this for exercise metadata.",
                        state: csvState,
                        stats: inbox.liftsLibrary.stats,
                        lastImportedAt: inbox.liftsLibrary.lastImportedAt,
                        transferStatus: inbox.liftsLibrary.transferStatus,
                        importTitle: "Import CSV",
                        sendTitle: "Send",
                        importAction: startCSVImport,
                        sendAction: sendLiftsToWatch,
                        isSendEnabled: inbox.liftsLibrary.isReadyForTransfer && !isTransferBusy(inbox.liftsLibrary.transferStatus)
                    )

                    WorkoutPlanSection(
                        state: planState,
                        plan: inbox.planLibrary,
                        importAction: startPlanImport,
                        sendAction: sendPlanToWatch
                    )

                    NextWorkoutPanel(
                        state: inbox.insights.nextWorkout,
                        onImportPlan: startPlanImport
                    )

                    PersonalRecordsSection(
                        state: inbox.insights.personalRecords,
                        onReimport: startCSVImport
                    )

                    ExportHistorySection(
                        latestSnapshot: inbox.latestFile,
                        history: inbox.history,
                        onShare: { shareItem = ShareItem(url: $0.fileURL) }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
            .navigationTitle("Export Inbox")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                FloatingImportButton(action: { isImportSheetPresented = true })
                    .padding()
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.url])
        }
        .sheet(isPresented: $isImportSheetPresented) {
            ImportSheet(
                onCSV: {
                    isImportSheetPresented = false
                    startCSVImport()
                },
                onPlan: {
                    isImportSheetPresented = false
                    startPlanImport()
                },
                onPR: {
                    isImportSheetPresented = false
                    startCSVImport()
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isImportingLifts) {
            DocumentPicker(
                allowedContentTypes: [.commaSeparatedText, .text, .data],
                allowsMultipleSelection: false,
                onPick: { url in
                    isImportingLifts = false
                    Task {
                        do {
                            try await inbox.importLiftsCSV(from: url)
                        } catch {
                            await MainActor.run {
                                present(error, title: "Lifts Import Failed")
                            }
                        }
                    }
                },
                onCancel: {
                    isImportingLifts = false
                }
            )
        }
        .sheet(isPresented: $isImportingPlan) {
            DocumentPicker(
                allowedContentTypes: [.json, .data],
                allowsMultipleSelection: false,
                onPick: { url in
                    isImportingPlan = false
                    Task {
                        do {
                            try await inbox.importWorkoutPlan(from: url)
                        } catch {
                            await MainActor.run {
                                present(error, title: "Plan Import Failed")
                            }
                        }
                    }
                },
                onCancel: {
                    isImportingPlan = false
                }
            )
        }
        .alert(item: $alertItem) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .task {
            inbox.requestNotificationAuthorization()
        }
        .onAppear {
            if !hasSeenOnboarding {
                showOnboardingOverlay = true
            }
        }
        .overlay {
            if showOnboardingOverlay {
                OnboardingOverlay {
                    hasSeenOnboarding = true
                    withAnimation(.spring()) {
                        showOnboardingOverlay = false
                    }
                }
            }
        }
    }

    private var csvState: DataState {
        DataState.make(for: inbox.liftsLibrary)
    }

    private var planState: DataState {
        DataState.make(for: inbox.planLibrary)
    }

    private var prState: DataState {
        let snapshot = inbox.insights
        switch snapshot.personalRecords {
        case .loading:
            return .progress(description: "Preparing insights…")
        case .empty(let message):
            return .notLoaded(description: message)
        case .error:
            return .error(description: "PR snapshot couldn’t be read.")
        case .ready:
            return .ready(updatedAt: snapshot.generatedAt, description: "Insights updated")
        }
    }

    private var syncSummary: SyncSummary {
        SyncSummary(csv: csvState, pr: prState, plan: planState)
    }

    private var isAnyTransferBusy: Bool {
        isTransferBusy(inbox.liftsLibrary.transferStatus) || isTransferBusy(inbox.planLibrary.transferStatus)
    }

    private func startCSVImport() {
        isImportingLifts = true
    }

    private func startPlanImport() {
        isImportingPlan = true
    }

    private func syncAll() {
        guard syncSummary.canSyncAnything, !isSyncingAll else { return }
        isSyncingAll = true
        defer { isSyncingAll = false }
        if inbox.liftsLibrary.isReadyForTransfer {
            sendLiftsToWatch()
        }
        if inbox.planLibrary.isReadyForTransfer {
            sendPlanToWatch()
        }
    }

    private func sendLiftsToWatch() {
        do {
            try inbox.transferLiftsToWatch()
        } catch {
            present(error, title: "Unable to Send CSV")
        }
    }

    private func sendPlanToWatch() {
        do {
            try inbox.transferPlanToWatch()
        } catch {
            present(error, title: "Unable to Send Plan")
        }
    }

    private func presentSyncHelp() {
        alertItem = AlertItem(
            title: "Sync tips",
            message: "Import a CSV or Plan, then choose Send. “Sync All” only sends items that are ready."
        )
    }

    private func present(_ error: Error, title: String) {
        if let userFacing = error as? UserFacingError {
            alertItem = AlertItem(title: title, message: userFacing.message)
        } else {
            alertItem = AlertItem(title: title, message: error.localizedDescription)
        }
    }

    private func isTransferBusy(_ status: TransferStatus) -> Bool {
        switch status.phase {
        case .preparing, .queued, .inProgress:
            return true
        default:
            return false
        }
    }
}

// MARK: - Dashboard Sections

private struct QuietHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SyncCenterCard: View {
    let summary: SyncSummary
    let isSyncing: Bool
    var onSyncAll: () -> Void
    var onImport: () -> Void
    var onHelp: () -> Void

    var body: some View {
        DashboardCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Sync Center")
                    .font(.headline)
                Spacer()
                if isSyncing {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            VStack(spacing: 10) {
                SyncStatusRow(label: "Global CSV", state: summary.csv)
                SyncStatusRow(label: "PR Snapshot", state: summary.pr)
                SyncStatusRow(label: "Workout Plan", state: summary.plan)
            }
            HStack(spacing: 12) {
                Button("Sync All", action: onSyncAll)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSyncing || !summary.canSyncAnything)
                Button("Import", action: onImport)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Help", action: onHelp)
                    .buttonStyle(.borderless)
            }
        }
    }
}

private struct SyncStatusRow: View {
    let label: String
    let state: DataState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.iconName)
                .foregroundStyle(state.tint)
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(state.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ImportSectionView: View {
    let title: String
    let help: String
    let state: DataState
    let stats: CsvQuickStats?
    let lastImportedAt: Date?
    let transferStatus: TransferStatus
    let importTitle: String
    let sendTitle: String
    let importAction: () -> Void
    let sendAction: () -> Void
    let isSendEnabled: Bool

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        DashboardCard {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                TagView(text: state.tagLabel, tint: state.tint)
            }
            Text(help)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let stats {
                InfoRow(title: "Rows", value: "\(stats.rows)")
                InfoRow(title: "Size", value: ImportSectionView.sizeFormatter.string(fromByteCount: Int64(stats.sizeBytes)))
            }
            if let lastImportedAt {
                InfoRow(title: "Imported", value: lastImportedAt.formatted(.relative(presentation: .named)))
            }

            StateLine(state: state)
            TransferStatusView(status: transferStatus)

            HStack(spacing: 12) {
                Button(importTitle, action: importAction)
                    .buttonStyle(.bordered)

                Button(sendTitle, action: sendAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isSendEnabled)
            }
        }
    }
}

private struct WorkoutPlanSection: View {
    let state: DataState
    let plan: PlanLibraryState
    let importAction: () -> Void
    let sendAction: () -> Void

    var body: some View {
        CollapsibleCard(
            title: "Workout Plan",
            summary: state.summary,
            initiallyExpanded: state.requiresAttention,
            expanded: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Load a validated plan JSON to preview workouts on the watch.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let summary = plan.summary {
                        PlanSummaryView(summary: summary)
                    }

                    if let error = plan.importError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if let importedAt = plan.lastImportedAt {
                        Text("Imported \(importedAt.formatted(.relative(presentation: .named))).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TransferStatusView(status: plan.transferStatus)

                    HStack(spacing: 12) {
                        Button("Import Plan", action: importAction)
                            .buttonStyle(.bordered)
                        Button("Send", action: sendAction)
                            .buttonStyle(.borderedProminent)
                            .disabled(!plan.isReadyForTransfer || isTransferBusy(plan.transferStatus))
                    }
                }
            },
            collapsed: {
                HStack {
                    Text(state.collapsedDescription)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Import Plan", action: importAction)
                        .buttonStyle(.bordered)
                }
            }
        )
    }

    private func isTransferBusy(_ status: TransferStatus) -> Bool {
        switch status.phase {
        case .preparing, .queued, .inProgress:
            return true
        default:
            return false
        }
    }
}

private struct PlanSummaryView: View {
    let summary: PlanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.planName)
                .font(.title3.weight(.semibold))
            InfoRow(title: "Days", value: "\(summary.dayCount)")
            InfoRow(title: "Unit", value: summary.unit.displaySymbol.uppercased())
            if !summary.scheduleOrder.isEmpty {
                Text("Schedule: \(summary.scheduleOrder.joined(separator: " → "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !summary.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(summary.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

private struct NextWorkoutPanel: View {
    let state: CardState<NextWorkoutDisplay>
    let onImportPlan: () -> Void

    var body: some View {
        CollapsibleCard(
            title: "Next Workout",
            summary: collapsedSummary,
            initiallyExpanded: needsAttention,
            expanded: {
                VStack(alignment: .leading, spacing: 12) {
                    switch state {
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    case .empty(let message):
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    case .error(let message):
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    case .ready(let display):
                        NextWorkoutDetailView(display: display)
                    }
                    Button("Import Plan", action: onImportPlan)
                        .buttonStyle(.bordered)
                }
            },
            collapsed: {
                HStack(alignment: .firstTextBaseline) {
                    Text(collapsedSummary)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Import Plan", action: onImportPlan)
                        .buttonStyle(.bordered)
                }
            }
        )
    }

    private var needsAttention: Bool {
        switch state {
        case .error, .empty:
            return true
        default:
            return false
        }
    }

    private var collapsedSummary: String {
        switch state {
        case .ready(let display):
            return "\(display.planName) • \(display.dayLabel) • \(display.lines.count) moves"
        case .loading:
            return "Loading preview…"
        case .empty:
            return "Not yet loaded"
        case .error:
            return "Needs import"
        }
    }
}

private struct NextWorkoutDetailView: View {
    let display: NextWorkoutDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(display.planName) • \(display.dayLabel)")
                .font(.headline)
            ForEach(display.lines) { line in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(line.name)
                        Spacer()
                        Text(line.targetReps)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if !line.badges.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(line.badges, id: \.self) { badge in
                                Text(badge)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.thinMaterial))
                            }
                        }
                    }
                }
                if line.id != display.lines.last?.id {
                    Divider()
                }
            }
            if display.remainingCount > 0 {
                Text("+\(display.remainingCount) more movements")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if display.timedSetsSkipped {
                Text("Timed sets skipped (not supported).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PersonalRecordsSection: View {
    let state: CardState<[PersonalRecordDisplay]>
    let onReimport: () -> Void
    private let dateFormatter = DateFormatter.shortStyle

    var body: some View {
        DashboardCard {
            HStack {
                Text("Personal Records")
                    .font(.headline)
                Spacer()
                TagView(text: badgeLabel, tint: badgeTint)
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
        case .empty(let message):
            Text(message)
                .foregroundStyle(.secondary)
        case .error:
            VStack(alignment: .leading, spacing: 8) {
                Text("PR snapshot couldn’t be read.")
                    .font(.body)
                Text("Try re-importing from the Watch export or CSV.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Re-Import", action: onReimport)
                    .buttonStyle(.bordered)
            }
        case .ready(let records):
            VStack(alignment: .leading, spacing: 14) {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(record.exerciseName)
                                .font(.headline)
                            if record.isNew {
                                Text("NEW")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.green.opacity(0.15)))
                            }
                        }
                        if let primary = record.primary {
                            HStack(spacing: 8) {
                                Text(primary.kind.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(InsightsFormatter.weight(value: primary.value, unit: record.unitSymbol))
                                    .font(.body.monospacedDigit())
                                Text(InsightsFormatter.setDetail(weight: primary.weight, reps: primary.reps, unit: record.unitSymbol))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(dateFormatter.string(from: primary.date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let message = record.missingPrimaryMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let secondary = record.secondary {
                            HStack(spacing: 8) {
                                Text(secondary.kind.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(InsightsFormatter.volume(value: secondary.value, unit: record.unitSymbol))
                                    .font(.footnote.monospacedDigit())
                                Text(InsightsFormatter.setDetail(weight: secondary.weight, reps: secondary.reps, unit: record.unitSymbol))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if record.id != records.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var badgeLabel: String {
        switch state {
        case .ready:
            return "Ready"
        case .error:
            return "Needs fix"
        case .loading:
            return "Loading"
        case .empty:
            return "Not loaded"
        }
    }

    private var badgeTint: Color {
        switch state {
        case .ready:
            return .green
        case .error:
            return .orange
        case .loading:
            return .secondary
        case .empty:
            return .secondary
        }
    }
}

private struct ExportHistorySection: View {
    let latestSnapshot: ExportedSnapshot?
    let history: [ExportedSnapshot]
    let onShare: (ExportedSnapshot) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if let snapshot = latestSnapshot {
                ExportDetailCard(snapshot: snapshot) {
                    onShare(snapshot)
                }
            } else {
                EmptyInboxView()
            }

            if history.count > 1 {
                DashboardCard {
                    Text("Recent Exports")
                        .font(.headline)
                    RecentExportsList(
                        snapshots: Array(history.dropFirst()),
                        onShare: onShare
                    )
                }
            }
        }
    }
}

private struct CollapsibleCard<Expanded: View, Collapsed: View>: View {
    let title: String
    let summary: String
    let expanded: () -> Expanded
    let collapsed: () -> Collapsed
    @State private var isExpanded: Bool

    init(title: String, summary: String, initiallyExpanded: Bool, @ViewBuilder expanded: @escaping () -> Expanded, @ViewBuilder collapsed: @escaping () -> Collapsed) {
        self.title = title
        self.summary = summary
        self.expanded = expanded
        self.collapsed = collapsed
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        DashboardCard {
            Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                expanded()
            } else {
                collapsed()
            }
        }
    }
}

private struct StateLine: View {
    let state: DataState

    var body: some View {
        Text(state.detail)
            .font(.subheadline)
            .foregroundStyle(state.tint)
    }
}

private struct TagView: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(tint.opacity(0.15))
            )
            .foregroundStyle(tint)
    }
}

private struct FloatingImportButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 6, y: 3)
        }
        .accessibilityLabel("Add import")
    }
}

private struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCSV: () -> Void
    var onPlan: () -> Void
    var onPR: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Import from Files") {
                    Button("Global CSV (lifts.csv)", action: onCSV)
                    Button("Workout Plan (plan.json)", action: onPlan)
                    Button("PR Snapshot", action: onPR)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct OnboardingOverlay: View {
    var dismiss: () -> Void
    @State private var index = 0
    private let steps = [
        "Import your lift log (CSV).",
        "Load a plan to preview workouts.",
        "Send data to your watch when ready."
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                TabView(selection: $index) {
                    ForEach(steps.indices, id: \.self) { idx in
                        VStack(spacing: 12) {
                            Text("Step \(idx + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(steps[idx])
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .tag(idx)
                    }
                }
                .frame(height: 180)
                .tabViewStyle(.page(indexDisplayMode: .always))
                Button("Get Started", action: dismiss)
                    .buttonStyle(.borderedProminent)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.regularMaterial)
            )
            .padding()
        }
    }
}

// MARK: - Existing reusable views

private struct ExportDetailCard: View {
    let snapshot: ExportedSnapshot
    let onShare: () -> Void

    var body: some View {
        DashboardCard {
            Text("CSV Export Ready")
                .font(.headline)
            Text(snapshot.fileName)
                .font(.footnote)
                .foregroundStyle(.secondary)

            InfoRow(title: "Rows", value: "\(snapshot.rows)")
            InfoRow(title: "Size", value: snapshot.sizeLabel)
            InfoRow(title: "Received", value: DateFormatter.shortFormatter.string(from: snapshot.receivedAt))
            InfoRow(title: "Schema", value: snapshot.schema)

            Button("Share or Save", action: onShare)
                .buttonStyle(.bordered)
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout)
        }
    }
}

private struct EmptyInboxView: View {
    var body: some View {
        DashboardCard {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No exports yet")
                    .font(.headline)
                Text("Use the Export option on your watch to send a CSV snapshot.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct RecentExportsList: View {
    let snapshots: [ExportedSnapshot]
    let onShare: (ExportedSnapshot) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(snapshots.enumerated()), id: \.element.id) { entry in
                let snapshot = entry.element
                let index = entry.offset
                Button {
                    onShare(snapshot)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.fileName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(snapshot.receivedAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(snapshot.sizeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if index < snapshots.count - 1 {
                    Divider()
                }
            }
        }
    }
}

private struct TransferStatusView: View {
    let status: TransferStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch status.phase {
            case .idle:
                if status.lastSuccessAt == nil {
                    Text("Ready to sync.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .preparing:
                StatusRow(icon: nil, isProgress: true, text: "Preparing file…", tint: .secondary)
            case .queued(let date):
                StatusRow(
                    icon: nil,
                    isProgress: true,
                    text: "Waiting for Watch (\(date.formatted(.relative(presentation: .named))))",
                    tint: .secondary
                )
            case .inProgress:
                StatusRow(icon: nil, isProgress: true, text: "Transferring…", tint: .secondary)
            case .completed(let date):
                StatusRow(icon: "checkmark.circle.fill", isProgress: false, text: "Sent \(date.formatted(.relative(presentation: .named))).", tint: .green)
            case .failed(let message):
                StatusRow(icon: "exclamationmark.triangle.fill", isProgress: false, text: "Transfer failed: \(message)", tint: .orange)
            }

            if let lastSuccess = status.lastSuccessAt, shouldShowLastSuccessReminder {
                Text("Last sent \(lastSuccess.formatted(.relative(presentation: .named))).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shouldShowLastSuccessReminder: Bool {
        guard status.lastSuccessAt != nil else { return false }
        if case .completed = status.phase {
            return false
        }
        return true
    }

    private struct StatusRow: View {
        let icon: String?
        let isProgress: Bool
        let text: String
        let tint: Color

        var body: some View {
            HStack(spacing: 8) {
                if isProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                }
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// Existing DocumentPicker implementation
private struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = allowsMultipleSelection
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: DocumentPicker

        init(parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onCancel()
                return
            }
            parent.onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}

// MARK: - Presentation helpers

private enum DataState: Equatable {
    case notLoaded(description: String)
    case ready(updatedAt: Date?, description: String)
    case error(description: String)
    case progress(description: String)

    static func make(for lifts: LiftsLibraryState) -> DataState {
        if let error = lifts.importError {
            return .error(description: error)
        }
        switch lifts.transferStatus.phase {
        case .preparing:
            return .progress(description: "Preparing…")
        case .queued:
            return .progress(description: "Queued for Watch")
        case .inProgress:
            return .progress(description: "Sending…")
        case .failed(let message):
            return .error(description: message)
        default:
            break
        }
        if lifts.isReadyForTransfer {
            return .ready(updatedAt: lifts.lastImportedAt, description: "Up to date")
        }
        return .notLoaded(description: "Not loaded")
    }

    static func make(for plan: PlanLibraryState) -> DataState {
        if let error = plan.importError {
            return .error(description: error)
        }
        switch plan.transferStatus.phase {
        case .preparing:
            return .progress(description: "Preparing…")
        case .queued:
            return .progress(description: "Queued for Watch")
        case .inProgress:
            return .progress(description: "Sending…")
        case .failed(let message):
            return .error(description: message)
        default:
            break
        }
        if plan.isReadyForTransfer {
            return .ready(updatedAt: plan.lastImportedAt, description: "Ready")
        }
        return .notLoaded(description: "Not loaded")
    }

    var summary: String {
        switch self {
        case .ready(let updatedAt, let description):
            if let updatedAt, let relative = relativeFormatter.localizedString(for: updatedAt, relativeTo: Date()).capitalizedFirstLetter {
                return "\(description) • \(relative)"
            }
            return description
        case .notLoaded(let description):
            return description
        case .error:
            return "Needs attention"
        case .progress(let description):
            return description
        }
    }

    var detail: String {
        switch self {
        case .ready(let date, let description):
            if let date {
                let relative = relativeFormatter.localizedString(for: date, relativeTo: Date())
                return "\(description). Updated \(relative)."
            }
            return description
        case .notLoaded(let description):
            return description
        case .error(let description):
            return description
        case .progress(let description):
            return description
        }
    }

    var tagLabel: String {
        switch self {
        case .ready:
            return "Ready"
        case .notLoaded:
            return "Not loaded"
        case .error:
            return "Needs fix"
        case .progress:
            return "Syncing"
        }
    }

    var tint: Color {
    switch self {
        case .ready:
            return .green
        case .notLoaded:
            return .secondary
        case .error:
            return .orange
        case .progress:
            return .blue
        }
    }

    var iconName: String {
        switch self {
        case .ready:
            return "checkmark.circle"
        case .notLoaded:
            return "circle.dashed"
        case .error:
            return "exclamationmark.triangle"
        case .progress:
            return "arrow.triangle.2.circlepath"
        }
    }

    var collapsedDescription: String {
        switch self {
        case .ready:
            return "Ready to sync"
        case .notLoaded:
            return "Not loaded"
        case .error(let description):
            return description
        case .progress(let description):
            return description
        }
    }

    var requiresAttention: Bool {
        switch self {
        case .error, .notLoaded:
            return true
        default:
            return false
        }
    }

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

private struct SyncSummary {
    let csv: DataState
    let pr: DataState
    let plan: DataState

    var canSyncAnything: Bool {
        csv.isReady || plan.isReady
    }
}

private let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

private extension String {
    var capitalizedFirstLetter: String? {
        guard let first = first else { return nil }
        return String(first).uppercased() + String(dropFirst())
    }
}

extension DateFormatter {
    static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let shortStyle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}
