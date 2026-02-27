//
//  GmailImportView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import SwiftUI

struct GmailImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    @StateObject private var authManager = GmailAuthManager.shared

    @State private var emails: [EmailMessage] = []
    @State private var selectedEmail: EmailMessage?
    @State private var isLoadingEmails = false
    @State private var isDownloadingAttachments = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingEmailDetail = false

    private let gmailService = GmailService()

    var body: some View {
        NavigationStack {
            VStack {
                if authManager.isSignedIn {
                    // Signed in - show email list
                    if isLoadingEmails {
                        VStack(spacing: 16) {
                            ProgressView("Loading emails...")
                                .padding()

                            Text("Fetching from: \(settings.gmailFilterSender)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if emails.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "envelope.arrow.triangle.branch")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)

                            Text("No Emails Yet")
                                .font(.title2.bold())

                            if settings.gmailFilterSender.isEmpty {
                                Text("Set your sender email filter in Settings first")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Tap Refresh to load emails from:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(settings.gmailFilterSender)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }

                            Button {
                                refreshEmails()
                            } label: {
                                Label("Refresh Emails", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(settings.gmailFilterSender.isEmpty)
                        }
                        .padding()
                    } else {
                        // Email list
                        EmailListView(emails: emails) { email in
                            selectedEmail = email
                            downloadAttachmentsAndShowDetail()
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

                        Text("Connect your Gmail account to import job data from emails")
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
            .navigationTitle("Import from Gmail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if authManager.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            refreshEmails()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoadingEmails || settings.gmailFilterSender.isEmpty)
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
                // Auto-load emails when view appears if signed in and filter is set
                if authManager.isSignedIn && !settings.gmailFilterSender.isEmpty && emails.isEmpty {
                    refreshEmails()
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

    private func refreshEmails() {
        guard !settings.gmailFilterSender.isEmpty else {
            errorMessage = "Please set a sender email filter in Settings"
            showingError = true
            return
        }

        isLoadingEmails = true

        Task {
            do {
                emails = try await gmailService.fetchMessages(from: settings.gmailFilterSender)
                isLoadingEmails = false
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoadingEmails = false
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
