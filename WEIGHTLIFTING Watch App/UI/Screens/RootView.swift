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
    let context: SessionContext

    @StateObject private var sessionVM = SessionVM()
    @State private var deck: [DeckItem]
    @State private var editingStates: [UUID: SetEditingState]
    @State private var currentIndex: Int
    @State private var weightCache: [String: Double] = [:]
    @State private var switchSheet: SwitchSheetState?
    @State private var completedSetIDs: Set<UUID> = []
    @State private var completionOrder: [UUID] = []
    @State private var showUndoToast = false
    @State private var undoCountdown = 0
    @State private var undoTimer: Timer?
    @State private var switchToastMessage: String?
    @State private var switchToastWorkItem: DispatchWorkItem?

    private let haptics = WatchHaptics()

    init(context: SessionContext) {
        self.context = context
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
        VStack(spacing: 0) {
            SessionHeaderView(vm: sessionVM)
            TabView(selection: $currentIndex) {
                ForEach(Array(deck.enumerated()), id: \.element.id) { entry in
                    let item = entry.element
                    ScrollView {
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
                            onSave: { saveDraft(for: item) }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                    .tag(entry.offset)
                }
            }
            .tabViewStyle(.page)
        }
        .navigationTitle(sessionVM.activeWorkoutName.isEmpty ? context.day.label : sessionVM.activeWorkoutName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $sessionVM.isWorkoutSheetVisible) {
            WorkoutSwitchSheet(vm: sessionVM)
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
        .overlay(alignment: .top) {
            if let message = switchToastMessage {
                ToastBanner(message: message)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if showUndoToast {
                ToastUndoChip(
                    title: "Saved",
                    actionTitle: "Undo",
                    countdown: undoCountdown,
                    action: {
                        if undoLastSavedSet() {
                            container.sessionManager.undoLast()
                        }
                        hideUndoToast()
                    }
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showUndoToast)
        .animation(.easeInOut(duration: 0.2), value: switchToastMessage != nil)
        .onAppear {
            configureViewModel()
        }
        .onChange(of: context.sessionID) { _ in
            configureViewModel()
            resetForContext()
            hideSwitchToast()
        }
        .onChange(of: context.day.label) { _ in
            let previousSessionID = sessionVM.sessionIdentifier
            sessionVM.sync(with: context)
            if previousSessionID == context.sessionID {
                resetForContext()
            }
        }
    }

    private func configureViewModel() {
        sessionVM.configure(
            sessionManager: container.sessionManager,
            context: context,
            onDidSwitch: { day in
                presentSwitchToast(for: day)
            }
        )
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
        undoTimer?.invalidate()
        undoCountdown = 5
        showUndoToast = true

        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if self.undoCountdown <= 1 {
                timer.invalidate()
                self.undoTimer = nil
                self.showUndoToast = false
            } else {
                self.undoCountdown -= 1
            }
        }
        undoTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func hideUndoToast() {
        undoTimer?.invalidate()
        undoTimer = nil
        showUndoToast = false
    }

    private func resetForContext() {
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
        showUndoToast = false
        undoTimer?.invalidate()
        undoTimer = nil
        switchSheet = nil
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
        context.plan.exerciseNames[code] ?? code
    }

    private func altGroupOptions(for item: DeckItem) -> [String] {
        guard let group = item.altGroup else {
            return [item.exerciseCode]
        }
        var codes = context.plan.altGroups[group] ?? []
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
        let symbol = context.plan.unit.displaySymbol
        if abs(weight - weight.rounded()) < 0.0001 {
            return "\(Int(weight)) \(symbol)"
        }
        return String(format: "%.1f %@", weight, symbol)
    }

    private func markCompleted(_ item: DeckItem) {
        completedSetIDs.insert(item.id)
        completionOrder.append(item.id)
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

    private struct SwitchSheetState: Identifiable {
        let itemID: UUID
        let currentCode: String
        let currentName: String
        let altOptions: [ExerciseSwitchOption]
        let recentOptions: [ExerciseSwitchOption]

        var id: UUID { itemID }
    }

    private struct SetEditingState {
        var weight: Double
        var reps: Int
        var effort: DeckItem.Effort
    }

    private struct SetCardHost: View {
        let item: DeckItem
        @Binding var state: SetEditingState
        let setPosition: (current: Int, total: Int)
        let targetDisplay: String
        let prevCompletions: [DeckItem.PrevCompletion]
        let isCompleted: Bool
        let onExerciseTap: () -> Void
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
