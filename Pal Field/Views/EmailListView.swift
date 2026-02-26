//
//  EmailListView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import SwiftUI

struct EmailListView: View {
    let emails: [EmailMessage]
    let onSelect: (EmailMessage) -> Void

    // Group emails by day
    var groupedEmails: [(String, [EmailMessage])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: emails) { email -> Date in
            calendar.startOfDay(for: email.date)
        }

        return grouped.sorted { $0.key > $1.key }.map { date, emails in
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d" // "Monday, Dec 16"

            // Check if it's today or yesterday
            let dateString: String
            if calendar.isDateInToday(date) {
                dateString = "Today, \(formatter.string(from: date))"
            } else if calendar.isDateInYesterday(date) {
                dateString = "Yesterday, \(formatter.string(from: date))"
            } else {
                dateString = formatter.string(from: date)
            }

            return (dateString, emails.sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        if emails.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)

                Text("No emails found")
                    .font(.headline)

                Text("Try refreshing or check your filter settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            List {
                ForEach(groupedEmails, id: \.0) { dayHeader, dayEmails in
                    Section(header: Text(dayHeader).font(.headline).foregroundStyle(.primary)) {
                        ForEach(dayEmails) { email in
                            Button {
                                onSelect(email)
                            } label: {
                                EmailRow(email: email)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Email Row

struct EmailRow: View {
    let email: EmailMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Subject
            Text(email.subject)
                .font(.headline)
                .lineLimit(2)

            // From
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text(email.from)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.green)

                Text(email.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.secondary)

                Text(email.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Snippet
            if !email.snippet.isEmpty {
                Text(email.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            // Attachments indicator
            if !email.attachments.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                        .font(.caption2)

                    Text("\(email.attachments.count) attachment\(email.attachments.count == 1 ? "" : "s")")
                        .font(.caption2)

                    // Show file types
                    if email.attachments.contains(where: { $0.isImage }) {
                        Image(systemName: "photo")
                            .font(.caption2)
                    }

                    if email.attachments.contains(where: { $0.isPDF }) {
                        Image(systemName: "doc.fill")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.blue)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}
