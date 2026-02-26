//
//  DashboardWidget.swift
//  PalFieldWidgets
//
//  Medium widget showing today's jobs and week earnings
//

import WidgetKit
import SwiftUI

struct DashboardEntry: TimelineEntry {
    let date: Date
    let weekEarnings: Double
    let weekJobCount: Int
    let todayEarnings: Double
    let todayJobCount: Int
}

struct DashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(
            date: Date(),
            weekEarnings: 850,
            weekJobCount: 12,
            todayEarnings: 145,
            todayJobCount: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
        let data = WidgetDataProvider.shared.fetchData()
        let entry = DashboardEntry(
            date: data.lastUpdated,
            weekEarnings: data.weekEarnings,
            weekJobCount: data.weekJobCount,
            todayEarnings: data.todayEarnings,
            todayJobCount: data.todayJobCount
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        let data = WidgetDataProvider.shared.fetchData()
        let entry = DashboardEntry(
            date: data.lastUpdated,
            weekEarnings: data.weekEarnings,
            weekJobCount: data.weekJobCount,
            todayEarnings: data.todayEarnings,
            todayJobCount: data.todayJobCount
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct DashboardWidgetEntryView: View {
    var entry: DashboardProvider.Entry
    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        HStack(spacing: 16) {
            // Today section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(String(format: "$%.0f", entry.todayEarnings))
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("\(entry.todayJobCount) jobs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Week section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(brandGreen)
                    Text("Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(String(format: "$%.0f", entry.weekEarnings))
                    .font(.title2.bold())
                    .foregroundStyle(brandGreen)

                Text("\(entry.weekJobCount) jobs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct DashboardWidget: Widget {
    let kind: String = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { entry in
            DashboardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dashboard")
        .description("Shows today's jobs and week earnings at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    DashboardWidget()
} timeline: {
    DashboardEntry(date: .now, weekEarnings: 850, weekJobCount: 12, todayEarnings: 145, todayJobCount: 2)
}
