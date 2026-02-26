//
//  BackgroundEmailChecker.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import Foundation
import BackgroundTasks
import UserNotifications

class BackgroundEmailChecker {
    static let shared = BackgroundEmailChecker()

    private let backgroundTaskIdentifier = "com.prewire.emailcheck"
    private let schedulingEmail = "plvscheduling@pallowvoltage.com"
    private let gmailService = GmailService()
    private let authManager = GmailAuthManager.shared

    // UserDefaults key to track last seen email IDs
    private let lastSeenEmailsKey = "lastSeenSchedulingEmails"

    private init() {}

    // MARK: - Registration

    /// Register background task - call this in AppDelegate or App init
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }

        print("📱 Background task registered: \(backgroundTaskIdentifier)")
    }

    // MARK: - Scheduling

    /// Schedule the next background refresh
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)

        // Schedule for 20 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh scheduled for 20 minutes from now")
        } catch {
            print("❌ Could not schedule background refresh: \(error)")
        }
    }

    // MARK: - Background Task Handler

    private func handleBackgroundTask(task: BGAppRefreshTask) {
        print("📧 Background task started at \(Date())")

        // Schedule the next refresh
        scheduleBackgroundRefresh()

        // Set expiration handler
        task.expirationHandler = {
            print("⏱ Background task expired")
        }

        // Check if we're within the allowed time window (3pm-10pm EST)
        guard isWithinCheckingHours() else {
            print("⏰ Outside checking hours (3pm-10pm EST)")
            task.setTaskCompleted(success: true)
            return
        }

        // Check if user is signed in
        guard authManager.isSignedIn else {
            print("⚠️ User not signed in to Gmail")
            task.setTaskCompleted(success: true)
            return
        }

        // Perform email check
        Task {
            await checkForNewEmails()
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Time Check

    private func isWithinCheckingHours() -> Bool {
        let estTimeZone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = estTimeZone

        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Check if between 3pm (15) and 10pm (22)
        return hour >= 15 && hour < 22
    }

    // MARK: - Email Checking

    /// Public method for SwiftUI background task
    func performBackgroundCheck() async {
        print("📧 Background task started at \(Date())")

        // Schedule the next refresh
        scheduleBackgroundRefresh()

        // Check if we're within the allowed time window (3pm-10pm EST)
        guard isWithinCheckingHours() else {
            print("⏰ Outside checking hours (3pm-10pm EST)")
            return
        }

        // Check if user is signed in
        guard authManager.isSignedIn else {
            print("⚠️ User not signed in to Gmail")
            return
        }

        // Perform email check
        await checkForNewEmails()
    }

    private func checkForNewEmails() async {
        print("📬 Checking for new emails from \(schedulingEmail)")

        do {
            // Fetch recent emails from scheduling
            let emails = try await gmailService.fetchMessages(from: schedulingEmail, maxResults: 10)

            // Get last seen email IDs
            let lastSeenIDs = getLastSeenEmailIDs()

            // Find new emails (emails we haven't seen before)
            let newEmails = emails.filter { !lastSeenIDs.contains($0.id) }

            if !newEmails.isEmpty {
                print("✨ Found \(newEmails.count) new email(s)")

                // Save the new email IDs
                updateLastSeenEmailIDs(emails.map { $0.id })

                // Show notification
                await showNotification(count: newEmails.count)
            } else {
                print("📭 No new emails")
            }

        } catch {
            print("❌ Error checking emails: \(error)")
        }
    }

    // MARK: - Email ID Tracking

    private func getLastSeenEmailIDs() -> Set<String> {
        if let data = UserDefaults.standard.data(forKey: lastSeenEmailsKey),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            return Set(ids)
        }
        return []
    }

    private func updateLastSeenEmailIDs(_ newIDs: [String]) {
        // Keep only the most recent 50 IDs to avoid unlimited growth
        let idsToKeep = Array(newIDs.prefix(50))

        if let data = try? JSONEncoder().encode(idsToKeep) {
            UserDefaults.standard.set(data, forKey: lastSeenEmailsKey)
        }
    }

    // MARK: - Notifications

    /// Request notification permissions
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
    }

    private func showNotification(count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "New Job Received"
        content.body = count == 1 ? "You have a new job from Scheduling" : "You have \(count) new jobs from Scheduling"
        content.sound = .default
        content.badge = NSNumber(value: count)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Notification sent")
        } catch {
            print("❌ Failed to show notification: \(error)")
        }
    }
}
