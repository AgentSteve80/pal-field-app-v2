//
//  WeekEarningsIntent.swift
//  PreWire Pro
//
//  Siri Shortcut to get this week's earnings
//

import AppIntents
import SwiftData
import Foundation

struct WeekEarningsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Week Earnings"
    static var description = IntentDescription("Get your earnings for the current week")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Get shared settings for pricing
        let settings = SharedSettings()

        // Calculate week start/end (Monday-based week)
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        let now = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let weekStart = calendar.startOfDay(for: calendar.date(from: components) ?? now)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now

        // Query jobs from shared container
        guard let container = SharedModelContainer.createReadOnly() else {
            return .result(dialog: "Unable to access job data.")
        }

        let context = ModelContext(container)

        do {
            let descriptor = FetchDescriptor<Job>(
                predicate: #Predicate<Job> { job in
                    job.jobDate >= weekStart && job.jobDate < weekEnd
                }
            )

            let weekJobs = try context.fetch(descriptor)
            let jobCount = weekJobs.count

            // Calculate total using shared settings
            var totalPay: Double = 0
            for job in weekJobs {
                totalPay += settings.calculateJobTotal(
                    wireRuns: job.wireRuns,
                    enclosure: job.enclosure,
                    flatPanelStud: job.flatPanelStud,
                    flatPanelWall: job.flatPanelWall,
                    flatPanelRemote: job.flatPanelRemote,
                    flexTube: job.flexTube,
                    mediaBox: job.mediaBox,
                    dryRun: job.dryRun,
                    serviceRun: job.serviceRun
                )
            }

            if jobCount == 0 {
                return .result(dialog: "You haven't logged any jobs this week yet.")
            }

            let jobWord = jobCount == 1 ? "job" : "jobs"
            return .result(dialog: "This week you've completed \(jobCount) \(jobWord) earning $\(String(format: "%.0f", totalPay)).")

        } catch {
            return .result(dialog: "Unable to fetch job data.")
        }
    }
}
