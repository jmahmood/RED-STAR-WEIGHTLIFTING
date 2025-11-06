//
//  WeightWatchApp.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import SwiftUI
import WidgetKit

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
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                container.exportService.handleScenePhaseChange()
                container.complicationService.reloadComplications()
            }
            .onOpenURL { url in
                // Handle deep linking from widgets/complications
                handleDeepLink(url)
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

    /// Handle deep links from widgets and complications
    private func handleDeepLink(_ url: URL) {
        print("Deep link received: \(url)")

        // Parse the URL scheme: weightlifting://workout/current
        guard url.scheme == "weightlifting" else { return }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if pathComponents.count >= 2 && pathComponents[0] == "workout" && pathComponents[1] == "current" {
            // Navigate to current workout
            // The app will naturally show the current session when it opens
            print("Opening current workout session")
        }
    }
}
