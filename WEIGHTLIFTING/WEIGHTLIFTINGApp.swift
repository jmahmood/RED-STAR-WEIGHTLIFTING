//
//  WEIGHTLIFTINGApp.swift
//  WEIGHTLIFTING
//
//  Created by Jawaad Mahmood on 2025-10-28.
//

import SwiftUI

@main
struct WEIGHTLIFTINGApp: App {
    @StateObject private var exportInbox = ExportInboxStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(exportInbox)
                .onAppear {
                    exportInbox.updateScenePhase(scenePhase)
                }
                .onChange(of: scenePhase, perform: exportInbox.updateScenePhase)
        }
    }
}
