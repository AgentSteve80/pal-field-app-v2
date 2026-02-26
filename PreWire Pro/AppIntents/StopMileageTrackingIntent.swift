//
//  StopMileageTrackingIntent.swift
//  PreWire Pro
//
//  Siri Shortcut to stop mileage tracking
//

import AppIntents
import SwiftUI
import SwiftData

struct StopMileageTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Mileage Tracking"
    static var description = IntentDescription("Stop tracking your mileage and save the trip")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tripManager = TripTrackingManager.shared

        guard tripManager.isTracking else {
            return .result(dialog: "No trip is currently being tracked.")
        }

        let miles = tripManager.totalMiles

        // Stop tracking and get the completed trip
        if let trip = tripManager.stopTrip() {
            // Save to SwiftData
            if let container = SharedModelContainer.create() {
                let context = ModelContext(container)
                context.insert(trip)
                try? context.save()
            }

            // Calculate tax deduction estimate (2025 IRS rate: $0.67/mile)
            let taxDeduction = miles * 0.67

            return .result(dialog: "Trip saved! You drove \(String(format: "%.1f", miles)) miles. Estimated tax deduction: $\(String(format: "%.2f", taxDeduction))")
        }

        return .result(dialog: "Trip stopped with \(String(format: "%.1f", miles)) miles.")
    }
}
