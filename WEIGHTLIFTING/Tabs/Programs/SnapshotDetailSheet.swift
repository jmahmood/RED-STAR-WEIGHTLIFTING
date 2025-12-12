import SwiftUI

/// Sheet for viewing snapshot details and confirming restoration
struct SnapshotDetailSheet: View {
    let planID: String
    let programName: String
    let snapshot: SnapshotMetadata

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var exportStore: ExportInboxStore

    @State private var showingConfirmation = false
    @State private var isRestoring = false
    @State private var restoreError: String?
    @State private var planDetails: PlanV03?

    var body: some View {
        NavigationStack {
            Form {
                snapshotInfoSection
                planInfoSection
                explanationSection

                if let error = restoreError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Restore Program Version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Restore This Version") {
                        showingConfirmation = true
                    }
                    .disabled(isRestoring || planDetails == nil)
                    .fontWeight(.semibold)
                }
            }
            .alert("Confirm Restore", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restore", role: .destructive) {
                    performRestore()
                }
            } message: {
                if let timestamp = snapshot.timestamp {
                    Text("Are you sure you want to restore the program to its state from \(formatDate(timestamp))? The current version will be saved as a backup.")
                }
            }
            .task {
                loadPlanDetails()
            }
        }
    }

    private var snapshotInfoSection: some View {
        Section("Snapshot Information") {
            if let timestamp = snapshot.timestamp {
                LabeledContent("Saved on") {
                    Text(formatDate(timestamp))
                        .foregroundStyle(.secondary)
                }
            }

            if let size = snapshot.fileSize {
                LabeledContent("File size") {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var planInfoSection: some View {
        Group {
            if let plan = planDetails {
                Section("Program Details") {
                    LabeledContent("Program Name", value: plan.planName)
                    LabeledContent("Training Days", value: "\(plan.days.count)")
                    LabeledContent("Unit", value: plan.unit.rawValue.uppercased())
                }
            } else {
                Section {
                    ProgressView("Loading details...")
                }
            }
        }
    }

    private var explanationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Restoring this version will:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Back up the current program as a snapshot", systemImage: "checkmark")
                    Label("Replace the current program with this version", systemImage: "checkmark")
                    Label("Update the version sent to Apple Watch on the next sync", systemImage: "checkmark")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func loadPlanDetails() {
        do {
            let detail = try PlanStore.shared.getSnapshotDetail(snapshotURL: snapshot.url)
            planDetails = detail.plan
            restoreError = nil
        } catch {
            if let storeError = error as? PlanStoreError {
                switch storeError {
                case .snapshotNotFound:
                    restoreError = "This version could not be found. It may have been deleted."
                case .invalidSnapshot:
                    restoreError = "This snapshot is corrupted and cannot be restored."
                default:
                    restoreError = "Could not load snapshot details: \(error.localizedDescription)"
                }
            } else {
                restoreError = "Could not load snapshot details: \(error.localizedDescription)"
            }
            planDetails = nil
        }
    }

    private func performRestore() {
        isRestoring = true
        restoreError = nil

        Task {
            do {
                // Restore via PlanStore (will create backup automatically)
                try PlanStore.shared.restoreSnapshot(planID: planID, snapshotURL: snapshot.url)

                // Reload plan library to reflect changes
                exportStore.reloadPlanLibrary()

                // Dismiss sheet
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    if let storeError = error as? PlanStoreError {
                        switch storeError {
                        case .snapshotNotFound:
                            restoreError = "This version could not be found. It may have been deleted."
                        case .invalidSnapshot:
                            restoreError = "This saved version is no longer compatible and cannot be restored."
                        default:
                            restoreError = "Could not restore version: \(error.localizedDescription)"
                        }
                    } else {
                        restoreError = "Could not restore version: \(error.localizedDescription)"
                    }
                    isRestoring = false
                }
            }
        }
    }
}
