//
//  TodayJobsWidget.swift
//  PreWireProWidgets
//
//  Large widget showing today's jobs list
//

import WidgetKit
import SwiftUI

struct TodayJobsEntry: TimelineEntry {
    let date: Date
    let todayJobs: [WidgetJobData.JobSummary]
    let todayEarnings: Double
}

struct TodayJobsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayJobsEntry {
        TodayJobsEntry(
            date: Date(),
            todayJobs: [
                WidgetJobData.JobSummary(jobNumber: "JB1", address: "123 Oak St", total: 72),
                WidgetJobData.JobSummary(jobNumber: "JB2", address: "456 Maple Ave", total: 108),
                WidgetJobData.JobSummary(jobNumber: "JB3", address: "789 Pine Dr", total: 95)
            ],
            todayEarnings: 275
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayJobsEntry) -> Void) {
        let data = WidgetDataProvider.shared.fetchData()
        let entry = TodayJobsEntry(
            date: data.lastUpdated,
            todayJobs: data.todayJobs,
            todayEarnings: data.todayEarnings
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayJobsEntry>) -> Void) {
        let data = WidgetDataProvider.shared.fetchData()
        let entry = TodayJobsEntry(
            date: data.lastUpdated,
            todayJobs: data.todayJobs,
            todayEarnings: data.todayEarnings
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TodayJobsWidgetEntryView: View {
    var entry: TodayJobsProvider.Entry
    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                Text("Today's Jobs")
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.0f", entry.todayEarnings))
                    .font(.headline)
                    .foregroundStyle(brandGreen)
            }

            Divider()

            if entry.todayJobs.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No jobs today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Jobs list (show up to 4 jobs)
                ForEach(Array(entry.todayJobs.prefix(4).enumerated()), id: \.offset) { _, job in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.jobNumber)
                                .font(.subheadline.bold())
                            Text(job.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(String(format: "$%.0f", job.total))
                            .font(.subheadline.bold())
                            .foregroundStyle(brandGreen)
                    }
                }

                if entry.todayJobs.count > 4 {
                    Text("+\(entry.todayJobs.count - 4) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct TodayJobsWidget: Widget {
    let kind: String = "TodayJobsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayJobsProvider()) { entry in
            TodayJobsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Jobs")
        .description("Shows a list of today's jobs with totals.")
        .supportedFamilies([.systemLarge])
    }
}

#Preview(as: .systemLarge) {
    TodayJobsWidget()
} timeline: {
    TodayJobsEntry(
        date: .now,
        todayJobs: [
            WidgetJobData.JobSummary(jobNumber: "JB1", address: "123 Oak St", total: 72),
            WidgetJobData.JobSummary(jobNumber: "JB2", address: "456 Maple Ave", total: 108),
            WidgetJobData.JobSummary(jobNumber: "JB3", address: "789 Pine Dr", total: 95)
        ],
        todayEarnings: 275
    )
}
