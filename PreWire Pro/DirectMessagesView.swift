//
//  DirectMessagesView.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

struct DirectMessagesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: Settings
    @Query private var allDMs: [TeamChatMessage]
    @Query(sort: \ChatUser.displayName) private var allUsers: [ChatUser]

    @State private var showingNewDM = false
    @State private var selectedUser: ChatUser?
    @State private var showingConversation = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    private var myEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    init() {
        // Query only DM messages
        _allDMs = Query(filter: #Predicate<TeamChatMessage> { $0.isDirectMessage == true })
    }

    /// Get unique conversations grouped by the other user's email
    private var conversations: [ConversationSummary] {
        var conversationMap: [String: ConversationSummary] = [:]

        for message in allDMs {
            let sender = message.senderEmail.lowercased()
            let recipient = message.recipientEmail.lowercased()

            // Determine the other party in this conversation
            let otherEmail: String
            if sender == myEmail {
                otherEmail = recipient
            } else if recipient == myEmail {
                otherEmail = sender
            } else {
                continue // Not my conversation
            }

            // Find or create conversation summary
            if var existing = conversationMap[otherEmail] {
                // Update if this message is newer
                if message.timestamp > existing.lastMessageDate {
                    existing.lastMessage = message.messageText
                    existing.lastMessageDate = message.timestamp
                    existing.lastMessageIsFromMe = sender == myEmail
                }
                // Count unread (messages TO me that are unread)
                if recipient == myEmail && !message.readByRecipient {
                    existing.unreadCount += 1
                }
                conversationMap[otherEmail] = existing
            } else {
                // Find user info
                let user = allUsers.first { $0.email.lowercased() == otherEmail }
                let displayName = user?.displayName ?? otherEmail
                let role = UserRole.role(for: otherEmail)

                var summary = ConversationSummary(
                    otherUserEmail: otherEmail,
                    otherUserName: displayName,
                    otherUserRole: role,
                    lastMessage: message.messageText,
                    lastMessageDate: message.timestamp,
                    lastMessageIsFromMe: sender == myEmail,
                    unreadCount: 0
                )
                if recipient == myEmail && !message.readByRecipient {
                    summary.unreadCount = 1
                }
                conversationMap[otherEmail] = summary
            }
        }

        // Sort by most recent
        return conversationMap.values.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                if conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(brandGreen.opacity(0.5))

                        Text("Direct Messages")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("Send private messages to team members.\nTap + to start a conversation.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(conversations, id: \.otherUserEmail) { conversation in
                        NavigationLink {
                            DMConversationView(otherUser: getUserForConversation(conversation))
                        } label: {
                            ConversationRow(conversation: conversation)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)

            // New DM button
            Button {
                showingNewDM = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(brandGreen)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingNewDM) {
            NewDMUserListView { user in
                selectedUser = user
                showingNewDM = false
                // Show conversation after a brief delay to let sheet dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingConversation = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingConversation) {
            if let user = selectedUser {
                NavigationStack {
                    DMConversationView(otherUser: user)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    showingConversation = false
                                    selectedUser = nil
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                    .foregroundStyle(brandGreen)
                                }
                            }
                        }
                }
            }
        }
    }

    /// Get ChatUser for an email address
    private func getUserForEmail(_ email: String) -> ChatUser {
        if let user = allUsers.first(where: { $0.email.lowercased() == email.lowercased() }) {
            return user
        }
        // Create temporary user for display
        return ChatUser(email: email, displayName: email)
    }

    /// Find existing ChatUser or create a temporary one for navigation
    private func getUserForConversation(_ conversation: ConversationSummary) -> ChatUser {
        if let user = allUsers.first(where: { $0.email.lowercased() == conversation.otherUserEmail }) {
            return user
        }
        // Create temporary user for display
        return ChatUser(email: conversation.otherUserEmail, displayName: conversation.otherUserName)
    }
}

// MARK: - Conversation Summary

struct ConversationSummary {
    let otherUserEmail: String
    let otherUserName: String
    let otherUserRole: UserRole
    var lastMessage: String
    var lastMessageDate: Date
    var lastMessageIsFromMe: Bool
    var unreadCount: Int
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ConversationSummary

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with role color
            ZStack {
                Circle()
                    .fill(conversation.otherUserRole.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Text(conversation.otherUserName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(conversation.otherUserRole.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUserName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Text(formatDate(conversation.lastMessageDate))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack {
                    Text(conversation.lastMessageIsFromMe ? "You: \(conversation.lastMessage)" : conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(brandGreen)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .numeric, time: .omitted)
        }
    }
}

#Preview {
    NavigationStack {
        DirectMessagesView()
    }
    .environmentObject(Settings.shared)
}
