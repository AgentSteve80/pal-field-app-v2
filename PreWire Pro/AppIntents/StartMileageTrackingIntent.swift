//
//  StartMileageTrackingIntent.swift
//  PreWire Pro
//
//  Siri Shortcut to start mileage tracking
//

import AppIntents
import SwiftUI

struct StartMileageTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Mileage Tracking"
    static var description = IntentDescription("Start tracking your mileage for a trip")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tripManager = TripTrackingManager.shared

        if tripManager.isTracking {
            return .result(dialog: "You already have a trip in progress with \(String(format: "%.1f", tripManager.totalMiles)) miles tracked.")
        }

        // Start tracking
        tripManager.startTrip()

        return .result(dialog: "Started tracking mileage. Drive safe!")
    }
}
