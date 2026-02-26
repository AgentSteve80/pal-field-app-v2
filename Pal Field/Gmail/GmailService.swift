//
//  GmailService.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import Foundation
import UIKit

/// Gmail API service layer using REST API calls
class GmailService {
    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let authManager = GmailAuthManager.shared
    private let attachmentManager = AttachmentManager.shared

    // MARK: - Public Methods

    /// Fetch recent messages (last 7 days) - FAST for worksite use
    func fetchRecentMessages(daysBack: Int = 7, maxResults: Int = 50, senderEmail: String? = nil) async throws -> [EmailMessage] {
        let accessToken = try await authManager.getAccessToken()

        // Build query: newer_than:7d for last 7 days
        var query = "newer_than:\(daysBack)d"
        if let sender = senderEmail {
            query += " from:\(sender)"
        }

        let queryEncoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/messages?q=\(queryEncoded)&maxResults=\(maxResults)"

        guard let url = URL(string: urlString) else {
            throw GmailError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        print("📧 Fetching emails from last \(daysBack) days")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Parse response
        let decoder = JSONDecoder()
        let messageList = try decoder.decode(MessageListResponse.self, from: data)

        print("✅ Found \(messageList.messages?.count ?? 0) recent emails")

        // Convert to EmailMessage objects
        var emails: [EmailMessage] = []

        if let messages = messageList.messages {
            for messageRef in messages {
                if let email = try await getMessageDetails(messageId: messageRef.id) {
                    emails.append(email)
                }
            }
        }

        return emails
    }

    /// Fetch all messages from Gmail (All Mail)
    func fetchAllMessages(maxResults: Int = 50) async throws -> [EmailMessage] {
        let accessToken = try await authManager.getAccessToken()

        let urlString = "\(baseURL)/messages?maxResults=\(maxResults)&labelIds=INBOX"

        guard let url = URL(string: urlString) else {
            throw GmailError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        print("📧 Fetching all emails from Gmail")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Parse response
        let decoder = JSONDecoder()
        let messageList = try decoder.decode(MessageListResponse.self, from: data)

        print("✅ Found \(messageList.messages?.count ?? 0) emails")

        // Convert to EmailMessage objects (metadata only at this point)
        var emails: [EmailMessage] = []

        if let messages = messageList.messages {
            for messageRef in messages {
                // Fetch full message details
                if let email = try await getMessageDetails(messageId: messageRef.id) {
                    emails.append(email)
                }
            }
        }

        return emails
    }

    /// Fetch messages from a specific sender
    func fetchMessages(from senderEmail: String, maxResults: Int = 50) async throws -> [EmailMessage] {
        let accessToken = try await authManager.getAccessToken()

        // Build query: from:sender@example.com
        let query = "from:\(senderEmail)"
        let queryEncoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "\(baseURL)/messages?q=\(queryEncoded)&maxResults=\(maxResults)"

        guard let url = URL(string: urlString) else {
            throw GmailError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        print("📧 Fetching emails from: \(senderEmail)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Parse response
        let decoder = JSONDecoder()
        let messageList = try decoder.decode(MessageListResponse.self, from: data)

        print("✅ Found \(messageList.messages?.count ?? 0) emails")

        // Convert to EmailMessage objects (metadata only at this point)
        var emails: [EmailMessage] = []

        if let messages = messageList.messages {
            for messageRef in messages {
                // Fetch full message details
                if let email = try await getMessageDetails(messageId: messageRef.id) {
                    emails.append(email)
                }
            }
        }

        return emails
    }

    /// Get full message details including body and attachments
    func getMessageDetails(messageId: String) async throws -> EmailMessage? {
        let accessToken = try await authManager.getAccessToken()

        let urlString = "\(baseURL)/messages/\(messageId)?format=full"

        guard let url = URL(string: urlString) else {
            throw GmailError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Parse message
        let decoder = JSONDecoder()
        let message = try decoder.decode(MessageResponse.self, from: data)

        // Extract headers
        let headers = message.payload.headers
        let subject = headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? "(No Subject)"
        let from = headers.first(where: { $0.name.lowercased() == "from" })?.value ?? "(Unknown)"
        let dateString = headers.first(where: { $0.name.lowercased() == "date" })?.value ?? ""
        let messageIdHeader = headers.first(where: { $0.name.lowercased() == "message-id" })?.value

        // Parse date
        let date = parseEmailDate(dateString) ?? Date()

        // Extract body text
        let bodyText = extractPlainTextBody(from: message.payload)

        // Extract snippet
        let snippet = message.snippet ?? ""

        // Extract attachments
        let attachments = extractAttachments(from: message.payload, messageId: messageId)

        return EmailMessage(
            id: message.id,
            threadId: message.threadId,
            subject: subject,
            from: from,
            date: date,
            snippet: snippet,
            bodyText: bodyText,
            attachments: attachments,
            rfc2822MessageId: messageIdHeader
        )
    }

    /// Send a reply to an email with optional image attachments
    func sendReply(to originalEmail: EmailMessage, body: String, images: [Data] = []) async throws {
        let accessToken = try await authManager.getAccessToken()

        // Get the user's email address
        let userEmail = try await getUserEmail()

        // Extract the reply-to address from the original email
        let toAddress = extractEmailAddress(from: originalEmail.from)

        // Create the reply subject
        let replySubject = originalEmail.subject.hasPrefix("Re:") ? originalEmail.subject : "Re: \(originalEmail.subject)"

        // Build the MIME message
        let mimeMessage = buildMimeMessage(
            from: userEmail,
            to: toAddress,
            subject: replySubject,
            body: body,
            images: images,
            threadId: originalEmail.threadId,
            inReplyTo: originalEmail.id
        )

        // Encode to base64url
        let base64Message = mimeMessage.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Send via Gmail API
        let urlString = "\(baseURL)/messages/send"
        guard let url = URL(string: urlString) else {
            throw GmailError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "raw": base64Message,
            "threadId": originalEmail.threadId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        print("📤 Sending reply to: \(toAddress)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError("Failed to send email: HTTP \(httpResponse.statusCode) - \(errorMessage)")
        }

        print("✅ Reply sent successfully!")
    }

    /// Get the authenticated user's email address
    private func getUserEmail() async throws -> String {
        let accessToken = try await authManager.getAccessToken()

        let urlString = "\(baseURL)/profile"
        guard let url = URL(string: urlString) else {
            throw GmailError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GmailError.apiError("Failed to get user profile")
        }

        let profile = try JSONDecoder().decode(ProfileResponse.self, from: data)
        return profile.emailAddress
    }

    /// Extract email address from "Name <email@example.com>" format
    private func extractEmailAddress(from: String) -> String {
        if let match = from.range(of: "<(.+)>", options: .regularExpression) {
            let email = from[match].dropFirst().dropLast()
            return String(email)
        }
        return from
    }

    /// Build a MIME message with optional image attachments
    private func buildMimeMessage(from: String, to: String, subject: String, body: String, images: [Data], threadId: String, inReplyTo: String) -> String {
        let boundary = "boundary_\(UUID().uuidString)"

        var message = ""

        // Headers
        message += "From: \(from)\r\n"
        message += "To: \(to)\r\n"
        message += "Subject: \(subject)\r\n"
        message += "In-Reply-To: <\(inReplyTo)>\r\n"
        message += "References: <\(inReplyTo)>\r\n"
        message += "MIME-Version: 1.0\r\n"

        if images.isEmpty {
            // Simple text email
            message += "Content-Type: text/plain; charset=utf-8\r\n"
            message += "\r\n"
            message += body
        } else {
            // Multipart email with attachments
            message += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n"
            message += "\r\n"

            // Text body part
            message += "--\(boundary)\r\n"
            message += "Content-Type: text/plain; charset=utf-8\r\n"
            message += "\r\n"
            message += body
            message += "\r\n"

            // Image attachments
            for (index, imageData) in images.enumerated() {
                let filename = "onsite_photo_\(index + 1).jpg"
                let base64Image = imageData.base64EncodedString()

                message += "--\(boundary)\r\n"
                message += "Content-Type: image/jpeg; name=\"\(filename)\"\r\n"
                message += "Content-Disposition: attachment; filename=\"\(filename)\"\r\n"
                message += "Content-Transfer-Encoding: base64\r\n"
                message += "\r\n"
                message += base64Image
                message += "\r\n"
            }

            message += "--\(boundary)--\r\n"
        }

        return message
    }

    /// Download attachment
    func downloadAttachment(messageId: String, attachmentId: String, filename: String) async throws -> URL {
        let accessToken = try await authManager.getAccessToken()

        let urlString = "\(baseURL)/messages/\(messageId)/attachments/\(attachmentId)"

        guard let url = URL(string: urlString) else {
            throw GmailError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        print("📎 Downloading attachment: \(filename)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.attachmentDownloadFailed(filename)
        }

        // Decode attachment response
        let decoder = JSONDecoder()
        let attachmentResponse = try decoder.decode(AttachmentResponse.self, from: data)

        // Decode base64url data
        guard let attachmentData = decodeBase64URL(attachmentResponse.data) else {
            throw GmailError.attachmentDownloadFailed(filename)
        }

        // Save to temp file
        let localURL = try attachmentManager.saveAttachment(attachmentData, filename: filename, emailId: messageId)

        print("✅ Downloaded: \(filename) (\(attachmentData.count) bytes)")

        return localURL
    }

    // MARK: - Private Helper Methods

    private func extractPlainTextBody(from payload: MessagePayload) -> String {
        // Check if this part has plain text body
        if payload.mimeType == "text/plain", let bodyData = payload.body.data {
            if let decoded = decodeBase64URL(bodyData), let text = String(data: decoded, encoding: .utf8) {
                return text
            }
        }

        // Check parts recursively
        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == "text/plain", let bodyData = part.body.data {
                    if let decoded = decodeBase64URL(bodyData), let text = String(data: decoded, encoding: .utf8) {
                        return text
                    }
                }

                // Recursive check for nested parts
                if let nestedParts = part.parts {
                    for nestedPart in nestedParts {
                        if nestedPart.mimeType == "text/plain", let bodyData = nestedPart.body.data {
                            if let decoded = decodeBase64URL(bodyData), let text = String(data: decoded, encoding: .utf8) {
                                return text
                            }
                        }
                    }
                }
            }
        }

        return ""
    }

    private func extractAttachments(from payload: MessagePayload, messageId: String) -> [EmailAttachment] {
        var attachments: [EmailAttachment] = []

        func processPayload(_ payload: MessagePayload) {
            if let filename = payload.filename, !filename.isEmpty,
               let attachmentId = payload.body.attachmentId {

                let attachment = EmailAttachment(
                    id: attachmentId,
                    filename: filename,
                    mimeType: payload.mimeType,
                    sizeBytes: payload.body.size ?? 0,
                    localURL: nil
                )

                attachments.append(attachment)
            }

            // Process parts recursively
            if let parts = payload.parts {
                for part in parts {
                    processPayload(part)
                }
            }
        }

        processPayload(payload)

        return attachments
    }

    private func decodeBase64URL(_ base64URL: String) -> Data? {
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }

    private func parseEmailDate(_ dateString: String) -> Date? {
        // RFC 2822 date format used in emails
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try alternative format
        formatter.dateFormat = "dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: dateString)
    }

    // MARK: - Closeout Email

    /// Send a closeout email with photos to scheduling
    /// If threadId and inReplyTo are provided, the email is sent as a reply in the original thread
    func sendCloseoutEmail(subject: String, body: String, images: [UIImage], threadId: String? = nil, inReplyTo: String? = nil) async throws {
        let accessToken = try await authManager.getAccessToken()
        let userEmail = try await getUserEmail()
        let toAddress = "plvscheduling@pallowvoltage.com"

        // Convert UIImages to Data
        let imageDataArray = images.compactMap { $0.jpegData(compressionQuality: 0.7) }

        // Build the MIME message
        let mimeMessage = buildCloseoutMimeMessage(
            from: userEmail,
            to: toAddress,
            subject: subject,
            body: body,
            images: imageDataArray,
            inReplyTo: inReplyTo
        )

        // Encode to base64url
        let base64Message = mimeMessage.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Send via Gmail API
        let urlString = "\(baseURL)/messages/send"
        guard let url = URL(string: urlString) else {
            throw GmailError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = ["raw": base64Message]
        if let threadId = threadId {
            payload["threadId"] = threadId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        print("📤 Sending closeout to: \(toAddress)\(threadId != nil ? " (threading into \(threadId!))" : "")")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.apiError("Failed to send closeout: HTTP \(httpResponse.statusCode) - \(errorMessage)")
        }

        print("✅ Closeout sent successfully!")
    }

    /// Build MIME message for closeout (reply if inReplyTo provided, otherwise new email)
    private func buildCloseoutMimeMessage(from: String, to: String, subject: String, body: String, images: [Data], inReplyTo: String? = nil) -> String {
        let boundary = "boundary_\(UUID().uuidString)"

        var message = ""

        // Headers
        message += "From: \(from)\r\n"
        message += "To: \(to)\r\n"
        message += "Subject: \(subject)\r\n"
        if let inReplyTo = inReplyTo {
            message += "In-Reply-To: \(inReplyTo)\r\n"
            message += "References: \(inReplyTo)\r\n"
        }
        message += "MIME-Version: 1.0\r\n"

        if images.isEmpty {
            message += "Content-Type: text/plain; charset=utf-8\r\n"
            message += "\r\n"
            message += body
        } else {
            message += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n"
            message += "\r\n"

            // Text body part
            message += "--\(boundary)\r\n"
            message += "Content-Type: text/plain; charset=utf-8\r\n"
            message += "\r\n"
            message += body
            message += "\r\n"

            // Image attachments
            for (index, imageData) in images.enumerated() {
                let filename = "closeout_photo_\(index + 1).jpg"
                let base64Image = imageData.base64EncodedString()

                // Wrap base64 at 76 characters per line (MIME standard)
                let wrappedBase64 = wrapBase64(base64Image, lineLength: 76)

                message += "--\(boundary)\r\n"
                message += "Content-Type: image/jpeg; name=\"\(filename)\"\r\n"
                message += "Content-Disposition: attachment; filename=\"\(filename)\"\r\n"
                message += "Content-Transfer-Encoding: base64\r\n"
                message += "\r\n"
                message += wrappedBase64
                message += "\r\n"
            }

            message += "--\(boundary)--\r\n"
        }

        return message
    }

    /// Wrap base64 string at specified line length
    private func wrapBase64(_ base64: String, lineLength: Int) -> String {
        var result = ""
        var index = base64.startIndex

        while index < base64.endIndex {
            let endIndex = base64.index(index, offsetBy: lineLength, limitedBy: base64.endIndex) ?? base64.endIndex
            result += base64[index..<endIndex]
            if endIndex < base64.endIndex {
                result += "\r\n"
            }
            index = endIndex
        }

        return result
    }
}

// MARK: - API Response Models

private struct MessageListResponse: Codable {
    let messages: [MessageReference]?
    let resultSizeEstimate: Int?
}

private struct MessageReference: Codable {
    let id: String
    let threadId: String
}

private struct MessageResponse: Codable {
    let id: String
    let threadId: String
    let snippet: String?
    let payload: MessagePayload
}

private struct MessagePayload: Codable {
    let mimeType: String
    let headers: [Header]
    let body: Body
    let parts: [MessagePayload]?
    let filename: String?
}

private struct Header: Codable {
    let name: String
    let value: String
}

private struct Body: Codable {
    let size: Int?
    let data: String?
    let attachmentId: String?
}

private struct AttachmentResponse: Codable {
    let size: Int
    let data: String
}

private struct ProfileResponse: Codable {
    let emailAddress: String
}

