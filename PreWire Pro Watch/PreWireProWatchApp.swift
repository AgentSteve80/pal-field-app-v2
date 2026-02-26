//
//  PreWireProWatchApp.swift
//  PreWire Pro Watch
//
//  Apple Watch companion app for mileage tracking
//

import SwiftUI

@main
struct PreWireProWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}
