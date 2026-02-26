//
//  AppGroupConstants.swift
//  PreWire Pro
//
//  Shared constants for App Group access across main app, widgets, and extensions
//

import Foundation

extension Notification.Name {
    static let jobDataDidChange = Notification.Name("jobDataDidChange")
}

struct AppGroupConstants {
    /// App Group identifier for shared data access
    static let appGroupIdentifier = "group.PalLow-Voltage.PreWire-Pro"

    /// Shared UserDefaults using App Group
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// URL for shared SwiftData store
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// URL for the shared SwiftData store file
    static var sharedStoreURL: URL? {
        sharedContainerURL?.appendingPathComponent("PreWirePro.store")
    }
}

// MARK: - Widget Data Cache (UserDefaults-based for reliability)

/// Codable job summary for caching in UserDefaults
struct CachedJobSummary: Codable {
    let jobNumber: String
    let address: String
    let total: Double
}

struct WidgetDataCache {
    private static let weekEarningsKey = "widget_weekEarnings"
    private static let weekJobCountKey = "widget_weekJobCount"
    private static let todayEarningsKey = "widget_todayEarnings"
    private static let todayJobCountKey = "widget_todayJobCount"
    private static let todayJobsKey = "widget_todayJobs"
    private static let lastUpdatedKey = "widget_lastUpdated"

    /// Save widget data from main app
    static func save(weekEarnings: Double, weekJobCount: Int, todayEarnings: Double, todayJobCount: Int, todayJobs: [CachedJobSummary] = []) {
        guard let defaults = AppGroupConstants.sharedDefaults else {
            print("❌ Widget cache: Failed to get shared defaults")
            return
        }

        defaults.set(weekEarnings, forKey: weekEarningsKey)
        defaults.set(weekJobCount, forKey: weekJobCountKey)
        defaults.set(todayEarnings, forKey: todayEarningsKey)
        defaults.set(todayJobCount, forKey: todayJobCountKey)
        defaults.set(Date(), forKey: lastUpdatedKey)

        // Encode individual job summaries as JSON
        if let data = try? JSONEncoder().encode(todayJobs) {
            defaults.set(data, forKey: todayJobsKey)
        }

        defaults.synchronize()

        print("✅ Widget cache updated: Week $\(weekEarnings) (\(weekJobCount) jobs), Today $\(todayEarnings) (\(todayJobCount) jobs, \(todayJobs.count) details)")
    }

    /// Read widget data (used by widget)
    static func load() -> (weekEarnings: Double, weekJobCount: Int, todayEarnings: Double, todayJobCount: Int, todayJobs: [CachedJobSummary], lastUpdated: Date?) {
        guard let defaults = AppGroupConstants.sharedDefaults else {
            return (0, 0, 0, 0, [], nil)
        }

        var todayJobs: [CachedJobSummary] = []
        if let data = defaults.data(forKey: todayJobsKey) {
            todayJobs = (try? JSONDecoder().decode([CachedJobSummary].self, from: data)) ?? []
        }

        return (
            weekEarnings: defaults.double(forKey: weekEarningsKey),
            weekJobCount: defaults.integer(forKey: weekJobCountKey),
            todayEarnings: defaults.double(forKey: todayEarningsKey),
            todayJobCount: defaults.integer(forKey: todayJobCountKey),
            todayJobs: todayJobs,
            lastUpdated: defaults.object(forKey: lastUpdatedKey) as? Date
        )
    }
}
