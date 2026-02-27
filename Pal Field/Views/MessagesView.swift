//
//  MessagesView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import SwiftUI
import SwiftData
import UserNotifications

enum EmailFilter: String, CaseIterable {
    case jobs = "Jobs"
    case schedulingOnly = "Scheduling Only"
    case allMail = "Last 7 Days"

    var senderEmail: String? {
        switch self {
        case .jobs:
            return "plvscheduling@pallowvoltage.com"
        case .schedulingOnly:
            return "plvscheduling@pallowvoltage.com"
        case .allMail:
            return nil
        }
    }
}

struct MessagesView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = GmailAuthManager.shared

    // Query cached emails from SwiftData
    @Query(sort: \CachedEmail.date, order: .reverse) private var cachedEmails: [CachedEmail]

    @State private var selectedEmail: EmailMessage?
    @State private var isSyncing = false
    @State private var isDownloadingAttachments = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingEmailDetail = false
    @State private var currentFilter: EmailFilter = .jobs
    @State private var lastSyncDate: Date?

    private let gmailService = GmailService()

    var filteredEmails: [EmailMessage] {
        let filtered = cachedEmails.filter { email in
            switch currentFilter {
            case .jobs:
                // Jobs filter: from scheduling, has attachments, no "Re:" in subject
                return email.isSenderScheduling &&
                       email.hasAttachments &&
                       !email.subject.uppercased().contains("RE:")
            case .schedulingOnly:
                return email.isSenderScheduling
            case .allMail:
                return true
            }
        }
        return filtered.map { $0.toEmailMessage() }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack {
                    if authManager.isSignedIn {
                        // Show cached emails immediately
                        if filteredEmails.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "envelope.open")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.blue)

                                Text("No Messages")
                                    .font(.title2.bold())

                                if isSyncing {
                                    ProgressView("Syncing...")
                                        .padding()
                                } else {
                                    Text("Tap Sync to load recent emails")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)

                                    Button {
                                        syncEmails()
                                    } label: {
                                        Label("Sync Now", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding()
                        } else {
                            // Email list from cache
                            VStack(spacing: 0) {
                                // Sync status bar
                                if let lastSync = lastSyncDate {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                        Text("Synced \(lastSync, style: .relative)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if isSyncing {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemBackground))
                                }

                                EmailListView(emails: filteredEmails) { email in
                                    selectedEmail = email
                                    downloadAttachmentsAndShowDetail()
                                }
                            }
                        }
                    } else {
                        // Not signed in - show sign-in prompt
                        VStack(spacing: 20) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .padding()

                            Text("Sign in to Gmail")
                                .font(.title2.bold())

                            Text("Connect your Gmail account to view your messages")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button {
                                Task {
                                    do {
                                        _ = try await authManager.signIn()
                                        // Load user-specific settings for the newly signed-in user
                                        await MainActor.run {
                                            Settings.shared.loadUserSettings()
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        showingError = true
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                    Text("Sign In with Google")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal)

                            if let error = authManager.authError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if authManager.isSignedIn {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(EmailFilter.allCases, id: \.self) { filter in
                                Button {
                                    currentFilter = filter
                                } label: {
                                    HStack {
                                        Text(filter.rawValue)
                                        if currentFilter == filter {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text(currentFilter.rawValue)
                                    .font(.subheadline)
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            syncEmails()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isSyncing)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingEmailDetail) {
                if let email = selectedEmail {
                    NavigationStack {
                        EmailDetailView(email: email)
                    }
                }
            }
            .task {
                // Clear app badge when viewing messages
                UNUserNotificationCenter.current().setBadgeCount(0)

                // Load last sync date
                lastSyncDate = UserDefaults.standard.object(forKey: "lastEmailSync") as? Date

                // Auto-sync if signed in and cache is empty or old
                if authManager.isSignedIn {
                    let shouldAutoSync = cachedEmails.isEmpty ||
                                       lastSyncDate == nil ||
                                       Date().timeIntervalSince(lastSyncDate!) > 300 // 5 minutes

                    if shouldAutoSync {
                        syncEmails()
                    }
                }
            }
            .overlay {
                if isDownloadingAttachments {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)

                            Text("Downloading attachments...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(30)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(radius: 20)
                    }
                }
            }
        }
    }

    // MARK: - Methods

    private func syncEmails() {
        print("🔄 Starting email sync...")
        isSyncing = true

        Task {
            do {
                // Fetch only recent emails (last 7 days) for speed
                let recentEmails = try await gmailService.fetchRecentMessages(
                    daysBack: 7,
                    maxResults: 50,
                    senderEmail: currentFilter.senderEmail
                )

                await MainActor.run {
                    // Clear old cache (older than 30 days)
                    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                    let oldEmails = cachedEmails.filter { $0.cachedAt < thirtyDaysAgo }
                    for email in oldEmails {
                        modelContext.delete(email)
                    }

                    // Update cache with new emails
                    for email in recentEmails {
                        // Check if already cached
                        if !cachedEmails.contains(where: { $0.id == email.id }) {
                            let cached = CachedEmail.from(email)
                            modelContext.insert(cached)
                        }
                    }

                    // Save context
                    try? modelContext.save()

                    // Update sync time
                    lastSyncDate = Date()
                    UserDefaults.standard.set(lastSyncDate, forKey: "lastEmailSync")

                    isSyncing = false
                    print("✅ Email sync complete - cached \(recentEmails.count) emails")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSyncing = false
                    print("❌ Email sync failed: \(error)")
                }
            }
        }
    }

    private func downloadAttachmentsAndShowDetail() {
        guard let email = selectedEmail else { return }

        // If no attachments, show detail immediately
        if email.attachments.isEmpty {
            showingEmailDetail = true
            return
        }

        isDownloadingAttachments = true

        Task {
            var updatedAttachments: [EmailAttachment] = []

            for attachment in email.attachments {
                do {
                    // Download attachment
                    let localURL = try await gmailService.downloadAttachment(
                        messageId: email.id,
                        attachmentId: attachment.id,
                        filename: attachment.filename
                    )

                    // Update attachment with local URL
                    var updatedAttachment = attachment
                    updatedAttachment.localURL = localURL
                    updatedAttachments.append(updatedAttachment)

                } catch {
                    print("⚠️ Failed to download attachment \(attachment.filename): \(error)")
                    // Add attachment without local URL
                    updatedAttachments.append(attachment)
                }
            }

            await MainActor.run {
                // Update selected email with downloaded attachments
                selectedEmail = EmailMessage(
                    id: email.id,
                    threadId: email.threadId,
                    subject: email.subject,
                    from: email.from,
                    date: email.date,
                    snippet: email.snippet,
                    bodyText: email.bodyText,
                    attachments: updatedAttachments
                )

                isDownloadingAttachments = false
                showingEmailDetail = true
            }
        }
    }
}
