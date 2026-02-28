//
//  SettingsView.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 11/13/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import GoogleSignIn
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var gmailAuth = GmailAuthManager.shared

    @Query private var jobs: [Job]
    @Query private var invoices: [Invoice]
    @Query private var expenses: [Expense]
    @Query private var mileageTrips: [MileageTrip]
    @Query private var inventoryItems: [InventoryItem]
    @Query private var chatUsers: [ChatUser]

    @State private var isSigningIn = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingImportOptions = false
    @State private var showingImportResult = false
    @State private var importURL: URL?
    @State private var importResult: BackupManager.ImportResult?
    @State private var mergeMode: BackupManager.MergeMode = .merge
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isBackingUpToICloud = false
    @State private var iCloudBackups: [BackupManager.ICloudBackupInfo] = []
    @State private var showingICloudBackups = false
    @State private var selectedICloudBackup: BackupManager.ICloudBackupInfo?
    @State private var showingICloudSignInAlert = false
    @State private var showingICloudAccountAlert = false
    @State private var showingAccessDenied = false
    @State private var showingClearChatConfirmation = false
    @State private var morningDigestEnabled = UserDefaults.standard.bool(forKey: "morningDigestEnabled")
    @State private var morningDigestTime: Date = {
        let hour = UserDefaults.standard.object(forKey: "morningDigestHour") as? Int ?? 6
        let minute = UserDefaults.standard.object(forKey: "morningDigestMinute") as? Int ?? 0
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }()
    @StateObject private var notificationManager = NotificationManager.shared

    var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }

    var lastICloudBackupDate: Date? {
        BackupManager.lastBackupDate
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                if settings.adminModeEnabled && settings.userRole.canEdit {
                    adminSection
                }
                personalInfoSection
                payTierSection
                appearanceSection
                notificationsSection
                gmailSection
                iCloudBackupSection
                backupRestoreSection
                widgetDebugSection
                syncStatusSection
                if settings.userRole == .developer {
                    developerSection
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileExporter(
                isPresented: $showingExportSheet,
                document: BackupFileDocument(url: exportURL),
                contentType: UTType(filenameExtension: "plvbackup") ?? .data,
                defaultFilename: exportURL?.lastPathComponent
            ) { result in
                handleExportResult(result)
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [UTType(filenameExtension: "plvbackup") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Import Options", isPresented: $showingImportOptions) {
                importOptionsButtons
            } message: {
                Text("Merge will keep existing data and add imported items. Replace will delete all current data and restore from backup.")
            }
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK") { }
            } message: {
                importResultMessage
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Sign in to iCloud", isPresented: $showingICloudSignInAlert) {
                iCloudSignInButtons
            } message: {
                Text("To enable iCloud backup, please sign in to your iCloud account in Settings.")
            }
            .alert("Login to iCloud", isPresented: $showingICloudAccountAlert) {
                Button("OK") { }
            } message: {
                Text("To save backups to iCloud:\n\n1. Open the Settings app\n2. Tap your name at the very top\n3. Tap 'iCloud'\n4. Turn on 'iCloud Drive'\n\nYour backups will then sync automatically.")
            }
            .alert("Access Denied", isPresented: $showingAccessDenied) {
                Button("OK") {
                    gmailAuth.clearAccessDenied()
                }
            } message: {
                Text("Your email is not authorized to use this app. Please contact an administrator to request access.")
            }
            .sheet(isPresented: $showingICloudBackups) {
                iCloudBackupsSheet
            }
            .sheet(isPresented: $showingClerkSignIn) {
                SignInView()
            }
        }
    }

    // MARK: - Form Sections

    @ObservedObject private var clerkAuth = ClerkAuthManager.shared
    @ObservedObject private var syncManager = ConvexSyncManager.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    private var accountSection: some View {
        Section("Account") {
            HStack {
                Text("Role")
                Spacer()
                Text(settings.userRole.rawValue)
                    .foregroundStyle(.secondary)
            }

            // Clerk auth status
            if clerkAuth.isAuthenticated {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clerkAuth.clerkDisplayName ?? "Signed In")
                            .font(.subheadline)
                        Text(clerkAuth.clerkEmail ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Button(role: .destructive) {
                    Task { await clerkAuth.signOut() }
                } label: {
                    Label("Sign Out of Pal Cloud", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Button {
                    showingClerkSignIn = true
                } label: {
                    Label("Sign in to Pal Cloud", systemImage: "person.crop.circle.badge.plus")
                }
            }

            if settings.userRole.canEdit {
                Toggle("Admin Mode", isOn: $settings.adminModeEnabled)

                if settings.adminModeEnabled {
                    Text("Admin features enabled: edit contacts, view all users' data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @State private var showingClerkSignIn = false

    private var adminSection: some View {
        Section("Admin Tools") {
            NavigationLink {
                UserAccountsView()
            } label: {
                Label("User Accounts", systemImage: "person.3.fill")
            }

            Button(role: .destructive) {
                showingClearChatConfirmation = true
            } label: {
                Label("Clear Team Chat (All Users)", systemImage: "trash")
            }
            .confirmationDialog(
                "Clear Team Chat for Everyone?",
                isPresented: $showingClearChatConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Messages", role: .destructive) {
                    clearTeamChatForEveryone()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all team chat messages for all users. This cannot be undone.")
            }
        }
    }

    private func clearTeamChatForEveryone() {
        // Delete all group chat messages (not DMs) - syncs to all users via CloudKit
        let descriptor = FetchDescriptor<TeamChatMessage>(predicate: #Predicate { $0.isDirectMessage == false })
        if let messages = try? modelContext.fetch(descriptor) {
            for message in messages {
                modelContext.delete(message)
            }
            try? modelContext.save()
        }
    }

    private var personalInfoSection: some View {
        Section("Personal Info") {
            TextField("Company Name", text: $settings.companyName)
            TextField("Name", text: $settings.workerName)
            TextField("Address", text: $settings.homeAddress)
            TextField("Phone Number", text: $settings.phoneNumber)
                .keyboardType(.phonePad)
            TextField("Pay Number", text: $settings.payNumber)
                .textInputAutocapitalization(.characters)
        }
    }

    private var payTierSection: some View {
        Section("Pay Tier") {
            Picker("Current Tier", selection: $settings.payTier) {
                ForEach(PayTier.allCases) { tier in
                    Text(tier.displayName).tag(tier)
                }
            }
            .pickerStyle(.segmented)

            Text("Pay rates adjust based on your selected tier")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle("Dark Mode", isOn: $settings.darkMode)
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Morning Digest", isOn: $morningDigestEnabled)
                .onChange(of: morningDigestEnabled) { _, enabled in
                    UserDefaults.standard.set(enabled, forKey: "morningDigestEnabled")
                    if enabled && !notificationManager.isAuthorized {
                        notificationManager.requestPermission()
                    }
                    notificationManager.scheduleMorningDigest()
                }

            if morningDigestEnabled {
                DatePicker("Notification Time", selection: $morningDigestTime, displayedComponents: .hourAndMinute)
                    .onChange(of: morningDigestTime) { _, newTime in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                        UserDefaults.standard.set(components.hour, forKey: "morningDigestHour")
                        UserDefaults.standard.set(components.minute, forKey: "morningDigestMinute")
                        notificationManager.scheduleMorningDigest()
                    }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Get a daily reminder to check your jobs for the day.")
        }
    }

    private var gmailSection: some View {
        Section {
            if gmailAuth.isSignedIn {
                gmailSignedInContent
            } else {
                gmailSignInButton
            }
        } header: {
            Text("Gmail (Messages)")
        } footer: {
            Text("Sign in to Gmail to view and respond to job emails in the Messages tab.")
        }
    }

    private var gmailSignedInContent: some View {
        Group {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed in as")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(gmailAuth.userEmail)
                        .font(.subheadline)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button(role: .destructive) {
                gmailAuth.signOut()
                // Reset onboarding to return to sign-in screen
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                dismiss()
            } label: {
                Label("Sign Out of Gmail", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private var gmailSignInButton: some View {
        Button {
            signInToGmail()
        } label: {
            if isSigningIn {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Signing in...")
                }
            } else {
                Label("Sign in with Google", systemImage: "envelope.badge")
            }
        }
        .disabled(isSigningIn)
    }

    private var iCloudBackupSection: some View {
        Section {
            if !BackupManager.isICloudAvailable() {
                iCloudUnavailableButton
            } else {
                iCloudAvailableContent
            }
        } header: {
            Text("iCloud Backup")
        } footer: {
            Text("Automatic backups save to iCloud Drive. Keeps last 10 backups.")
        }
    }

    private var iCloudUnavailableButton: some View {
        Button {
            showingICloudSignInAlert = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable iCloud Backup")
                        .foregroundStyle(.primary)
                    Text("Sign in to iCloud to enable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var iCloudAvailableContent: some View {
        Group {
            Toggle(isOn: Binding(
                get: { BackupManager.isICloudEnabled },
                set: { BackupManager.isICloudEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic iCloud Backup")
                    Text("Backs up to your iCloud Drive daily")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if BackupManager.isICloudEnabled {
                iCloudEnabledOptions
            }
        }
    }

    private var iCloudEnabledOptions: some View {
        Group {
            Picker("Backup Frequency", selection: Binding(
                get: { BackupManager.backupFrequencyDays },
                set: { BackupManager.backupFrequencyDays = $0 }
            )) {
                Text("Daily").tag(1)
                Text("Every 3 Days").tag(3)
                Text("Weekly").tag(7)
            }

            if let lastBackup = lastICloudBackupDate {
                HStack {
                    Text("Last iCloud Backup")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lastBackup, style: .relative)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Button {
                backupToICloudNow()
            } label: {
                if isBackingUpToICloud {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Backing up to iCloud...")
                    }
                } else {
                    Label("Backup to iCloud Now", systemImage: "icloud.and.arrow.up")
                }
            }
            .disabled(isBackingUpToICloud)

            Button {
                loadICloudBackups()
            } label: {
                Label("Restore from iCloud", systemImage: "icloud.and.arrow.down")
            }

            Button {
                showingICloudAccountAlert = true
            } label: {
                Label("Login to iCloud", systemImage: "icloud.and.arrow.up.fill")
            }
        }
    }

    private var backupRestoreSection: some View {
        Section {
            backupInfoView
            exportBackupButton
            importBackupButton
        } header: {
            Text("Backup & Restore")
        } footer: {
            Text("Export creates a .plvbackup file with all jobs, invoices, and expenses. Import restores data from a backup file.")
        }
    }

    private var widgetDebugSection: some View {
        Section {
            let defaults = AppGroupConstants.sharedDefaults
            let cached = WidgetDataCache.load()

            VStack(alignment: .leading, spacing: 8) {
                Text("Cache Status")
                    .font(.headline)

                if defaults != nil {
                    Text("✅ Shared UserDefaults OK")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("❌ Shared UserDefaults FAILED")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                Text("Cached Data:")
                    .font(.subheadline.bold())
                Text("Week: $\(String(format: "%.0f", cached.weekEarnings)) (\(cached.weekJobCount) jobs)")
                    .font(.caption)
                Text("Today: $\(String(format: "%.0f", cached.todayEarnings)) (\(cached.todayJobCount) jobs)")
                    .font(.caption)
                if let lastUpdated = cached.lastUpdated {
                    Text("Last updated: \(lastUpdated, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never updated - tap button below")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Divider()

                Text("Widget Reports:")
                    .font(.subheadline.bold())
                Text(defaults?.string(forKey: "widgetDebug1") ?? "No widget data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Update Cache Now") {
                // Manually trigger cache update
                let weekJobs = jobs.filter { job in
                    let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                    let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
                    return job.jobDate >= weekStart && job.jobDate < weekEnd
                }
                let weekEarnings = weekJobs.reduce(0.0) { $0 + $1.total(settings: settings) }

                let todayStart = Calendar.current.startOfDay(for: Date())
                let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
                let todayJobs = jobs.filter { $0.jobDate >= todayStart && $0.jobDate < todayEnd }
                let todayEarnings = todayJobs.reduce(0.0) { $0 + $1.total(settings: settings) }

                let jobSummaries = todayJobs.map { job in
                    CachedJobSummary(
                        jobNumber: job.jobNumber,
                        address: job.address,
                        total: job.total(settings: settings)
                    )
                }

                WidgetDataCache.save(
                    weekEarnings: weekEarnings,
                    weekJobCount: weekJobs.count,
                    todayEarnings: todayEarnings,
                    todayJobCount: todayJobs.count,
                    todayJobs: jobSummaries
                )
                WidgetCenter.shared.reloadAllTimelines()
            }
            .buttonStyle(.borderedProminent)

        } header: {
            Text("Widget Diagnostics")
        }
    }

    private var syncStatusSection: some View {
        Section {
            HStack {
                Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                    .foregroundStyle(networkMonitor.isConnected ? .green : .red)
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                Spacer()
                if syncManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if clerkAuth.isAuthenticated {
                if let lastSync = syncManager.lastSyncDate {
                    HStack {
                        Text("Last sync")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if let error = syncManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    syncManager.triggerSync()
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(syncManager.isSyncing || !networkMonitor.isConnected)

                Button {
                    forceFullSync()
                } label: {
                    Label("Force Full Upload", systemImage: "icloud.and.arrow.up")
                }
                .disabled(syncManager.isSyncing || !networkMonitor.isConnected)
                .foregroundStyle(.orange)
            } else {
                Text("Sign in to enable cloud sync")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Cloud Sync")
        } footer: {
            Text("Data syncs automatically in the background when online. Your local data is always available offline.")
        }
    }

    private var developerSection: some View {
        Section {
            Button("Reset Onboarding") {
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                dismiss()
            }
            .foregroundStyle(.orange)
        } header: {
            Text("Developer Options")
        } footer: {
            Text("Reset onboarding to test the first-launch experience. Close and reopen the app after resetting.")
        }
    }

    private var backupInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backup all your data to a file")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(jobs.count) jobs")
                    Text("\(invoices.count) invoices")
                    Text("\(expenses.count) expenses")
                    Text("\(mileageTrips.count) mileage trips")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                if let date = lastBackupDate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last backup")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var exportBackupButton: some View {
        Button {
            exportBackup()
        } label: {
            if isExporting {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Creating Backup...")
                }
            } else {
                Label("Export Backup", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(isExporting || (jobs.isEmpty && invoices.isEmpty && expenses.isEmpty))
    }

    private var importBackupButton: some View {
        Button {
            showingImportOptions = true
        } label: {
            Label("Import Backup", systemImage: "square.and.arrow.down")
        }
        .disabled(isImporting)
    }

    // MARK: - Alert Components

    private var importOptionsButtons: some View {
        Group {
            Button("Merge with Existing") {
                mergeMode = .merge
                if let backup = selectedICloudBackup {
                    restoreFromICloudBackup(backup)
                    selectedICloudBackup = nil
                } else {
                    showingImportPicker = true
                }
            }
            Button("Replace All Data", role: .destructive) {
                mergeMode = .replace
                if let backup = selectedICloudBackup {
                    restoreFromICloudBackup(backup)
                    selectedICloudBackup = nil
                } else {
                    showingImportPicker = true
                }
            }
            Button("Cancel", role: .cancel) {
                selectedICloudBackup = nil
            }
        }
    }

    @ViewBuilder
    private var importResultMessage: some View {
        if let result = importResult {
            Text("Successfully imported:\n• \(result.importedJobs) jobs\n• \(result.importedInvoices) invoices\n• \(result.importedExpenses) expenses\n• \(result.importedMileageTrips) mileage trips\(result.totalSkipped > 0 ? "\n\nSkipped \(result.totalSkipped) duplicate items" : "")")
        }
    }

    private var iCloudSignInButtons: some View {
        Group {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var iCloudBackupsSheet: some View {
        NavigationStack {
            List {
                if iCloudBackups.isEmpty {
                    ContentUnavailableView(
                        "No iCloud Backups",
                        systemImage: "icloud.slash",
                        description: Text("Create your first iCloud backup to see it here")
                    )
                } else {
                    ForEach(iCloudBackups) { backup in
                        Button {
                            selectedICloudBackup = backup
                            showingICloudBackups = false
                            showingImportOptions = true
                        } label: {
                            iCloudBackupRow(backup)
                        }
                    }
                }
            }
            .navigationTitle("iCloud Backups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingICloudBackups = false
                    }
                }
            }
        }
    }

    private func iCloudBackupRow(_ backup: BackupManager.ICloudBackupInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(backup.name)
                .font(.headline)
            HStack {
                Text(backup.creationDate, style: .date)
                Text("•")
                Text(backup.creationDate, style: .time)
                Text("•")
                Text(backup.formattedSize)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func forceFullSync() {
        let context = modelContext
        // Mark all jobs as pending sync
        let jobDescriptor = FetchDescriptor<Job>()
        if let allJobs = try? context.fetch(jobDescriptor) {
            for job in allJobs {
                job.syncStatusRaw = 1
                job.updatedAt = Date()
            }
        }
        // Mark all invoices as pending sync
        let invoiceDescriptor = FetchDescriptor<Invoice>()
        if let allInvoices = try? context.fetch(invoiceDescriptor) {
            for inv in allInvoices {
                inv.syncStatusRaw = 1
            }
        }
        // Mark all expenses as pending sync
        let expenseDescriptor = FetchDescriptor<Expense>()
        if let allExpenses = try? context.fetch(expenseDescriptor) {
            for exp in allExpenses {
                exp.syncStatusRaw = 1
            }
        }
        // Mark all mileage trips as pending sync
        let mileageDescriptor = FetchDescriptor<MileageTrip>()
        if let allTrips = try? context.fetch(mileageDescriptor) {
            for trip in allTrips {
                trip.syncStatusRaw = 1
            }
        }
        try? context.save()
        HapticManager.success()
        // Trigger sync
        syncManager.triggerSync()
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("✅ Backup saved to: \(url)")
            UserDefaults.standard.set(Date(), forKey: "lastBackupDate")
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                importBackup(from: url)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func backupToICloudNow() {
        isBackingUpToICloud = true

        Task {
            do {
                try await BackupManager.backupToICloud(
                    jobs: jobs,
                    invoices: invoices,
                    expenses: expenses,
                    mileageTrips: mileageTrips,
                    inventoryItems: inventoryItems
                )
                await MainActor.run {
                    isBackingUpToICloud = false
                    print("✅ iCloud backup complete")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isBackingUpToICloud = false
                }
            }
        }
    }

    private func loadICloudBackups() {
        Task {
            do {
                let backups = try BackupManager.listICloudBackups()
                await MainActor.run {
                    iCloudBackups = backups
                    showingICloudBackups = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load iCloud backups: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func restoreFromICloudBackup(_ backup: BackupManager.ICloudBackupInfo) {
        isImporting = true

        Task {
            do {
                let result = try BackupManager.restoreFromICloud(
                    backupURL: backup.url,
                    modelContext: modelContext,
                    mergeMode: mergeMode
                )

                await MainActor.run {
                    importResult = result
                    showingImportResult = true
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to restore from iCloud: \(error.localizedDescription)"
                    showingError = true
                    isImporting = false
                }
            }
        }
    }

    private func exportBackup() {
        isExporting = true

        Task {
            do {
                let url = try BackupManager.exportBackup(
                    jobs: jobs,
                    invoices: invoices,
                    expenses: expenses,
                    mileageTrips: mileageTrips,
                    inventoryItems: inventoryItems
                )
                await MainActor.run {
                    exportURL = url
                    showingExportSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create backup: \(error.localizedDescription)"
                    showingError = true
                    isExporting = false
                }
            }
        }
    }

    private func importBackup(from url: URL) {
        isImporting = true

        Task {
            do {
                // Start accessing security-scoped resource
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                // Copy to temp location
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                try FileManager.default.copyItem(at: url, to: tempURL)

                let result = try BackupManager.importBackup(
                    from: tempURL,
                    modelContext: modelContext,
                    mergeMode: mergeMode
                )

                await MainActor.run {
                    importResult = result
                    showingImportResult = true
                    isImporting = false
                }

                // Clean up
                try? FileManager.default.removeItem(at: tempURL)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to import backup: \(error.localizedDescription)"
                    showingError = true
                    isImporting = false
                }
            }
        }
    }

    private func signInToGmail() {
        isSigningIn = true

        Task {
            do {
                let email = try await gmailAuth.signIn()
                await MainActor.run {
                    isSigningIn = false

                    // Check access for external emails
                    if gmailAuth.pendingAccessCheck {
                        let authorizedEmails = chatUsers.map { $0.email }
                        if gmailAuth.isEmailAllowed(email, authorizedEmails: authorizedEmails) {
                            gmailAuth.confirmAccess()
                        } else {
                            gmailAuth.denyAccess()
                            showingAccessDenied = true
                        }
                    }

                    // Load user-specific settings for the newly signed-in user
                    Settings.shared.loadUserSettings()
                }
            } catch {
                await MainActor.run {
                    // Check if user cancelled
                    if (error as NSError).code == GIDSignInError.canceled.rawValue {
                        // User cancelled, no error message needed
                    } else {
                        errorMessage = "Gmail sign-in failed: \(error.localizedDescription)"
                        showingError = true
                    }
                    isSigningIn = false
                }
            }
        }
    }
}

// MARK: - Backup File Document

struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "plvbackup") ?? .data]
    }

    var url: URL?

    init(url: URL?) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url,
              let data = try? Data(contentsOf: url) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
