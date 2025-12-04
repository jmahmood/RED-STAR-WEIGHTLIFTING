import SwiftUI
import UniformTypeIdentifiers

/// Data tab showing sync status, exports, imports, and diagnostics
struct DataOverviewView: View {
    @EnvironmentObject private var exportStore: ExportInboxStore
    @State private var showingCSVPicker = false
    @State private var showingPlanPicker = false
    @State private var csvRowCount: Int = 0
    @State private var csvFileSize: String = ""

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

            // Diagnostics section
            Section("Diagnostics") {
                LabeledContent("App Version", value: appVersion)
                LabeledContent("CSV Schema", value: "v0.3")
                LabeledContent("Plan Schema", value: "v0.3")

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
    }

    private var csvTransferStatusText: String {
        switch exportStore.liftsLibrary.transferStatus.phase {
        case .idle:
            return "Idle"
        case .preparing:
            return "Preparing"
        case .queued:
            return "Queued"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    private var csvTransferColor: Color {
        switch exportStore.liftsLibrary.transferStatus.phase {
        case .idle:
            return .gray
        case .preparing, .queued:
            return .orange
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var planTransferStatusText: String {
        switch exportStore.planLibrary.transferStatus.phase {
        case .idle:
            return "Idle"
        case .preparing:
            return "Preparing"
        case .queued:
            return "Queued"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    private var planTransferColor: Color {
        switch exportStore.planLibrary.transferStatus.phase {
        case .idle:
            return .gray
        case .preparing, .queued:
            return .orange
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private func loadCSVInfo() {
        guard let csvURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("WeightWatch/Global/all_time.csv") else {
            return
        }

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
                let data = try Data(contentsOf: url)
                let plan = try JSONDecoder().decode(PlanV03.self, from: data)

                // Save to Plans directory
                guard let planDirectory = try? FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ).appendingPathComponent("WeightWatch/Plans") else {
                    return
                }

                try FileManager.default.createDirectory(at: planDirectory, withIntermediateDirectories: true)
                let destination = planDirectory.appendingPathComponent("\(plan.planName).json")
                try data.write(to: destination, options: .atomic)
            } catch {
                print("Failed to import plan: \(error)")
            }
        }
    }
}
