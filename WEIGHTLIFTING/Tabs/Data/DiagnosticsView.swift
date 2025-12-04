import SwiftUI

/// Detailed diagnostics view
struct DiagnosticsView: View {
    @State private var diagnostics: DiagnosticsInfo?

    var body: some View {
        List {
            if let diagnostics = diagnostics {
                Section("App Info") {
                    LabeledContent("Version", value: diagnostics.appVersion)
                    LabeledContent("Build", value: diagnostics.buildNumber)
                    LabeledContent("Bundle ID", value: diagnostics.bundleID)
                }

                Section("Data Schema") {
                    LabeledContent("CSV Version", value: "v0.3")
                    LabeledContent("Plan Version", value: "v0.3")
                    LabeledContent("CSV Columns", value: "23")
                }

                Section("File Storage") {
                    LabeledContent("CSV Path", value: diagnostics.csvPath)
                    LabeledContent("Plan Path", value: diagnostics.planPath)
                    LabeledContent("CSV Exists", value: diagnostics.csvExists ? "Yes" : "No")
                    LabeledContent("Plan Exists", value: diagnostics.planExists ? "Yes" : "No")
                }

                Section("Storage Usage") {
                    LabeledContent("CSV Size", value: diagnostics.csvSize)
                    LabeledContent("Plans Size", value: diagnostics.plansSize)
                    LabeledContent("Total Size", value: diagnostics.totalSize)
                }

                Section("System Info") {
                    LabeledContent("iOS Version", value: diagnostics.iosVersion)
                    LabeledContent("Device Model", value: diagnostics.deviceModel)
                }

                Section("Actions") {
                    Button("Copy Diagnostics") {
                        copyDiagnostics()
                    }
                }
            } else {
                ProgressView("Loading diagnostics...")
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            loadDiagnostics()
        }
    }

    private func loadDiagnostics() {
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let bundleID = Bundle.main.bundleIdentifier else {
            return
        }

        guard let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("WeightWatch") else {
            return
        }

        let csvURL = baseURL.appendingPathComponent("Global/all_time.csv")
        let planURL = baseURL.appendingPathComponent("Plans/active_plan.json")

        let csvExists = FileManager.default.fileExists(atPath: csvURL.path)
        let planExists = FileManager.default.fileExists(atPath: planURL.path)

        let csvSize = fileSize(at: csvURL)
        let plansSize = directorySize(at: baseURL.appendingPathComponent("Plans"))
        let totalSize = directorySize(at: baseURL)

        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        diagnostics = DiagnosticsInfo(
            appVersion: appVersion,
            buildNumber: buildNumber,
            bundleID: bundleID,
            csvPath: csvURL.path,
            planPath: planURL.path,
            csvExists: csvExists,
            planExists: planExists,
            csvSize: csvSize,
            plansSize: plansSize,
            totalSize: totalSize,
            iosVersion: iosVersion,
            deviceModel: deviceModel
        )
    }

    private func fileSize(at url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return "N/A"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func directorySize(at url: URL) -> String {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return "N/A"
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }

        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    private func copyDiagnostics() {
        guard let diagnostics = diagnostics else { return }

        let text = """
        WeightWatch Diagnostics

        App Info:
        - Version: \(diagnostics.appVersion)
        - Build: \(diagnostics.buildNumber)
        - Bundle ID: \(diagnostics.bundleID)

        Data Schema:
        - CSV Version: v0.3
        - Plan Version: v0.3

        File Storage:
        - CSV Path: \(diagnostics.csvPath)
        - Plan Path: \(diagnostics.planPath)
        - CSV Exists: \(diagnostics.csvExists ? "Yes" : "No")
        - Plan Exists: \(diagnostics.planExists ? "Yes" : "No")

        Storage Usage:
        - CSV Size: \(diagnostics.csvSize)
        - Plans Size: \(diagnostics.plansSize)
        - Total Size: \(diagnostics.totalSize)

        System Info:
        - iOS Version: \(diagnostics.iosVersion)
        - Device Model: \(diagnostics.deviceModel)
        """

        UIPasteboard.general.string = text
    }
}

// MARK: - Diagnostics Info

struct DiagnosticsInfo {
    let appVersion: String
    let buildNumber: String
    let bundleID: String
    let csvPath: String
    let planPath: String
    let csvExists: Bool
    let planExists: Bool
    let csvSize: String
    let plansSize: String
    let totalSize: String
    let iosVersion: String
    let deviceModel: String
}
