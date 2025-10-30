//
//  RootView.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Combine
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            switch sessionStore.session {
            case .idle:
                ProgressView()
                    .task {
                        sessionStore.loadInitialSession()
                    }
            case .active(let context):
                SessionView(context: context)
            case .error:
                Text("Unable to load session")
            }
        }
    }
}

struct SessionView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var currentContext: SessionContext
    @StateObject private var sessionVM = SessionVM()
    @State private var deck: [DeckItem]
    @State private var editingStates: [UUID: SetEditingState]
    @State private var currentIndex: Int
    @State private var weightCache: [String: Double] = [:]
    @State private var switchSheet: SwitchSheetState?
    @State private var completedSetIDs: Set<UUID> = []
    @State private var completionOrder: [UUID] = []
    @State private var showUndoToast = false
    @State private var undoDeadline: Date?
    @State private var undoToastWorkItem: DispatchWorkItem?
    @State private var switchToastMessage: String?
    @State private var switchToastWorkItem: DispatchWorkItem?
    @State private var exportToastMessage: String?
    @State private var exportToastWorkItem: DispatchWorkItem?
    @State private var showEndScreen = false
    @State private var adhocSheet: AdhocSheetState?
    @State private var activeWeightPicker: ActiveWeightPicker?

    private let haptics = WatchHaptics()

    init(context: SessionContext) {
        _currentContext = State(initialValue: context)
        let initialDeck = context.deck
        _deck = State(initialValue: initialDeck)

        let initialStates = Dictionary(uniqueKeysWithValues: initialDeck.map { item in
            let defaultWeight = item.prevCompletions.first?.weight ?? 0
            let defaultEffort = item.prevCompletions.first?.effort ?? .expected
            let defaultReps = SessionView.defaultReps(for: item)
            return (
                item.id,
                SetEditingState(
                    weight: defaultWeight,
                    reps: defaultReps,
                    effort: defaultEffort
                )
            )
        })
        _editingStates = State(initialValue: initialStates)
        _currentIndex = State(initialValue: 0)
    }

    var body: some View {
        if showEndScreen {
            EndOfSessionView(
                context: currentContext,
                completedSetIDs: completedSetIDs,
                onStartNewSession: {
                    let nextDay = nextDayLabel()
                    container.sessionManager.switchDay(to: nextDay)
                    resetForNewSession()
                },
                 onAddAdhoc: {
                     adhocSheet = AdhocSheetState()
                 }
             )
             .navigationTitle("")
             .navigationBarTitleDisplayMode(.inline)
             .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $sessionVM.isWorkoutSheetVisible) {
                WorkoutSwitchSheet(vm: sessionVM)
            }
            .sheet(isPresented: $sessionVM.isWorkoutMenuVisible) {
                NavigationStack {
                    WorkoutMenuView(
                        vm: sessionVM,
                        onExport: {
                            container.exportService.exportSnapshotToPhone()
                        },
                        onAddExercise: {
                            adhocSheet = AdhocSheetState()
                        }
                    )
                }
            }
            .sheet(item: $switchSheet) { sheet in
                ExerciseSwitchSheet(
                    currentName: sheet.currentName,
                    currentCode: sheet.currentCode,
                     altOptions: sheet.altOptions,
                     recentOptions: sheet.recentOptions,
                     onApply: { selectedCode, scope in
                         applySwitch(itemID: sheet.itemID, to: selectedCode, scope: scope)
                         switchSheet = nil
                     },
                     onCancel: {
                         switchSheet = nil
                     }
                 )
            }
             .sheet(item: $adhocSheet) { _ in
                 AdhocExerciseSheet(
                     context: currentContext,
                     onSelect: { code in
                         addAdhocExercise(code: code)
                         adhocSheet = nil
                     },
                     onCancel: {
                         adhocSheet = nil
                     }
                 )
             }
            .sheet(item: $activeWeightPicker) { picker in
                let stateBinding = binding(for: picker.item)
                NavigationStack {
                    WeightPickerScreen(
                        value: Binding(
                            get: { stateBinding.wrappedValue.weight },
                            set: { newValue in
                                var updated = stateBinding.wrappedValue
                                updated.weight = newValue
                                stateBinding.wrappedValue = updated
                            }
                        ),
                        unit: picker.item.unit
                    )
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 4) {
                    if showUndoToast, let deadline = undoDeadline {
                        ToastUndoChip(
                            title: "Saved",
                            actionTitle: "Undo",
                            deadline: deadline,
                            action: {
                                if undoLastSavedSet() {
                                    container.sessionManager.undoLast()
                                }
                                hideUndoToast()
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let exportMessage = exportToastMessage {
                        ToastBanner(message: exportMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                     }
                     if let message = switchToastMessage {
                         ToastBanner(message: message)
                             .transition(.move(edge: .top).combined(with: .opacity))
                     }
                }
                .padding(.top, 4)
            }
            .animation(.easeInOut(duration: 0.2), value: showUndoToast)
            .animation(.easeInOut(duration: 0.2), value: switchToastMessage != nil)
            .animation(.easeInOut(duration: 0.2), value: exportToastMessage != nil)
            .onAppear {
                configureViewModel(with: currentContext)
            }
            .onReceive(sessionStore.$session) { state in
                guard case .active(let newContext) = state else { return }
                handleContextUpdate(newContext)
            }
            .onReceive(container.exportService.eventsPublisher) { event in
                handleExportEvent(event)
            }
        } else {
            TabView(selection: $currentIndex) {
                ForEach(Array(deck.enumerated()), id: \.element.id) { entry in
                    let item = entry.element
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            SetCardHost(
                                item: item,
                                state: binding(for: item),
                                setPosition: (
                                    current: position(for: item),
                                    total: totalSets(for: item.exerciseCode)
                                ),
                                targetDisplay: targetDisplay(for: item),
                                prevCompletions: item.prevCompletions,
                                isCompleted: completedSetIDs.contains(item.id),
                                onExerciseTap: { presentSwitch(for: item) },
                                onWeightTap: { presentWeightPicker(for: item) },
                                onSave: { saveDraft(for: item) }
                            )
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                            SessionHeaderView(vm: sessionVM)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tag(entry.offset)
                }
            }
            .tabViewStyle(.page)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $sessionVM.isWorkoutSheetVisible) {
                WorkoutSwitchSheet(vm: sessionVM)
            }
            .sheet(isPresented: $sessionVM.isWorkoutMenuVisible) {
                NavigationStack {
                    WorkoutMenuView(
                        vm: sessionVM,
                        onExport: {
                            container.exportService.exportSnapshotToPhone()
                        },
                        onAddExercise: {
                            adhocSheet = AdhocSheetState()
                        }
                    )
                }
            }
            .sheet(item: $switchSheet) { sheet in
                ExerciseSwitchSheet(
                    currentName: sheet.currentName,
                    currentCode: sheet.currentCode,
                    altOptions: sheet.altOptions,
                    recentOptions: sheet.recentOptions,
                    onApply: { selectedCode, scope in
                        applySwitch(itemID: sheet.itemID, to: selectedCode, scope: scope)
                        switchSheet = nil
                    },
                    onCancel: {
                        switchSheet = nil
                    }
                )
            }
            .sheet(item: $adhocSheet) { _ in
                AdhocExerciseSheet(
                    context: currentContext,
                    onSelect: { code in
                        addAdhocExercise(code: code)
                        adhocSheet = nil
                    },
                    onCancel: {
                        adhocSheet = nil
                    }
                )
            }
            .sheet(item: $activeWeightPicker) { picker in
                let stateBinding = binding(for: picker.item)
                NavigationStack {
                    WeightPickerScreen(
                        value: Binding(
                            get: { stateBinding.wrappedValue.weight },
                            set: { newValue in
                                var updated = stateBinding.wrappedValue
                                updated.weight = newValue
                                stateBinding.wrappedValue = updated
                            }
                        ),
                        unit: picker.item.unit
                    )
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 4) {
                    if showUndoToast, let deadline = undoDeadline {
                        ToastUndoChip(
                            title: "Saved",
                            actionTitle: "Undo",
                            deadline: deadline,
                            action: {
                                if undoLastSavedSet() {
                                    container.sessionManager.undoLast()
                                }
                                hideUndoToast()
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let exportMessage = exportToastMessage {
                        ToastBanner(message: exportMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let message = switchToastMessage {
                        ToastBanner(message: message)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, 4)
            }
             .animation(.easeInOut(duration: 0.2), value: showUndoToast)
             .animation(.easeInOut(duration: 0.2), value: switchToastMessage != nil)
             .animation(.easeInOut(duration: 0.2), value: exportToastMessage != nil)
            .onAppear {
                configureViewModel(with: currentContext)
            }
            .onReceive(sessionStore.$session) { state in
                guard case .active(let newContext) = state else { return }
                handleContextUpdate(newContext)
            }
            .onReceive(container.exportService.eventsPublisher) { event in
                handleExportEvent(event)
            }
        }

    }

    private func configureViewModel(with context: SessionContext) {
        sessionVM.configure(
            sessionManager: container.sessionManager,
            context: context,
            onDidSwitch: { day in
                presentSwitchToast(for: day)
            }
        )
    }

    private func handleContextUpdate(_ newContext: SessionContext) {
        let previousContext = currentContext
        currentContext = newContext
        sessionVM.sync(with: newContext)
        guard previousContext.sessionID != newContext.sessionID ||
            previousContext.day.label != newContext.day.label else {
            return
        }

        if previousContext.sessionID != newContext.sessionID {
            configureViewModel(with: newContext)
            hideSwitchToast()
        }

        resetForContext(using: newContext)
        showEndScreen = false
        showEndScreen = false
    }

    private func handleExportEvent(_ event: ExportService.ExportEvent) {
        switch event {
        case .queued:
            presentExportToast(message: "Export queued")
            haptics.playClick()
        case .delivered:
            presentExportToast(message: "Export ready on phone")
            haptics.playSuccess()
        case .failed(_, let error):
            presentExportToast(message: error.displayMessage)
            haptics.playError()
        }
    }

    private func presentExportToast(message: String) {
        exportToastWorkItem?.cancel()
        exportToastMessage = message
        let workItem = DispatchWorkItem {
            exportToastMessage = nil
            exportToastWorkItem = nil
        }
        exportToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func presentSwitchToast(for day: String) {
        switchToastWorkItem?.cancel()
        switchToastMessage = "Switched to \(day)"
        let workItem = DispatchWorkItem {
            switchToastMessage = nil
            switchToastWorkItem = nil
        }
        switchToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func hideSwitchToast() {
        switchToastWorkItem?.cancel()
        switchToastWorkItem = nil
        switchToastMessage = nil
    }

    private func binding(for item: DeckItem) -> Binding<SetEditingState> {
        Binding(
            get: {
                var state = editingStates[item.id] ?? SetEditingState(
                    weight: item.prevCompletions.first?.weight ?? 0,
                    reps: SessionView.defaultReps(for: item),
                    effort: item.prevCompletions.first?.effort ?? .expected
                )
                if let cachedWeight = weightCache[shareKey(for: item)], state.weight == 0 {
                    state.weight = cachedWeight
                    editingStates[item.id] = state
                }
                return state
            },
            set: { editingStates[item.id] = $0 }
        )
    }

    private func saveDraft(for item: DeckItem) {
        guard let state = editingStates[item.id] else { return }
        let startingIndex = currentIndex
        container.sessionManager.save(set: item, weight: state.weight, reps: state.reps, effort: state.effort)
        propagateDefaults(from: item, state: state)
        markCompleted(item)
        haptics.playSuccess()
        presentUndoToast()
        advanceToNextIncomplete(after: startingIndex)
    }

    private static func defaultReps(for item: DeckItem) -> Int {
        let numbers = item.targetReps
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        if let first = numbers.first {
            return max(1, min(first, 30))
        }
        return 1
    }

    private func propagateDefaults(from item: DeckItem, state: SetEditingState) {
        let key = shareKey(for: item)
        weightCache[key] = state.weight
        for deckItem in deck where shareKey(for: deckItem) == key {
            if deckItem.id == item.id { continue }
            if var existing = editingStates[deckItem.id], existing.weight == 0 {
                existing.weight = state.weight
                editingStates[deckItem.id] = existing
            }
        }
    }

    private func shareKey(for item: DeckItem) -> String {
        "\(item.exerciseCode)-\(item.segmentID)"
    }

    private func position(for item: DeckItem) -> Int {
        var count = 0
        for candidate in deck {
            if candidate.exerciseCode == item.exerciseCode {
                count += 1
            }
            if candidate.id == item.id {
                return count
            }
        }
        return 1
    }

    private func totalSets(for code: String) -> Int {
        deck.reduce(0) { partialResult, item in
            partialResult + (item.exerciseCode == code ? 1 : 0)
        }
    }

    private func targetDisplay(for item: DeckItem) -> String {
        item.targetReps.isEmpty ? "—" : item.targetReps
    }

    private func prefillActiveWeight() {
        guard deck.indices.contains(currentIndex) else { return }
        let item = deck[currentIndex]
        guard let latest = try? container.indexService.latestCompletion(for: item.exerciseCode) else { return }
        var state = editingStates[item.id] ?? SetEditingState(
            weight: latest.weight ?? 0,
            reps: SessionView.defaultReps(for: item),
            effort: latest.effort ?? .expected
        )
        if let weight = latest.weight {
            state.weight = weight
        }
        if let reps = latest.reps {
            state.reps = reps
        }
        if let effort = latest.effort {
            state.effort = effort
        }
        editingStates[item.id] = state
    }

    private func presentUndoToast() {
        undoToastWorkItem?.cancel()
        undoDeadline = Date().addingTimeInterval(5)
        showUndoToast = true
        let workItem = DispatchWorkItem {
            hideUndoToast()
        }
        undoToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func hideUndoToast() {
        undoToastWorkItem?.cancel()
        undoToastWorkItem = nil
        showUndoToast = false
        undoDeadline = nil
    }

    private func resetForContext(using context: SessionContext) {
        let newDeck = context.deck
        deck = newDeck
        let initialStates = Dictionary(uniqueKeysWithValues: newDeck.map { item in
            let defaultWeight = item.prevCompletions.first?.weight ?? 0
            let defaultEffort = item.prevCompletions.first?.effort ?? .expected
            let defaultReps = SessionView.defaultReps(for: item)
            return (
                item.id,
                SetEditingState(
                    weight: defaultWeight,
                    reps: defaultReps,
                    effort: defaultEffort
                )
            )
        })
        editingStates = initialStates
        weightCache = [:]
        completedSetIDs.removeAll()
        completionOrder.removeAll()
        currentIndex = 0
        undoToastWorkItem?.cancel()
        undoToastWorkItem = nil
        showUndoToast = false
        undoDeadline = nil
        switchSheet = nil
        showEndScreen = false
        prefillActiveWeight()
    }

    private func presentSwitch(for item: DeckItem) {
        let altCodes = altGroupOptions(for: item)
        let altOptions = altCodes.map {
            ExerciseSwitchOption(
                code: $0,
                title: displayName(for: $0),
                subtitle: nil,
                source: .altGroup
            )
        }

        let recentOptions = (try? container.indexService.recentExercises(inLast: 7, limit: 8)) ?? []
        let filteredRecents = recentOptions
            .filter { $0.exerciseCode != item.exerciseCode }
            .filter { !altCodes.contains($0.exerciseCode) }
        let mappedRecents = filteredRecents.map {
            ExerciseSwitchOption(
                code: $0.exerciseCode,
                title: displayName(for: $0.exerciseCode),
                subtitle: recentSubtitle(from: $0.latest),
                source: .recent
            )
        }

        switchSheet = SwitchSheetState(
            itemID: item.id,
            currentCode: item.exerciseCode,
            currentName: item.exerciseName,
            altOptions: altOptions,
            recentOptions: mappedRecents
        )
    }

    private func presentWeightPicker(for item: DeckItem) {
        activeWeightPicker = ActiveWeightPicker(item: item)
    }

    private func applySwitch(itemID: UUID, to newCode: String, scope: ExerciseSwitchScope) {
        guard let startIndex = deck.firstIndex(where: { $0.id == itemID }) else { return }
        let originalItem = deck[startIndex]
        let completions = (try? container.indexService.fetchLastTwo(for: newCode)) ?? []
        let latestWeight = completions.first?.weight
        let latestReps = completions.first?.reps

        let indicesToUpdate: [Int]
        switch scope {
        case .thisSet:
            indicesToUpdate = [startIndex]
        case .remaining:
            indicesToUpdate = deck.enumerated().compactMap { offset, element in
                guard element.exerciseCode == originalItem.exerciseCode, offset >= startIndex else { return nil }
                return offset
            }
        }

        var affectedSequences: [Int] = []

        for index in indicesToUpdate {
            let prior = deck[index]
            let oldKey = shareKey(for: prior)

            var updated = prior
            updated.exerciseCode = newCode
            updated.exerciseName = displayName(for: newCode)
            updated.prevCompletions = completions
            deck[index] = updated

            let newKey = shareKey(for: updated)
            if oldKey != newKey {
                weightCache.removeValue(forKey: oldKey)
            }

            if let latestWeight {
                weightCache[newKey] = latestWeight
            }

            var state = editingStates[updated.id] ?? SetEditingState(
                weight: latestWeight ?? 0,
                reps: SessionView.defaultReps(for: updated),
                effort: updated.prevCompletions.first?.effort ?? .expected
            )
            state.weight = latestWeight ?? 0
            if let reps = latestReps {
                state.reps = reps
            }
            editingStates[updated.id] = state

            affectedSequences.append(updated.sequence)
        }

        container.sessionManager.recordMutation(
            originalCode: originalItem.exerciseCode,
            newCode: newCode,
            scope: scope,
            startSequence: originalItem.sequence,
            affectedSequences: affectedSequences
        )
        prefillActiveWeight()
        haptics.playSuccess()
    }

    private func displayName(for code: String) -> String {
        currentContext.plan.exerciseNames[code] ?? code
    }

    private func altGroupOptions(for item: DeckItem) -> [String] {
        guard let group = item.altGroup else {
            return [item.exerciseCode]
        }
        var codes = currentContext.plan.altGroups[group] ?? []
        if !codes.contains(item.exerciseCode) {
            codes.insert(item.exerciseCode, at: 0)
        }
        if codes.isEmpty {
            codes = [item.exerciseCode]
        }
        return codes
    }

    private func recentSubtitle(from completion: DeckItem.PrevCompletion) -> String {
        var segments: [String] = []
        if let weight = completion.weight {
            segments.append(formattedWeight(weight))
        }
        if let reps = completion.reps {
            segments.append("× \(reps)")
        }
        let detail = segments.joined(separator: " ")

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "MMM d"
        let dateText = dateFormatter.string(from: completion.date)

        if detail.isEmpty {
            return dateText
        }
        return "\(detail) • \(dateText)"
    }

    private func formattedWeight(_ weight: Double) -> String {
        let symbol = currentContext.plan.unit.displaySymbol
        if abs(weight - weight.rounded()) < 0.0001 {
            return "\(Int(weight)) \(symbol)"
        }
        return String(format: "%.1f %@", weight, symbol)
    }

    private func markCompleted(_ item: DeckItem) {
        completedSetIDs.insert(item.id)
        completionOrder.append(item.id)
        if completedSetIDs.count == deck.count {
            container.sessionManager.markSessionCompleted()
            showEndScreen = true
            haptics.playSuccess()
        }
    }

    @discardableResult
    private func undoLastSavedSet() -> Bool {
        guard let last = completionOrder.popLast() else { return false }
        completedSetIDs.remove(last)
        if let index = deck.firstIndex(where: { $0.id == last }) {
            currentIndex = index
            prefillActiveWeight()
        }
        return true
    }

    private func advanceToNextIncomplete(after index: Int) {
        guard !deck.isEmpty else { return }
        var next = index + 1
        while next < deck.count {
            if !completedSetIDs.contains(deck[next].id) {
                currentIndex = next
                prefillActiveWeight()
                return
            }
            next += 1
        }
        if let first = deck.firstIndex(where: { !completedSetIDs.contains($0.id) }) {
            currentIndex = first
            prefillActiveWeight()
        }
    }

    private func nextDayLabel() -> String {
        guard let currentIndex = currentContext.plan.scheduleOrder.firstIndex(of: currentContext.day.label) else {
            return currentContext.plan.scheduleOrder.first ?? currentContext.day.label
        }
        let nextIndex = (currentIndex + 1) % currentContext.plan.scheduleOrder.count
        return currentContext.plan.scheduleOrder[nextIndex]
    }

    private func resetForNewSession() {
        showEndScreen = false
        // Other resets if needed
    }

    private func addAdhocExercise(code: String) {
        let name = currentContext.plan.exerciseNames[code] ?? code
        let prev = (try? container.indexService.fetchLastTwo(for: code)) ?? []
        let targetReps = prev.first?.reps.map { "\($0)" } ?? "3-5"
        let item = DeckItem(
            id: UUID(),
            kind: .straight,
            supersetID: nil,
            segmentID: 999, // adhoc
            sequence: deck.count + 1000, // high sequence
            setIndex: 1,
            round: nil,
            exerciseCode: code,
            exerciseName: name,
            altGroup: nil,
            targetReps: targetReps,
            unit: currentContext.plan.unit,
            isWarmup: false,
            badges: [],
            canSkip: false,
            restSeconds: nil,
            adlib: true,
            prevCompletions: prev
        )
        deck.append(item)
        let defaultWeight = prev.first?.weight ?? 0
        let defaultReps = SessionView.defaultReps(for: item)
        editingStates[item.id] = SetEditingState(
            weight: defaultWeight,
            reps: defaultReps,
            effort: .expected
        )
        currentIndex = deck.count - 1
        showEndScreen = false
    }

    private struct SwitchSheetState: Identifiable {
        let itemID: UUID
        let currentCode: String
        let currentName: String
        let altOptions: [ExerciseSwitchOption]
        let recentOptions: [ExerciseSwitchOption]

        var id: UUID { itemID }
    }

    private struct ActiveWeightPicker: Identifiable {
        let item: DeckItem
        var id: UUID { item.id }
    }

    private struct SetEditingState {
        var weight: Double
        var reps: Int
        var effort: DeckItem.Effort
    }

    private struct AdhocExerciseSheet: View {
        let context: SessionContext
        let onSelect: (String) -> Void
        let onCancel: () -> Void

        @State private var searchText = ""
        @State private var selectedGroup: String?

        var body: some View {
            NavigationView {
                VStack {
                    TextField("Search exercises", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding()

                    if searchText.isEmpty {
                        if selectedGroup == nil {
                            List(context.plan.altGroups.keys.sorted(), id: \.self) { group in
                                Button(group) {
                                    selectedGroup = group
                                }
                            }
                        } else if let group = selectedGroup {
                            List(context.plan.altGroups[group] ?? [], id: \.self) { code in
                                Button(context.plan.exerciseNames[code] ?? code) {
                                    onSelect(code)
                                }
                            }
                        }
                    } else {
                        let filtered = context.plan.exerciseNames.filter { $0.value.localizedCaseInsensitiveContains(searchText) }
                        List(filtered.keys.sorted(), id: \.self) { code in
                            Button(context.plan.exerciseNames[code] ?? code) {
                                onSelect(code)
                            }
                        }
                    }
                }
                .navigationTitle("Add Adhoc Exercise")
                .toolbar {
                    if selectedGroup != nil {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") { selectedGroup = nil }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Cancel") { onCancel() }
                    }
                }
            }
        }
    }

    private struct AdhocSheetState: Identifiable {
        let id = UUID()
    }

    private struct SetCardHost: View {
        let item: DeckItem
        @Binding var state: SetEditingState
        let setPosition: (current: Int, total: Int)
        let targetDisplay: String
        let prevCompletions: [DeckItem.PrevCompletion]
        let isCompleted: Bool
        let onExerciseTap: () -> Void
        let onWeightTap: () -> Void
        let onSave: () -> Void

        var body: some View {
            SetCardView(
                item: item,
                weight: $state.weight,
                reps: $state.reps,
                effort: $state.effort,
                setPosition: setPosition,
                targetDisplay: targetDisplay,
                prevCompletions: prevCompletions,
                isCompleted: isCompleted,
                onExerciseTap: onExerciseTap,
                onWeightTap: onWeightTap,
                onSave: onSave
            )
        }
    }


}

#Preview {
    let container = AppContainer()
    return RootView()
        .environmentObject(container)
        .environmentObject(container.sessionStore)
        .environmentObject(container.deckStore)
}
