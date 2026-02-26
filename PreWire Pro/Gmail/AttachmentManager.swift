//
//  AttachmentManager.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import Foundation

/// Manages temporary storage for downloaded email attachments
class AttachmentManager {
    static let shared = AttachmentManager()

    private let tempDirectory: URL = {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("GmailAttachments", isDirectory: true)
    }()

    private init() {
        createTempDirectoryIfNeeded()
        cleanupOrphanedFiles()
    }

    // MARK: - Public Methods

    /// Save downloaded attachment data to temp file
    func saveAttachment(_ data: Data, filename: String, emailId: String) throws -> URL {
        let emailDir = tempDirectory.appendingPathComponent(emailId, isDirectory: true)

        // Create email-specific directory if needed
        if !FileManager.default.fileExists(atPath: emailDir.path) {
            try FileManager.default.createDirectory(
                at: emailDir,
                withIntermediateDirectories: true
            )
        }

        let fileURL = emailDir.appendingPathComponent(filename)
        try data.write(to: fileURL)

        print("📎 Saved attachment: \(filename) (\(data.count) bytes)")
        return fileURL
    }

    /// Clean up all temp files
    func cleanupAllTempFiles() {
        do {
            try FileManager.default.removeItem(at: tempDirectory)
            createTempDirectoryIfNeeded()
            print("🧹 Cleaned up all temp attachments")
        } catch {
            print("⚠️ Failed to cleanup all temp files: \(error)")
        }
    }

    /// Clean up specific email's attachments
    func cleanupEmailAttachments(emailId: String) {
        let emailDir = tempDirectory.appendingPathComponent(emailId)

        do {
            if FileManager.default.fileExists(atPath: emailDir.path) {
                try FileManager.default.removeItem(at: emailDir)
                print("🧹 Cleaned up attachments for email: \(emailId)")
            }
        } catch {
            print("⚠️ Failed to cleanup email attachments: \(error)")
        }
    }

    /// Get size of temp directory in bytes
    func getTempDirectorySize() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: tempDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    // MARK: - Private Methods

    private func createTempDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: tempDirectory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: tempDirectory,
                    withIntermediateDirectories: true
                )
                print("📁 Created temp directory: \(tempDirectory.path)")
            } catch {
                print("❌ Failed to create temp directory: \(error)")
            }
        }
    }

    /// Clean up orphaned files on app launch (files older than 1 day)
    private func cleanupOrphanedFiles() {
        guard let enumerator = FileManager.default.enumerator(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }

        let oneDayAgo = Date().addingTimeInterval(-86400) // 24 hours

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = resourceValues.creationDate else {
                continue
            }

            // Delete files older than 1 day
            if creationDate < oneDayAgo {
                try? FileManager.default.removeItem(at: fileURL)
                print("🧹 Deleted orphaned file: \(fileURL.lastPathComponent)")
            }
        }
    }
}
