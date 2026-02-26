//
//  PalFieldShortcuts.swift
//  Pal Field
//
//  AppShortcutsProvider to register Siri phrases
//

import AppIntents

struct PalFieldShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMileageTrackingIntent(),
            phrases: [
                "Start tracking mileage with \(.applicationName)",
                "Start mileage in \(.applicationName)",
                "Track my drive with \(.applicationName)",
                "Begin trip tracking in \(.applicationName)"
            ],
            shortTitle: "Start Mileage",
            systemImageName: "car.fill"
        )

        AppShortcut(
            intent: StopMileageTrackingIntent(),
            phrases: [
                "Stop tracking mileage with \(.applicationName)",
                "Stop mileage in \(.applicationName)",
                "End my trip in \(.applicationName)",
                "Finish trip tracking in \(.applicationName)"
            ],
            shortTitle: "Stop Mileage",
            systemImageName: "stop.circle.fill"
        )

        AppShortcut(
            intent: WeekEarningsIntent(),
            phrases: [
                "How much did I make this week with \(.applicationName)",
                "Get my week earnings from \(.applicationName)",
                "Check my earnings in \(.applicationName)",
                "What are my weekly earnings in \(.applicationName)"
            ],
            shortTitle: "Week Earnings",
            systemImageName: "dollarsign.circle.fill"
        )
    }
}
