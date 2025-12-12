import SwiftUI
import UniformTypeIdentifiers

/// Displays list of available programs
struct ProgramListView: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    @EnvironmentObject private var exportStore: ExportInboxStore
    @State private var installedPrograms: [ProgramInfo] = []
    @State private var showingImportPicker = false
    @State private var showingOnboarding = false
    @State private var showingHistory = false
    @State private var historyPlanName: String?
    @State private var historyPlanID: String?

    var body: some View {
        List {
            if let activePlan = exportStore.activePlan {
                Section("Active Program") {
                    ActiveProgramCard(plan: activePlan)
                }
            }

            if !installedPrograms.isEmpty {
                Section("Installed Programs") {
                    ForEach(installedPrograms) { program in
                        ProgramRow(program: program)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                coordinator.navigateToProgramDetail(program.name)
                            }
                    }
                }
            }

            Section("Actions") {
                Button {
                    showingImportPicker = true
                } label: {
                    Label("Import Program", systemImage: "square.and.arrow.down")
                }
            }
        }
        .navigationTitle("Programs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        if let activePlan = exportStore.activePlan {
                            historyPlanName = activePlan.planName
                            historyPlanID = (try? PlanStore.shared.getActivePlanID())
                                ?? PlanStore.generatePlanID(from: activePlan.planName)
                            showingHistory = true
                        }
                    } label: {
                        Label("History & Restore...", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(exportStore.activePlan == nil || historyPlanID == nil)

                    Divider()

                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Program", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingImportPicker) {
            DocumentPickerView(contentTypes: [.json]) { urls in
                guard let url = urls.first else { return }
                importProgram(from: url)
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            ProgramOnboardingView(
                selectDefault: activateDefaultProgram(_:),
                importTapped: { showingImportPicker = true }
            )
        }
        .sheet(isPresented: $showingHistory) {
            if let planName = historyPlanName, let planID = historyPlanID {
                NavigationStack {
                    ProgramHistoryView(
                        planID: planID,
                        programName: planName
                    )
                    .environmentObject(exportStore)
                }
            }
        }
        .task {
            seedDefaultPrograms()
            loadInstalledPrograms()
            showingOnboarding = exportStore.activePlan == nil
            historyPlanName = exportStore.activePlan?.planName
            historyPlanID = try? PlanStore.shared.getActivePlanID()
        }
        .onChange(of: exportStore.activePlan?.planName ?? "") { _ in
            showingOnboarding = exportStore.activePlan == nil
            if let active = exportStore.activePlan?.planName {
                historyPlanName = active
                historyPlanID = try? PlanStore.shared.getActivePlanID()
            }
        }
        .onChange(of: showingImportPicker) { isShowing in
            if !isShowing {
                showingOnboarding = exportStore.activePlan == nil
            }
        }
    }

    private func loadInstalledPrograms() {
        // Load programs from the Plans directory
        guard let planDirectory = ProgramDefaults.plansDirectory() else {
            return
        }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: planDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var mapped: [ProgramInfo] = []
        for url in contents {
            guard url.pathExtension == "json",
                  url.lastPathComponent != "active_plan.json" else { continue }
            do {
                let data = try Data(contentsOf: url)
                let plan = try JSONDecoder().decode(PlanV03.self, from: data)
                mapped.append(
                    ProgramInfo(
                        name: plan.planName,
                        fileURL: url,
                        dayCount: plan.days.count,
                        unit: plan.unit
                    )
                )
            } catch {
                print("ProgramListView: failed to decode \(url.lastPathComponent): \(error)")
            }
        }

        // Deduplicate by program name, preferring first encountered
        var unique: [String: ProgramInfo] = [:]
        for program in mapped {
            if unique[program.name] == nil {
                unique[program.name] = program
            }
        }
        installedPrograms = Array(unique.values).sorted { $0.name < $1.name }
    }

    private func importProgram(from url: URL) {
        Task {
            do {
                try await exportStore.importWorkoutPlan(from: url)
                loadInstalledPrograms()
            } catch {
                print("Failed to import program: \(error)")
            }
        }
    }

    private func seedDefaultPrograms() {
        ProgramDefaults.seedDefaults()
    }

    private func activateDefaultProgram(_ program: ProgramDefaults.DefaultProgram) {
        Task {
            do {
                guard let planDirectory = ProgramDefaults.plansDirectory(),
                      let data = ProgramDefaults.data(for: program) else {
                    return
                }
                let destination = ProgramDefaults.destinationURL(for: program, directory: planDirectory)
                try data.write(to: destination, options: .atomic)
                try await exportStore.importWorkoutPlan(from: destination)
                showingOnboarding = false
                loadInstalledPrograms()
            } catch {
                print("Failed to activate default program: \(error)")
            }
        }
    }
}

/// Active program card
struct ActiveProgramCard: View {
    @EnvironmentObject private var coordinator: TabCoordinator
    let plan: PlanV03

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.planName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        Label("\(plan.days.count) days", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label(plan.unit.rawValue.uppercased(), systemImage: "scalemass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            HStack(spacing: 12) {
                Button {
                    coordinator.programsNavPath.append(ProgramsDestination.editActiveProgram)
                } label: {
                    Text("Edit Program")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    coordinator.navigateToProgramDetail(plan.planName)
                } label: {
                    Text("View Details")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Program row in list
struct ProgramRow: View {
    let program: ProgramInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(program.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Text("\(program.dayCount) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(program.unit.rawValue.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Models

struct ProgramInfo: Identifiable {
    let id = UUID()
    let name: String
    let fileURL: URL
    let dayCount: Int
    let unit: WeightUnit
}

// MARK: - Onboarding

private struct ProgramOnboardingView: View {
    let selectDefault: (ProgramDefaults.DefaultProgram) -> Void
    let importTapped: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose Your Program")
                            .font(.title2.weight(.bold))

                        Text("Pick a starter program or import your own plan to unlock insights and your next workout.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        ForEach(ProgramDefaults.programs) { program in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(program.name)
                                    .font(.headline)
                                Text(program.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button {
                                    selectDefault(program)
                                } label: {
                                    Text("Activate \(program.name)")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }

                    VStack(spacing: 8) {
                        Text("Have a plan file?")
                            .font(.headline)
                        Button {
                            importTapped()
                        } label: {
                            Label("Import Program JSON", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Welcome")
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

import UniformTypeIdentifiers
