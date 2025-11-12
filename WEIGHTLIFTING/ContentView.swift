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
    @State private var shareItem: ShareItem?
    @State private var isImportingLifts = false
    @State private var isImportingPlan = false
    @State private var alertItem: AlertItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    InsightsView(snapshot: inbox.insights)

                    LiftsLibrarySection(
                        state: inbox.liftsLibrary,
                        importAction: { isImportingLifts = true },
                        transferAction: sendLiftsToWatch
                    )

                    PlanLibrarySection(
                        state: inbox.planLibrary,
                        importAction: { isImportingPlan = true },
                        transferAction: sendPlanToWatch
                    )

                    Divider()

                    if let snapshot = inbox.latestFile {
                        ExportDetailCard(snapshot: snapshot) {
                            shareItem = ShareItem(url: snapshot.fileURL)
                        }
                    } else {
                        EmptyInboxView()
                    }

                    if inbox.history.count > 1 {
                        Divider()
                        Text("Recent Exports")
                            .font(.headline)
                        RecentExportsList(
                            snapshots: Array(inbox.history.dropFirst()),
                            onShare: { snapshot in
                                shareItem = ShareItem(url: snapshot.fileURL)
                            }
                        )
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Export Inbox")
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.url])
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
    }

    private func sendLiftsToWatch() {
        do {
            try inbox.transferLiftsToWatch()
        } catch {
            present(error, title: "Unable to Transfer Lifts")
        }
    }

    private func sendPlanToWatch() {
        do {
            try inbox.transferPlanToWatch()
        } catch {
            present(error, title: "Unable to Transfer Plan")
        }
    }

    private func present(_ error: Error, title: String) {
        if let userFacing = error as? UserFacingError {
            alertItem = AlertItem(title: title, message: userFacing.message)
        } else {
            alertItem = AlertItem(title: title, message: error.localizedDescription)
        }
    }
}

private struct ExportDetailCard: View {
    let snapshot: ExportedSnapshot
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSV Export Ready")
                .font(.title3)
                .bold()
            Text(snapshot.fileName)
                .font(.footnote)
                .foregroundStyle(.secondary)

            InfoRow(title: "Rows", value: "\(snapshot.rows)")
            InfoRow(title: "Size", value: snapshot.sizeLabel)
            InfoRow(title: "Received", value: DateFormatter.shortFormatter.string(from: snapshot.receivedAt))
            InfoRow(title: "Schema", value: snapshot.schema)

            Button("Share / Save to Files", action: onShare)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
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
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)

                if index < snapshots.count - 1 {
                    Divider()
                }
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

private struct LiftsLibrarySection: View {
    let state: LiftsLibraryState
    let importAction: () -> Void
    let transferAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global CSV")
                .font(.headline)

            if let stats = state.stats {
                InfoRow(title: "Rows", value: "\(stats.rows)")
                InfoRow(title: "Size", value: LiftsLibrarySection.sizeFormatter.string(fromByteCount: Int64(stats.sizeBytes)))
                if let importedAt = state.lastImportedAt {
                    InfoRow(title: "Imported", value: importedAt.formatted(.relative(presentation: .named)))
                }
            } else if let error = state.importError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("Import a lifts.csv snapshot to update the data your watch uses.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TransferStatusView(status: state.transferStatus)

            HStack {
                Button("Import lifts.csv", action: importAction)
                    .buttonStyle(.bordered)

                Spacer()

                Button("Send to Watch", action: transferAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.isReadyForTransfer || isBusy)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    private var isBusy: Bool {
        switch state.transferStatus.phase {
        case .preparing, .queued, .inProgress:
            return true
        default:
            return false
        }
    }
}

private struct PlanLibrarySection: View {
    let state: PlanLibraryState
    let importAction: () -> Void
    let transferAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Plan")
                .font(.headline)

            if let summary = state.summary {
                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.planName)
                        .font(.title3)
                        .bold()
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
                                Label(warning, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            } else if let error = state.importError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("Load a validated plan JSON file to update the workout deck on your watch.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let importedAt = state.lastImportedAt {
                Text("Imported \(importedAt.formatted(.relative(presentation: .named))).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            TransferStatusView(status: state.transferStatus)

            HStack {
                Button("Import Plan", action: importAction)
                    .buttonStyle(.bordered)

                Spacer()

                Button("Send to Watch", action: transferAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.isReadyForTransfer || isBusy)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private var isBusy: Bool {
        switch state.transferStatus.phase {
        case .preparing, .queued, .inProgress:
            return true
        default:
            return false
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
        switch status.phase {
        case .completed:
            return false
        default:
            return true
        }
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

private extension DateFormatter {
    static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

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
