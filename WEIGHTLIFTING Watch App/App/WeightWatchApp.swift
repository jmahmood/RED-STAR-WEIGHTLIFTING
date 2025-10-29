//
//  WeightWatchApp.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI

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
            }
        }
    }
}
