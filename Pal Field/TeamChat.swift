//
//  TeamChat.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import Foundation
import SwiftData
import Combine

@Model
final class TeamChatMessage {
    var id: UUID = UUID()
    var senderName: String = ""
    var messageText: String = ""
    var timestamp: Date = Date()
    var isRead: Bool = false

    // DM support fields
    var senderEmail: String = ""           // Who sent it
    var recipientEmail: String = ""        // Empty = team chat, filled = DM
    var isDirectMessage: Bool = false      // Quick filter flag
    var readByRecipient: Bool = false      // For DM read receipts
    var readTimestamp: Date?               // When recipient read it

    /// Team chat message initializer
    init(senderName: String, message: String) {
        self.id = UUID()
        self.senderName = senderName
        self.messageText = message
        self.timestamp = Date()
        self.isRead = false
        self.senderEmail = ""
        self.recipientEmail = ""
        self.isDirectMessage = false
        self.readByRecipient = false
        self.readTimestamp = nil
    }

    /// Team chat message with email initializer
    init(senderName: String, senderEmail: String, message: String) {
        self.id = UUID()
        self.senderName = senderName
        self.senderEmail = senderEmail
        self.messageText = message
        self.timestamp = Date()
        self.isRead = false
        self.recipientEmail = ""
        self.isDirectMessage = false
        self.readByRecipient = false
        self.readTimestamp = nil
    }

    /// Direct message initializer
    init(senderName: String, senderEmail: String, recipientEmail: String, message: String) {
        self.id = UUID()
        self.senderName = senderName
        self.senderEmail = senderEmail
        self.recipientEmail = recipientEmail
        self.messageText = message
        self.timestamp = Date()
        self.isRead = false
        self.isDirectMessage = true
        self.readByRecipient = false
        self.readTimestamp = nil
    }
}

// Track last read timestamp per user
class ChatNotificationManager: ObservableObject {
    static let shared = ChatNotificationManager()

    @Published var unreadCount: Int = 0
    @Published var refreshTrigger: UUID = UUID()

    private let lastReadKey = "chatLastReadTimestamp"
    private var refreshTimer: Timer?

    var lastReadTimestamp: Date {
        get {
            UserDefaults.standard.object(forKey: lastReadKey) as? Date ?? Date.distantPast
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastReadKey)
        }
    }

    init() {
        startRefreshTimer()
    }

    func updateUnreadCount(messages: [TeamChatMessage], currentUser: String) {
        // Count messages from others that are newer than last read
        let newCount = messages.filter {
            $0.timestamp > lastReadTimestamp && $0.senderName != currentUser
        }.count

        if newCount != unreadCount {
            unreadCount = newCount
        }
    }

    func markAsRead() {
        lastReadTimestamp = Date()
        unreadCount = 0
    }

    /// Start a timer to trigger periodic refresh checks
    func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshTrigger = UUID()
            }
        }
    }

    /// Trigger an immediate refresh
    func triggerRefresh() {
        refreshTrigger = UUID()
    }
}
