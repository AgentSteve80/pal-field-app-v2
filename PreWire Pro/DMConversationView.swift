//
//  DMConversationView.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

struct DMConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: Settings

    let otherUser: ChatUser

    @Query private var allMessages: [TeamChatMessage]
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    private var myEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    /// Messages in this DM conversation (between me and otherUser)
    private var conversationMessages: [TeamChatMessage] {
        let otherEmail = otherUser.email.lowercased()
        return allMessages.filter { msg in
            guard msg.isDirectMessage else { return false }
            let sender = msg.senderEmail.lowercased()
            let recipient = msg.recipientEmail.lowercased()
            // Message is from me to them OR from them to me
            return (sender == myEmail && recipient == otherEmail) ||
                   (sender == otherEmail && recipient == myEmail)
        }.sorted { $0.timestamp < $1.timestamp }
    }

    init(otherUser: ChatUser) {
        self.otherUser = otherUser
        // Query all DM messages
        _allMessages = Query(filter: #Predicate<TeamChatMessage> { $0.isDirectMessage == true })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if conversationMessages.isEmpty {
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(otherUser.role.color.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(otherUser.displayName.prefix(1).uppercased())
                                            .font(.largeTitle.bold())
                                            .foregroundStyle(otherUser.role.color)
                                    )

                                Text(otherUser.displayName)
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)

                                Text("Start a conversation with \(otherUser.displayName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.top, 60)
                        }

                        ForEach(conversationMessages) { message in
                            DMBubble(
                                message: message,
                                isFromCurrentUser: message.senderEmail.lowercased() == myEmail
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: conversationMessages.count) { _, _ in
                    if let lastMessage = conversationMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = conversationMessages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                    // Mark unread messages as read
                    markMessagesAsRead()
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
        .navigationTitle(otherUser.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let senderName = settings.workerName.isEmpty ? "Unknown" : settings.workerName
        let senderEmail = GmailAuthManager.shared.userEmail

        let newMessage = TeamChatMessage(
            senderName: senderName,
            senderEmail: senderEmail,
            recipientEmail: otherUser.email,
            message: trimmed
        )
        modelContext.insert(newMessage)
        try? modelContext.save()

        messageText = ""
    }

    private func markMessagesAsRead() {
        var needsSave = false
        for message in conversationMessages {
            if message.recipientEmail.lowercased() == myEmail && !message.readByRecipient {
                message.readByRecipient = true
                message.readTimestamp = Date()
                needsSave = true
            }
        }
        if needsSave {
            try? modelContext.save()
        }
    }
}

// MARK: - DM Bubble

struct DMBubble: View {
    let message: TeamChatMessage
    let isFromCurrentUser: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.messageText)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isFromCurrentUser ? brandGreen : Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 4) {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))

                    // Read receipt for sent messages
                    if isFromCurrentUser && message.readByRecipient {
                        Text("Read")
                            .font(.caption2)
                            .foregroundStyle(brandGreen.opacity(0.8))
                    }
                }
            }

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
    }
}

#Preview {
    NavigationStack {
        DMConversationView(otherUser: ChatUser(email: "test@example.com", displayName: "Test User"))
    }
    .environmentObject(Settings.shared)
}
