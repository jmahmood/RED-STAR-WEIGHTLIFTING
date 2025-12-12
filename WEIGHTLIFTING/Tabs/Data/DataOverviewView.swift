import SwiftUI
import UniformTypeIdentifiers

/// Data tab showing sync status, exports, imports, and diagnostics
struct DataOverviewView: View {
    @EnvironmentObject private var exportStore: ExportInboxStore
    @State private var showingCSVPicker = false
    @State private var showingPlanPicker = false
    @State private var csvRowCount: Int = 0
    @State private var csvFileSize: String = ""
    @State private var shareItem: ShareItem?

    var body: some View {
        List {
            // Sync status section
            Section("Sync Status") {
                LabeledContent("CSV Transfer") {
                    Text(csvTransferStatusText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(csvTransferColor.opacity(0.2))
                        .foregroundColor(csvTransferColor)
                        .cornerRadius(8)
                }

                LabeledContent("Plan Transfer") {
                    Text(planTransferStatusText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(planTransferColor.opacity(0.2))
                        .foregroundColor(planTransferColor)
                        .cornerRadius(8)
                }

                LabeledContent("Last Watch Sync") {
                    if let lastSync = exportStore.lastWatchSyncDate {
                        Text(lastSync.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // CSV data section
            Section("Workout Data") {
                LabeledContent("Total Rows", value: "\(csvRowCount)")
                LabeledContent("File Size", value: csvFileSize)
            }

            // Import section
            Section("Import") {
                Button {
                    showingCSVPicker = true
                } label: {
                    Label("Import Workout CSV", systemImage: "square.and.arrow.down")
                }

                Button {
                    showingPlanPicker = true
                } label: {
                    Label("Import Program", systemImage: "doc.badge.plus")
                }
            }

            // Sync to Watch section
            Section("Sync to Watch") {
                Button {
                    sendCSVToWatch()
                } label: {
                    Label("Send CSV to Watch", systemImage: "applewatch.radiowaves.left.and.right")
                }
                .disabled(!exportStore.liftsLibrary.isReadyForTransfer || isCSVTransferBusy)

                Button {
                    sendPlanToWatch()
                } label: {
                    Label("Send Program to Watch", systemImage: "applewatch")
                }
                .disabled(!exportStore.planLibrary.isReadyForTransfer || isPlanTransferBusy)
            }

            // Export section
            Section("Export") {
                Button {
                    exportCSV()
                } label: {
                    Label("Export Workout CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(exportStore.liftsLibrary.fileURL == nil)
            }

            // Stored links section
            Section("Stored Links") {
                NavigationLink(value: DataDestination.storedLinks) {
                    Label("Stored Links", systemImage: "bookmark")
                }
            }

            // Diagnostics section
            Section("Diagnostics") {
                LabeledContent("App Version", value: appVersion)
                LabeledContent("CSV Schema", value: SchemaVersions.csv)
                LabeledContent("Plan Schema", value: SchemaVersions.plan)

                NavigationLink(value: DataDestination.diagnostics) {
                    Label("View Diagnostics", systemImage: "wrench.and.screwdriver")
                }
            }
        }
        .navigationTitle("Data")
        .sheet(isPresented: $showingCSVPicker) {
            DocumentPickerView(contentTypes: [.commaSeparatedText, .text]) { urls in
                guard let url = urls.first else { return }
                importCSV(from: url)
            }
        }
        .sheet(isPresented: $showingPlanPicker) {
            DocumentPickerView(contentTypes: [.json]) { urls in
                guard let url = urls.first else { return }
                importPlan(from: url)
            }
        }
        .task {
            loadCSVInfo()
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.url])
        }
    }

    private var csvTransferStatusText: String {
        exportStore.liftsLibrary.transferStatus.phase.displayText
    }

    private var csvTransferColor: Color {
        exportStore.liftsLibrary.transferStatus.phase.tint
    }

    private var planTransferStatusText: String {
        exportStore.planLibrary.transferStatus.phase.displayText
    }

    private var planTransferColor: Color {
        exportStore.planLibrary.transferStatus.phase.tint
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var isCSVTransferBusy: Bool {
        exportStore.liftsLibrary.transferStatus.phase.isBusy
    }

    private var isPlanTransferBusy: Bool {
        exportStore.planLibrary.transferStatus.phase.isBusy
    }

    private func loadCSVInfo() {
        let csvURL = StoragePaths.makeDefault().globalCSVURL

        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            return
        }

        // Count rows
        if let content = try? String(contentsOf: csvURL) {
            csvRowCount = content.components(separatedBy: .newlines).count - 1 // Subtract header
        }

        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: csvURL.path),
           let size = attributes[.size] as? Int64 {
            csvFileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }

    private func importCSV(from url: URL) {
        Task {
            do {
                try await exportStore.importLiftsCSV(from: url)
                loadCSVInfo()
            } catch {
                print("Failed to import CSV: \(error)")
            }
        }
    }

    private func importPlan(from url: URL) {
        Task {
            do {
                try await exportStore.importWorkoutPlan(from: url)
            } catch {
                print("Failed to import plan: \(error)")
            }
        }
    }

    private func sendCSVToWatch() {
        do {
            try exportStore.transferLiftsToWatch()
        } catch {
            print("Failed to send CSV to watch: \(error)")
        }
    }

    private func sendPlanToWatch() {
        do {
            try exportStore.transferPlanToWatch()
        } catch {
            print("Failed to send plan to watch: \(error)")
        }
    }

    private func exportCSV() {
        guard let csvURL = exportStore.liftsLibrary.fileURL else { return }
        shareItem = ShareItem(url: csvURL)
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}
