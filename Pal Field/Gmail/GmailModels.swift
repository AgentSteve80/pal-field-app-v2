//
//  GmailModels.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import Foundation
import SwiftUI

// MARK: - Email Message Model

struct EmailMessage: Identifiable, Equatable {
    let id: String              // Gmail message ID
    let threadId: String
    let subject: String
    let from: String
    let date: Date
    let snippet: String         // Preview text
    var bodyText: String        // Full plain text body
    var attachments: [EmailAttachment]

    init(id: String, threadId: String, subject: String, from: String, date: Date, snippet: String, bodyText: String = "", attachments: [EmailAttachment] = []) {
        self.id = id
        self.threadId = threadId
        self.subject = subject
        self.from = from
        self.date = date
        self.snippet = snippet
        self.bodyText = bodyText
        self.attachments = attachments
    }
}

// MARK: - Email Attachment Model

struct EmailAttachment: Identifiable, Equatable, Codable {
    let id: String              // Attachment ID from Gmail
    let filename: String
    let mimeType: String
    let sizeBytes: Int
    var localURL: URL?          // Temporary file URL after download

    var isImage: Bool {
        mimeType.starts(with: "image/")
    }

    var isPDF: Bool {
        mimeType == "application/pdf"
    }

    var isViewable: Bool {
        isImage || isPDF
    }

    // Custom coding keys to handle URL encoding
    enum CodingKeys: String, CodingKey {
        case id, filename, mimeType, sizeBytes, localURL
    }
}

// MARK: - Parsed Job Data

struct ParsedJobData {
    var jobNumber: String = ""
    var jobType: String = "" // (P) = Prewire, (R) = Rough, etc.
    var lotNumber: String = ""
    var address: String = ""
    var subdivision: String = ""
    var prospect: String = ""
    var builderCompany: String = "" // Epcon, Beazer, Drees, Pulte, MI
    var jobDate: Date = Date()
    var wireRuns: Int = 0
    var enclosure: Int = 0
    var flatPanelStud: Int = 0
    var flatPanelWall: Int = 0
    var flatPanelRemote: Int = 0
    var flexTube: Int = 0
    var mediaBox: Int = 0
    var dryRun: Int = 0
    var serviceRun: Int = 0
    var miles: Double = 0.0

    var isValid: Bool {
        // At minimum, we need a lot number to create a job
        !lotNumber.isEmpty
    }

    // Convert to Job model
    func toJob(settings: Settings) -> Job {
        let finalJobNumber = jobNumber.isEmpty ? "JB\(lotNumber)" : jobNumber

        let job = Job(
            jobNumber: finalJobNumber,
            jobDate: jobDate,
            lotNumber: lotNumber,
            address: address,
            subdivision: subdivision,
            prospect: prospect,
            wireRuns: wireRuns,
            enclosure: enclosure,
            flatPanelStud: flatPanelStud,
            flatPanelWall: flatPanelWall,
            flatPanelRemote: flatPanelRemote,
            flexTube: flexTube,
            mediaBox: mediaBox,
            dryRun: dryRun,
            serviceRun: serviceRun,
            miles: miles,
            payTierValue: settings.payTier.rawValue
        )
        job.builderCompany = builderCompany
        // Set owner info for user data isolation
        job.ownerEmail = GmailAuthManager.shared.userEmail
        job.ownerName = settings.workerName
        return job
    }
}

// MARK: - Gmail Error Types

enum GmailError: LocalizedError {
    case notAuthenticated
    case noAccessToken
    case noViewController
    case apiError(String)
    case parsingError(String)
    case networkError(Error)
    case invalidResponse
    case attachmentDownloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to Gmail. Please sign in first."
        case .noAccessToken:
            return "No access token available. Please sign in again."
        case .noViewController:
            return "Cannot present sign-in UI."
        case .apiError(let message):
            return "Gmail API Error: \(message)"
        case .parsingError(let message):
            return "Parsing Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Gmail API."
        case .attachmentDownloadFailed(let filename):
            return "Failed to download attachment: \(filename)"
        }
    }
}
