//
//  PalFieldWatchApp.swift
//  Pal Field Watch
//
//  Apple Watch companion app for mileage tracking
//

import SwiftUI

@main
struct PalFieldWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}
