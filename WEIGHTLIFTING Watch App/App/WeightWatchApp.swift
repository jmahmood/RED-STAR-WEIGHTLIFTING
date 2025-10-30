//
//  WeightWatchApp.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI
import ClockKit

@main
struct WeightWatchApp: App {
    @StateObject private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RootView()
            }
            .environmentObject(container)
            .environmentObject(container.sessionStore)
            .environmentObject(container.deckStore)
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                container.exportService.handleScenePhaseChange()
                container.complicationService.reloadComplications()
            }
            .onContinueUserActivity("com.weightlifting.nextSet") { userActivity in
                // Handle deep-link to next set
                if let userInfo = userActivity.userInfo,
                   let sessionID = userInfo["sessionID"] as? String,
                   let deckIndex = userInfo["deckIndex"] as? Int {
                    // TODO: Navigate to the set at deckIndex in sessionID
                    print("Navigate to session \(sessionID) index \(deckIndex)")
                }
            }
        }
    }
}
