import SwiftUI

/// Displays the history of snapshots for a program
struct ProgramHistoryView: View {
    let planID: String
    let programName: String

    @State private var snapshots: [SnapshotMetadata] = []
    @State private var loadError: String?
    @State private var selectedSnapshot: SnapshotMetadata?
    @State private var snapshotNames: [URL: String] = [:]

    var body: some View {
        Group {
            if let loadError {
                errorStateView(loadError)
            } else if snapshots.isEmpty {
                emptyStateView
            } else {
                snapshotList
            }
        }
        .navigationTitle("Program History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSnapshot) { snapshot in
            SnapshotDetailSheet(
                planID: planID,
                programName: programName,
                snapshot: snapshot
            )
        }
        .task {
            loadSnapshots()
        }
    }

    private var snapshotList: some View {
        List {
            Section {
                Text("View previously saved versions of this program. Restoring a version will back up the current one first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Previous Versions") {
                ForEach(snapshots) { snapshot in
                    SnapshotRow(snapshot: snapshot, planName: snapshotNames[snapshot.url] ?? programName)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSnapshot = snapshot
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 40, weight: .semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                loadSnapshots()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Previous Versions")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Snapshots are created when edits are made to this program.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadSnapshots() {
        do {
            snapshots = try PlanStore.shared.listSnapshots(planID: planID)
            loadError = nil
            snapshotNames = [:]

            for snapshot in snapshots {
                if let name = snapshotPlanName(snapshot.url) {
                    snapshotNames[snapshot.url] = name
                }
            }
        } catch {
            loadError = "Failed to load history: \(error.localizedDescription)"
            snapshots = []
        }
    }

    private func snapshotPlanName(_ url: URL) -> String? {
        if let detail = try? PlanStore.shared.getSnapshotDetail(snapshotURL: url) {
            return detail.plan.planName
        }

        // Fallback: decode just the plan name without full validation to show something meaningful
        if let data = try? Data(contentsOf: url),
           let plan = try? JSONDecoder().decode(PlanV03.self, from: data) {
            return plan.planName
        }

        return nil
    }
}

/// Row displaying a single snapshot
struct SnapshotRow: View {
    let snapshot: SnapshotMetadata
    let planName: String

    private var formattedDate: String {
        guard let timestamp = snapshot.timestamp else {
            return "Unknown date"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    private var formattedSize: String {
        guard let size = snapshot.fileSize else {
            return "Unknown size"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(planName)
                .font(.body)
                .fontWeight(.semibold)

            Text(formattedDate)
                .font(.subheadline)

            Text(formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
