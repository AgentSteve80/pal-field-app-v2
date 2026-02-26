//
//  BackupManager.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import Foundation
import SwiftData
import UIKit

class BackupManager {

    // MARK: - iCloud Backup Settings

    private static let iCloudEnabledKey = "iCloudBackupEnabled"
    private static let lastBackupDateKey = "lastICloudBackupDate"
    private static let backupFrequencyKey = "backupFrequencyDays"

    static var isICloudEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: iCloudEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: iCloudEnabledKey) }
    }

    static var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBackupDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBackupDateKey) }
    }

    static var backupFrequencyDays: Int {
        get { UserDefaults.standard.integer(forKey: backupFrequencyKey) == 0 ? 1 : UserDefaults.standard.integer(forKey: backupFrequencyKey) }
        set { UserDefaults.standard.set(newValue, forKey: backupFrequencyKey) }
    }

    static var shouldBackupToday: Bool {
        guard isICloudEnabled else { return false }

        guard let lastBackup = lastBackupDate else {
            return true // Never backed up before
        }

        let daysSinceBackup = Calendar.current.dateComponents([.day], from: lastBackup, to: Date()).day ?? 0
        return daysSinceBackup >= backupFrequencyDays
    }

    /// Check and perform automatic backup if needed
    static func performAutomaticBackupIfNeeded(jobs: [Job], invoices: [Invoice], expenses: [Expense], mileageTrips: [MileageTrip] = [], inventoryItems: [InventoryItem] = []) async {
        guard shouldBackupToday else {
            print("⏭️ Auto-backup not needed today")
            return
        }

        guard isICloudAvailable() else {
            print("⚠️ iCloud not available for auto-backup")
            return
        }

        print("🔄 Performing automatic iCloud backup...")

        do {
            try await backupToICloud(jobs: jobs, invoices: invoices, expenses: expenses, mileageTrips: mileageTrips, inventoryItems: inventoryItems)
            print("✅ Automatic backup completed successfully")
        } catch {
            print("❌ Automatic backup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Backup Data Structures

    struct BackupData: Codable {
        let metadata: BackupMetadata
        let jobs: [JobBackup]
        let invoices: [InvoiceBackup]
        let expenses: [ExpenseBackup]
        let mileageTrips: [MileageTripBackup]?  // Optional for backwards compatibility
        let inventoryItems: [InventoryItemBackup]?  // Optional for backwards compatibility
    }

    struct BackupMetadata: Codable {
        let version: String
        let appVersion: String
        let exportDate: Date
        let jobCount: Int
        let invoiceCount: Int
        let expenseCount: Int
        let mileageTripCount: Int?  // Optional for backwards compatibility
        let inventoryItemCount: Int?  // Optional for backwards compatibility
    }

    struct JobBackup: Codable {
        let id: String
        let jobNumber: String
        let jobDate: Date
        let lotNumber: String
        let address: String
        let prospect: String
        let wireRuns: Int
        let enclosure: Int
        let flatPanelStud: Int
        let flatPanelWall: Int
        let flatPanelRemote: Int
        let flexTube: Int
        let mediaBox: Int
        let dryRun: Int
        let serviceRun: Int
        let miles: Double
        let payTierValue: Int
    }

    struct InvoiceBackup: Codable {
        let id: String
        let weekStart: Date
        let weekEnd: Date
        let total: Double
        let jobCount: Int
        let createdAt: Date
        let pdfDataBase64: String
        let fileName: String
    }

    struct ExpenseBackup: Codable {
        let id: String
        let date: Date
        let category: String
        let amount: Double
        let merchant: String
        let notes: String
        let receiptImageBase64: String?
    }

    struct MileageTripBackup: Codable {
        let id: String
        let startDate: Date
        let endDate: Date?
        let miles: Double
        let purpose: String
        let notes: String
    }

    struct InventoryItemBackup: Codable {
        let id: String
        let supplier: String
        let category: String
        let itemNumber: Int
        let quantity: Int
        let lengthFeet: Int
        let status: String
        let notes: String
        let createdAt: Date
        let ownerEmail: String
        let ownerName: String
    }

    // MARK: - Export

    static func exportBackup(jobs: [Job], invoices: [Invoice], expenses: [Expense], mileageTrips: [MileageTrip] = [], inventoryItems: [InventoryItem] = []) throws -> URL {
        // Convert to backup format
        let jobBackups = jobs.map { job in
            JobBackup(
                id: job.id.uuidString,
                jobNumber: job.jobNumber,
                jobDate: job.jobDate,
                lotNumber: job.lotNumber,
                address: job.address,
                prospect: job.prospect,
                wireRuns: job.wireRuns,
                enclosure: job.enclosure,
                flatPanelStud: job.flatPanelStud,
                flatPanelWall: job.flatPanelWall,
                flatPanelRemote: job.flatPanelRemote,
                flexTube: job.flexTube,
                mediaBox: job.mediaBox,
                dryRun: job.dryRun,
                serviceRun: job.serviceRun,
                miles: job.miles,
                payTierValue: job.payTierValue
            )
        }

        let invoiceBackups = invoices.map { invoice in
            InvoiceBackup(
                id: invoice.id.uuidString,
                weekStart: invoice.weekStart,
                weekEnd: invoice.weekEnd,
                total: invoice.total,
                jobCount: invoice.jobCount,
                createdAt: invoice.createdAt,
                pdfDataBase64: invoice.pdfData.base64EncodedString(),
                fileName: invoice.fileName
            )
        }

        let expenseBackups = expenses.map { expense in
            ExpenseBackup(
                id: expense.id.uuidString,
                date: expense.date,
                category: expense.category,
                amount: expense.amount,
                merchant: expense.merchant,
                notes: expense.notes,
                receiptImageBase64: expense.receiptImageData?.base64EncodedString()
            )
        }

        let mileageTripBackups = mileageTrips.map { trip in
            MileageTripBackup(
                id: trip.id.uuidString,
                startDate: trip.startDate,
                endDate: trip.endDate,
                miles: trip.miles,
                purpose: trip.purpose,
                notes: trip.notes
            )
        }

        let inventoryItemBackups = inventoryItems.map { item in
            InventoryItemBackup(
                id: item.id.uuidString,
                supplier: item.supplier,
                category: item.category,
                itemNumber: item.itemNumber,
                quantity: item.quantity,
                lengthFeet: item.lengthFeet,
                status: item.status,
                notes: item.notes,
                createdAt: item.createdAt,
                ownerEmail: item.ownerEmail,
                ownerName: item.ownerName
            )
        }

        let metadata = BackupMetadata(
            version: "1.2",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            exportDate: Date(),
            jobCount: jobs.count,
            invoiceCount: invoices.count,
            expenseCount: expenses.count,
            mileageTripCount: mileageTrips.count,
            inventoryItemCount: inventoryItems.count
        )

        let backupData = BackupData(
            metadata: metadata,
            jobs: jobBackups,
            invoices: invoiceBackups,
            expenses: expenseBackups,
            mileageTrips: mileageTripBackups,
            inventoryItems: inventoryItemBackups
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(backupData)

        // Create backup file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "PalLowVoltage_Backup_\(dateString).plvbackup"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: fileURL)

        // Write JSON file
        try jsonData.write(to: fileURL)

        return fileURL
    }

    // MARK: - Import

    static func importBackup(from url: URL, modelContext: ModelContext, mergeMode: MergeMode) throws -> ImportResult {
        // Read JSON directly from backup file
        print("📂 Reading backup from: \(url.path)")
        let jsonData = try Data(contentsOf: url)
        print("📂 Backup file size: \(jsonData.count) bytes")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupData = try decoder.decode(BackupData.self, from: jsonData)

        // SAFETY CHECK: Validate backup has data BEFORE deleting anything
        let totalItemsInBackup = backupData.jobs.count + backupData.invoices.count + backupData.expenses.count + (backupData.mileageTrips?.count ?? 0) + (backupData.inventoryItems?.count ?? 0)
        print("📂 Backup contains: \(backupData.jobs.count) jobs, \(backupData.invoices.count) invoices, \(backupData.expenses.count) expenses, \(backupData.mileageTrips?.count ?? 0) trips, \(backupData.inventoryItems?.count ?? 0) inventory items")

        if mergeMode == .replace && totalItemsInBackup == 0 {
            throw BackupError.backupFailed("Backup file is empty - aborting to protect existing data")
        }

        // Get existing IDs if merging
        var existingJobIDs = Set<String>()
        var existingInvoiceIDs = Set<String>()
        var existingExpenseIDs = Set<String>()
        var existingMileageTripIDs = Set<String>()
        var existingInventoryItemIDs = Set<String>()

        if mergeMode == .merge {
            let jobs = try modelContext.fetch(FetchDescriptor<Job>())
            existingJobIDs = Set(jobs.map { $0.id.uuidString })

            let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())
            existingInvoiceIDs = Set(invoices.map { $0.id.uuidString })

            let expenses = try modelContext.fetch(FetchDescriptor<Expense>())
            existingExpenseIDs = Set(expenses.map { $0.id.uuidString })

            let mileageTrips = try modelContext.fetch(FetchDescriptor<MileageTrip>())
            existingMileageTripIDs = Set(mileageTrips.map { $0.id.uuidString })

            let inventoryItems = try modelContext.fetch(FetchDescriptor<InventoryItem>())
            existingInventoryItemIDs = Set(inventoryItems.map { $0.id.uuidString })
        } else {
            // Replace mode: ONLY delete after confirming backup is valid
            print("⚠️ Replace mode: Deleting existing data...")
            let jobs = try modelContext.fetch(FetchDescriptor<Job>())
            jobs.forEach { modelContext.delete($0) }

            let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())
            invoices.forEach { modelContext.delete($0) }

            let expenses = try modelContext.fetch(FetchDescriptor<Expense>())
            expenses.forEach { modelContext.delete($0) }

            let mileageTrips = try modelContext.fetch(FetchDescriptor<MileageTrip>())
            mileageTrips.forEach { modelContext.delete($0) }

            let inventoryItems = try modelContext.fetch(FetchDescriptor<InventoryItem>())
            inventoryItems.forEach { modelContext.delete($0) }
        }

        var importedJobs = 0
        var importedInvoices = 0
        var importedExpenses = 0
        var importedMileageTrips = 0
        var importedInventoryItems = 0
        var skippedJobs = 0
        var skippedInvoices = 0
        var skippedExpenses = 0
        var skippedMileageTrips = 0
        var skippedInventoryItems = 0

        // Import Jobs
        for jobBackup in backupData.jobs {
            if mergeMode == .merge && existingJobIDs.contains(jobBackup.id) {
                skippedJobs += 1
                continue
            }

            let job = Job(
                wireRuns: jobBackup.wireRuns,
                enclosure: jobBackup.enclosure,
                flatPanelStud: jobBackup.flatPanelStud,
                flatPanelWall: jobBackup.flatPanelWall,
                flatPanelRemote: jobBackup.flatPanelRemote,
                flexTube: jobBackup.flexTube,
                mediaBox: jobBackup.mediaBox,
                dryRun: jobBackup.dryRun,
                serviceRun: jobBackup.serviceRun,
                miles: jobBackup.miles,
                payTierValue: jobBackup.payTierValue
            )
            job.id = UUID(uuidString: jobBackup.id) ?? UUID()
            job.jobNumber = jobBackup.jobNumber
            job.jobDate = jobBackup.jobDate
            job.lotNumber = jobBackup.lotNumber
            job.address = jobBackup.address
            job.prospect = jobBackup.prospect
            // Set owner to current user when restoring backup
            job.ownerEmail = GmailAuthManager.shared.userEmail
            job.ownerName = Settings.shared.workerName

            modelContext.insert(job)
            importedJobs += 1
        }

        // Import Invoices
        for invoiceBackup in backupData.invoices {
            if mergeMode == .merge && existingInvoiceIDs.contains(invoiceBackup.id) {
                skippedInvoices += 1
                continue
            }

            guard let pdfData = Data(base64Encoded: invoiceBackup.pdfDataBase64) else {
                continue
            }

            let invoice = Invoice(
                weekStart: invoiceBackup.weekStart,
                weekEnd: invoiceBackup.weekEnd,
                total: invoiceBackup.total,
                jobCount: invoiceBackup.jobCount,
                pdfData: pdfData
            )
            invoice.id = UUID(uuidString: invoiceBackup.id) ?? UUID()
            invoice.createdAt = invoiceBackup.createdAt
            // Set owner to current user when restoring backup
            invoice.ownerEmail = GmailAuthManager.shared.userEmail
            invoice.ownerName = Settings.shared.workerName

            modelContext.insert(invoice)
            importedInvoices += 1
        }

        // Import Expenses
        for expenseBackup in backupData.expenses {
            if mergeMode == .merge && existingExpenseIDs.contains(expenseBackup.id) {
                skippedExpenses += 1
                continue
            }

            var imageData: Data?
            if let base64 = expenseBackup.receiptImageBase64 {
                imageData = Data(base64Encoded: base64)
            }

            let expense = Expense(
                date: expenseBackup.date,
                category: expenseBackup.category,
                amount: expenseBackup.amount,
                merchant: expenseBackup.merchant,
                notes: expenseBackup.notes,
                receiptImageData: imageData
            )
            expense.id = UUID(uuidString: expenseBackup.id) ?? UUID()
            // Set owner to current user when restoring backup
            expense.ownerEmail = GmailAuthManager.shared.userEmail
            expense.ownerName = Settings.shared.workerName

            modelContext.insert(expense)
            importedExpenses += 1
        }

        // Import Mileage Trips (if present in backup)
        if let mileageTripBackups = backupData.mileageTrips {
            for tripBackup in mileageTripBackups {
                if mergeMode == .merge && existingMileageTripIDs.contains(tripBackup.id) {
                    skippedMileageTrips += 1
                    continue
                }

                let trip = MileageTrip(
                    startDate: tripBackup.startDate,
                    endDate: tripBackup.endDate,
                    miles: tripBackup.miles,
                    purpose: tripBackup.purpose,
                    notes: tripBackup.notes,
                    ownerEmail: GmailAuthManager.shared.userEmail,
                    ownerName: Settings.shared.workerName
                )
                trip.id = UUID(uuidString: tripBackup.id) ?? UUID()

                modelContext.insert(trip)
                importedMileageTrips += 1
            }
        }

        // Import Inventory Items (if present in backup)
        if let inventoryItemBackups = backupData.inventoryItems {
            for itemBackup in inventoryItemBackups {
                if mergeMode == .merge && existingInventoryItemIDs.contains(itemBackup.id) {
                    skippedInventoryItems += 1
                    continue
                }

                let item = InventoryItem(
                    supplier: itemBackup.supplier,
                    category: itemBackup.category,
                    itemNumber: itemBackup.itemNumber,
                    quantity: itemBackup.quantity,
                    lengthFeet: itemBackup.lengthFeet,
                    status: itemBackup.status,
                    notes: itemBackup.notes
                )
                item.id = UUID(uuidString: itemBackup.id) ?? UUID()
                item.createdAt = itemBackup.createdAt
                // Set owner to current user when restoring backup
                item.ownerEmail = GmailAuthManager.shared.userEmail
                item.ownerName = Settings.shared.workerName

                modelContext.insert(item)
                importedInventoryItems += 1
            }
        }

        // Save
        try modelContext.save()

        return ImportResult(
            metadata: backupData.metadata,
            importedJobs: importedJobs,
            importedInvoices: importedInvoices,
            importedExpenses: importedExpenses,
            importedMileageTrips: importedMileageTrips,
            importedInventoryItems: importedInventoryItems,
            skippedJobs: skippedJobs,
            skippedInvoices: skippedInvoices,
            skippedExpenses: skippedExpenses,
            skippedMileageTrips: skippedMileageTrips,
            skippedInventoryItems: skippedInventoryItems
        )
    }

    // MARK: - iCloud Backup

    static func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    private static let iCloudContainerID = "iCloud.com.pallowvoltage.fieldapp"

    static func getICloudBackupURL() -> URL? {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID) else {
            print("❌ Could not get iCloud container URL for: \(iCloudContainerID)")
            return nil
        }
        let backupFolder = iCloudURL.appendingPathComponent("Documents/Backups")

        // Create folder if it doesn't exist
        try? FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        return backupFolder
    }

    static func backupToICloud(jobs: [Job], invoices: [Invoice], expenses: [Expense], mileageTrips: [MileageTrip] = [], inventoryItems: [InventoryItem] = []) async throws {
        guard isICloudAvailable() else {
            throw BackupError.iCloudNotAvailable
        }

        guard let iCloudBackupFolder = getICloudBackupURL() else {
            throw BackupError.iCloudNotAvailable
        }

        // Export backup to temp location
        let tempBackupURL = try exportBackup(jobs: jobs, invoices: invoices, expenses: expenses, mileageTrips: mileageTrips, inventoryItems: inventoryItems)

        // Create filename with date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "AutoBackup_\(dateString).plvbackup"

        let iCloudFileURL = iCloudBackupFolder.appendingPathComponent(fileName)

        // Copy to iCloud
        if FileManager.default.fileExists(atPath: iCloudFileURL.path) {
            try FileManager.default.removeItem(at: iCloudFileURL)
        }

        try FileManager.default.copyItem(at: tempBackupURL, to: iCloudFileURL)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempBackupURL)

        // Update last backup date
        lastBackupDate = Date()

        // Keep only last 10 backups in iCloud
        try? cleanupOldICloudBackups(keeping: 10)

        print("✅ Backed up to iCloud: \(fileName)")
    }

    static func listICloudBackups() throws -> [ICloudBackupInfo] {
        guard let iCloudBackupFolder = getICloudBackupURL() else {
            return []
        }

        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: iCloudBackupFolder, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])

        let backups = contents.filter { $0.pathExtension == "plvbackup" }.compactMap { url -> ICloudBackupInfo? in
            guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let creationDate = attributes[.creationDate] as? Date,
                  let fileSize = attributes[.size] as? Int64 else {
                return nil
            }

            return ICloudBackupInfo(
                url: url,
                name: url.lastPathComponent,
                creationDate: creationDate,
                fileSize: fileSize
            )
        }

        return backups.sorted { $0.creationDate > $1.creationDate }
    }

    static func restoreFromICloud(backupURL: URL, modelContext: ModelContext, mergeMode: MergeMode) throws -> ImportResult {
        print("☁️ Starting iCloud restore from: \(backupURL.lastPathComponent)")

        // Download from iCloud if needed
        try FileManager.default.startDownloadingUbiquitousItem(at: backupURL)

        // Wait for download with timeout
        var isDownloading = true
        var attempts = 0
        let maxAttempts = 300  // 30 seconds max wait

        while isDownloading && attempts < maxAttempts {
            if let values = try? backupURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey]),
               let status = values.ubiquitousItemDownloadingStatus {
                print("☁️ Download status: \(status.rawValue), attempt \(attempts)")
                if status == .current {
                    isDownloading = false
                } else if status == .notDownloaded {
                    // File hasn't started downloading yet, keep waiting
                }
            }
            if isDownloading {
                Thread.sleep(forTimeInterval: 0.1)
                attempts += 1
            }
        }

        if attempts >= maxAttempts {
            throw BackupError.backupFailed("Timeout waiting for iCloud file to download")
        }

        // Verify file exists and has content
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw BackupError.backupFailed("Backup file not found after download")
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        print("☁️ Downloaded file size: \(fileSize) bytes")

        if fileSize == 0 {
            throw BackupError.backupFailed("Downloaded backup file is empty")
        }

        // Import the backup
        return try importBackup(from: backupURL, modelContext: modelContext, mergeMode: mergeMode)
    }

    private static func cleanupOldICloudBackups(keeping: Int) throws {
        let backups = try listICloudBackups()

        // Delete backups beyond the keep limit
        if backups.count > keeping {
            for backup in backups.dropFirst(keeping) {
                try? FileManager.default.removeItem(at: backup.url)
                print("🗑️ Deleted old iCloud backup: \(backup.name)")
            }
        }
    }

    // MARK: - Supporting Types

    enum MergeMode {
        case merge      // Keep existing, add new
        case replace    // Delete all, import everything
    }

    struct ImportResult {
        let metadata: BackupMetadata
        let importedJobs: Int
        let importedInvoices: Int
        let importedExpenses: Int
        let importedMileageTrips: Int
        let importedInventoryItems: Int
        let skippedJobs: Int
        let skippedInvoices: Int
        let skippedExpenses: Int
        let skippedMileageTrips: Int
        let skippedInventoryItems: Int

        var totalImported: Int {
            importedJobs + importedInvoices + importedExpenses + importedMileageTrips + importedInventoryItems
        }

        var totalSkipped: Int {
            skippedJobs + skippedInvoices + skippedExpenses + skippedMileageTrips + skippedInventoryItems
        }
    }

    struct ICloudBackupInfo: Identifiable {
        let url: URL
        let name: String
        let creationDate: Date
        let fileSize: Int64

        var id: String { url.path }

        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: fileSize)
        }
    }

    enum BackupError: LocalizedError {
        case iCloudNotAvailable
        case backupFailed(String)

        var errorDescription: String? {
            switch self {
            case .iCloudNotAvailable:
                return "iCloud Drive is not available. Please sign in to iCloud in Settings."
            case .backupFailed(let message):
                return "Backup failed: \(message)"
            }
        }
    }
}
