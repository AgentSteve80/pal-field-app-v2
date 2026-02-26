//
//  WidgetDataProvider.swift
//  PalFieldWidgets
//
//  Provides data for widgets using cached UserDefaults
//

import Foundation
import WidgetKit

/// Data structure for widget timeline entries
struct WidgetJobData {
    let weekEarnings: Double
    let weekJobCount: Int
    let todayEarnings: Double
    let todayJobCount: Int
    let todayJobs: [JobSummary]
    let lastUpdated: Date

    struct JobSummary {
        let jobNumber: String
        let address: String
        let total: Double
    }
}

/// Provides job data for widgets
struct WidgetDataProvider {
    static let shared = WidgetDataProvider()

    // App Group identifier - must match main app
    private let appGroupID = "group.com.pallowvoltage.fieldapp"

    /// Fetches current data for widgets from cached UserDefaults
    func fetchData() -> WidgetJobData {
        let now = Date()

        // Get shared UserDefaults
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            // Can't access shared defaults - return zeros
            return WidgetJobData(
                weekEarnings: 0,
                weekJobCount: 0,
                todayEarnings: 0,
                todayJobCount: 0,
                todayJobs: [],
                lastUpdated: now
            )
        }

        // Read cached values
        let weekEarnings = defaults.double(forKey: "widget_weekEarnings")
        let weekJobCount = defaults.integer(forKey: "widget_weekJobCount")
        let todayEarnings = defaults.double(forKey: "widget_todayEarnings")
        let todayJobCount = defaults.integer(forKey: "widget_todayJobCount")
        let lastUpdated = defaults.object(forKey: "widget_lastUpdated") as? Date ?? now

        // Decode individual today's jobs from cached JSON
        var todayJobs: [WidgetJobData.JobSummary] = []
        if let data = defaults.data(forKey: "widget_todayJobs"),
           let cached = try? JSONDecoder().decode([CachedJobSummary].self, from: data) {
            todayJobs = cached.map { WidgetJobData.JobSummary(jobNumber: $0.jobNumber, address: $0.address, total: $0.total) }
        }

        return WidgetJobData(
            weekEarnings: weekEarnings,
            weekJobCount: weekJobCount,
            todayEarnings: todayEarnings,
            todayJobCount: todayJobCount,
            todayJobs: todayJobs,
            lastUpdated: lastUpdated
        )
    }
}
