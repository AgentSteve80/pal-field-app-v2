//
//  TeamChatView.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

// MARK: - Main Chat View with Tabs

struct TeamChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: Settings

    @State private var selectedTab: ChatTab = .team

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    enum ChatTab: String, CaseIterable {
        case team = "Team Chat"
        case direct = "Direct Messages"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Chat Type", selection: $selectedTab) {
                    ForEach(ChatTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content based on tab
                switch selectedTab {
                case .team:
                    TeamChatContent()
                case .direct:
                    DirectMessagesView()
                }
            }
            .background(Color.black)
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(brandGreen)
                }
            }
            .onAppear {
                registerCurrentUser()
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Auto-register or update the current user in ChatUser model
    private func registerCurrentUser() {
        let email = GmailAuthManager.shared.userEmail
        guard !email.isEmpty else { return }

        let lowercasedEmail = email.lowercased()
        let descriptor = FetchDescriptor<ChatUser>(predicate: #Predicate { $0.email == lowercasedEmail })

        do {
            let existingUsers = try modelContext.fetch(descriptor)
            if let existing = existingUsers.first {
                // Update last seen
                existing.lastSeen = Date()
                if existing.displayName.isEmpty || existing.displayName != settings.workerName {
                    existing.displayName = settings.workerName
                }
            } else {
                // Create new user
                let newUser = ChatUser(email: email, displayName: settings.workerName)
                modelContext.insert(newUser)
            }
            try modelContext.save()
        } catch {
            print("Failed to register chat user: \(error)")
        }
    }
}

// MARK: - Team Chat Content (Non-DM Messages)

struct TeamChatContent: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: Settings
    @Query private var messages: [TeamChatMessage]

    @State private var messageText = ""
    @StateObject private var notificationManager = ChatNotificationManager.shared
    @FocusState private var isInputFocused: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    /// Filter to only team chat messages (not DMs)
    private var teamMessages: [TeamChatMessage] {
        messages
            .filter { !$0.isDirectMessage }
            .sorted { $0.timestamp < $1.timestamp }
    }

    init() {
        // Query non-DM messages
        _messages = Query(filter: #Predicate<TeamChatMessage> { $0.isDirectMessage == false },
                          sort: \TeamChatMessage.timestamp)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if teamMessages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(brandGreen.opacity(0.5))

                                Text("Team Chat")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)

                                Text("Send messages to your team.\nAll workers with the app can see messages.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        }

                        ForEach(teamMessages) { message in
                            ChatBubble(
                                message: message,
                                isFromCurrentUser: message.senderName == settings.workerName
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: teamMessages.count) { _, _ in
                    if let lastMessage = teamMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = teamMessages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            // Input bar
            HStack(spacing: 12) {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(messageText.isEmpty ? .gray : brandGreen)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color.black)
        }
        .background(Color.black)
        .onAppear {
            // Mark all messages as read
            notificationManager.markAsRead()
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let senderName = settings.workerName.isEmpty ? "Unknown" : settings.workerName
        let senderEmail = GmailAuthManager.shared.userEmail

        let newMessage = TeamChatMessage(senderName: senderName, senderEmail: senderEmail, message: trimmed)
        modelContext.insert(newMessage)
        try? modelContext.save()

        messageText = ""
    }
}

// MARK: - Chat Bubble with Role Colors

struct ChatBubble: View {
    let message: TeamChatMessage
    let isFromCurrentUser: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    /// Get the role for this message's sender
    private var senderRole: UserRole {
        if !message.senderEmail.isEmpty {
            return UserRole.role(for: message.senderEmail)
        }
        // Fallback for old messages without email
        return .standard
    }

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser {
                    HStack(spacing: 6) {
                        Text(message.senderName)
                            .font(.caption.bold())
                            .foregroundStyle(senderRole.color)

                        // Role badge
                        Text(senderRole.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(senderRole.color)
                            .clipShape(Capsule())
                    }
                }

                Text(message.messageText)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isFromCurrentUser ? brandGreen : Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Chat Button with Badge

struct ChatButton: View {
    @Query(sort: \TeamChatMessage.timestamp) private var messages: [TeamChatMessage]
    @EnvironmentObject private var settings: Settings
    @StateObject private var notificationManager = ChatNotificationManager.shared
    @State private var showingChat = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    private var myEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    /// Only count team chat messages for the badge
    private var teamMessages: [TeamChatMessage] {
        messages.filter { !$0.isDirectMessage }
    }

    /// Count unread DMs (messages sent to me that I haven't read)
    private var unreadDMCount: Int {
        messages.filter { msg in
            msg.isDirectMessage &&
            msg.recipientEmail.lowercased() == myEmail &&
            !msg.readByRecipient
        }.count
    }

    /// Total unread count (team chat + DMs)
    private var totalUnreadCount: Int {
        notificationManager.unreadCount + unreadDMCount
    }

    var body: some View {
        Button {
            showingChat = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(brandGreen)

                if totalUnreadCount > 0 {
                    Text("\(min(totalUnreadCount, 99))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
        }
        .sheet(isPresented: $showingChat) {
            TeamChatView()
        }
        .onChange(of: teamMessages.count) { _, _ in
            notificationManager.updateUnreadCount(messages: teamMessages, currentUser: settings.workerName)
        }
        .onChange(of: messages) { _, _ in
            // Also refresh when any message changes
            notificationManager.updateUnreadCount(messages: teamMessages, currentUser: settings.workerName)
        }
        .onChange(of: notificationManager.refreshTrigger) { _, _ in
            // Periodic refresh trigger
            notificationManager.updateUnreadCount(messages: teamMessages, currentUser: settings.workerName)
        }
        .onAppear {
            notificationManager.updateUnreadCount(messages: teamMessages, currentUser: settings.workerName)
        }
    }
}

#Preview {
    TeamChatView()
        .environmentObject(Settings.shared)
}
