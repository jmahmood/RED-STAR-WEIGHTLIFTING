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

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RootView()
            }
            .environmentObject(container)
            .environmentObject(container.sessionStore)
            .environmentObject(container.deckStore)
        }
    }
}
