//
//  CachedEmail.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import Foundation
import SwiftData

@Model
final class CachedEmail {
    var id: String
    var threadId: String
    var subject: String
    var fromEmail: String
    var fromName: String
    var date: Date
    var snippet: String
    var bodyText: String
    var attachmentData: Data? // Serialized attachment info
    var cachedAt: Date
    var isSenderScheduling: Bool

    init(id: String, threadId: String, subject: String, fromEmail: String, fromName: String, date: Date, snippet: String, bodyText: String, attachmentData: Data? = nil, isSenderScheduling: Bool = false) {
        self.id = id
        self.threadId = threadId
        self.subject = subject
        self.fromEmail = fromEmail
        self.fromName = fromName
        self.date = date
        self.snippet = snippet
        self.bodyText = bodyText
        self.attachmentData = attachmentData
        self.cachedAt = Date()
        self.isSenderScheduling = isSenderScheduling
    }

    // Check if email has attachments
    var hasAttachments: Bool {
        guard let data = attachmentData else { return false }
        guard let attachments = try? JSONDecoder().decode([EmailAttachment].self, from: data) else { return false }
        return !attachments.isEmpty
    }

    // Convert to EmailMessage
    func toEmailMessage() -> EmailMessage {
        // Deserialize attachments
        var attachments: [EmailAttachment] = []
        if let data = attachmentData {
            attachments = (try? JSONDecoder().decode([EmailAttachment].self, from: data)) ?? []
        }

        return EmailMessage(
            id: id,
            threadId: threadId,
            subject: subject,
            from: "\(fromName) <\(fromEmail)>",
            date: date,
            snippet: snippet,
            bodyText: bodyText,
            attachments: attachments
        )
    }

    // Create from EmailMessage
    static func from(_ email: EmailMessage) -> CachedEmail {
        // Parse from field
        let fromComponents = email.from.components(separatedBy: "<")
        let fromName = fromComponents.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let fromEmail = fromComponents.last?
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespaces) ?? ""

        // Serialize attachments
        var attachmentData: Data?
        if !email.attachments.isEmpty {
            attachmentData = try? JSONEncoder().encode(email.attachments)
        }

        let isScheduling = fromEmail.lowercased() == "plvscheduling@pallowvoltage.com"

        return CachedEmail(
            id: email.id,
            threadId: email.threadId,
            subject: email.subject,
            fromEmail: fromEmail,
            fromName: fromName,
            date: email.date,
            snippet: email.snippet,
            bodyText: email.bodyText,
            attachmentData: attachmentData,
            isSenderScheduling: isScheduling
        )
    }
}
