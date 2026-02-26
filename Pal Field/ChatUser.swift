//
//  ChatUser.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import Foundation
import SwiftData

@Model
final class ChatUser {
    var id: UUID = UUID()
    var email: String = ""
    var displayName: String = ""
    var lastSeen: Date = Date()
    var createdAt: Date = Date()

    /// Computed role based on email address
    var role: UserRole {
        UserRole.role(for: email)
    }

    init(email: String, displayName: String) {
        self.id = UUID()
        self.email = email
        self.displayName = displayName
        self.lastSeen = Date()
        self.createdAt = Date()
    }
}
