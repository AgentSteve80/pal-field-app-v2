//
//  WeekEarningsWidget.swift
//  PreWireProWidgets
//
//  Small widget showing week earnings total
//

import WidgetKit
import SwiftUI

struct WeekEarningsEntry: TimelineEntry {
    let date: Date
    let weekEarnings: Double
    let weekJobCount: Int
}

struct WeekEarningsProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekEarningsEntry {
        WeekEarningsEntry(date: Date(), weekEarnings: 850, weekJobCount: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekEarningsEntry) -> Void) {
        let data = WidgetDataProvider.shared.fetchData()
        let entry = WeekEarningsEntry(
            date: data.lastUpdated,
            weekEarnings: data.weekEarnings,
            weekJobCount: data.weekJobCount
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekEarningsEntry>) -> Void) {
        let data = WidgetDataProvider.shared.fetchData()
        let entry = WeekEarningsEntry(
            date: data.lastUpdated,
            weekEarnings: data.weekEarnings,
            weekJobCount: data.weekJobCount
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct WeekEarningsWidgetEntryView: View {
    var entry: WeekEarningsProvider.Entry
    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
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
                .font(.title.bold())
                .foregroundStyle(brandGreen)
                .minimumScaleFactor(0.6)

            Text("\(entry.weekJobCount) jobs")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct WeekEarningsWidget: Widget {
    let kind: String = "WeekEarningsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekEarningsProvider()) { entry in
            WeekEarningsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Week Earnings")
        .description("Shows your earnings for the current week.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    WeekEarningsWidget()
} timeline: {
    WeekEarningsEntry(date: .now, weekEarnings: 850, weekJobCount: 12)
}
