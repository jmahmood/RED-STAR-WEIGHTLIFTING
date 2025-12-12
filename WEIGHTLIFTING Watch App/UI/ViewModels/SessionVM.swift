//
//  SessionVM.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-29.
//

import Combine
import Foundation

final class SessionVM: ObservableObject {
    @Published var activeWorkoutName: String = ""
    @Published var isWorkoutSheetVisible = false
    @Published var isWorkoutMenuVisible = false
    @Published var planDays: [String] = []
    @Published var planName: String = ""

    private var sessionManager: SessionManaging?
    private var didSwitchHandler: ((String) -> Void)?
    private let haptics: WatchHaptics

    private(set) var sessionIdentifier: String?

    init(haptics: WatchHaptics = WatchHaptics()) {
        self.haptics = haptics
    }

    func configure(
        sessionManager: SessionManaging,
        context: SessionContext,
        onDidSwitch: @escaping (String) -> Void
    ) {
        self.sessionManager = sessionManager
        self.didSwitchHandler = onDidSwitch
        let previousSessionID = sessionIdentifier
        sync(with: context)
        if previousSessionID != context.sessionID {
            isWorkoutSheetVisible = false
            isWorkoutMenuVisible = false
        }
    }

    func sync(with context: SessionContext) {
        sessionIdentifier = context.sessionID
        planName = context.plan.planName
        if planDays != context.plan.scheduleOrder {
            planDays = context.plan.scheduleOrder
        }
        if activeWorkoutName != context.day.label {
            activeWorkoutName = context.day.label
        }
        if isWorkoutSheetVisible && !planDays.contains(activeWorkoutName) {
            isWorkoutSheetVisible = false
        }
        if isWorkoutMenuVisible && !planDays.contains(activeWorkoutName) {
            isWorkoutMenuVisible = false
        }
    }

    func presentWorkoutSwitchSheet() {
        isWorkoutSheetVisible = true
    }

    func presentWorkoutMenu() {
        isWorkoutMenuVisible = true
    }

    func dismissWorkoutMenu() {
        isWorkoutMenuVisible = false
    }

    func presentWorkoutSwitchFromMenu() {
        isWorkoutMenuVisible = false
        DispatchQueue.main.async {
            self.isWorkoutSheetVisible = true
        }
    }

    func switchWorkout(to newDayLabel: String) {
        guard let manager = sessionManager else { return }
        guard newDayLabel != activeWorkoutName else {
            isWorkoutSheetVisible = false
            return
        }

        manager.switchDay(to: newDayLabel)
        activeWorkoutName = newDayLabel
        isWorkoutSheetVisible = false
        haptics.playSuccess()
        didSwitchHandler?(newDayLabel)
    }
}
