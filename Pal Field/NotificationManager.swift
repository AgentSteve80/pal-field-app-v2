//
//  NotificationManager.swift
//  Pal Field
//
//  Local morning digest notification scheduler.
//

import Foundation
import Combine
import UserNotifications
import SwiftData

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private let notificationId = "pal-field-morning-digest"
    
    private init() {
        checkAuthorization()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.isAuthorized = granted
                if granted {
                    self?.scheduleMorningDigest()
                }
            }
        }
    }
    
    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Schedule the daily morning digest notification.
    func scheduleMorningDigest() {
        let enabled = UserDefaults.standard.bool(forKey: "morningDigestEnabled")
        guard enabled else {
            cancelMorningDigest()
            return
        }
        
        let hour = UserDefaults.standard.object(forKey: "morningDigestHour") as? Int ?? 6
        let minute = UserDefaults.standard.object(forKey: "morningDigestMinute") as? Int ?? 0
        
        // Remove old one before scheduling
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        
        let content = UNMutableNotificationContent()
        content.title = "Good Morning ☀️"
        content.body = "Ready to work? Open Pal Field to see today's jobs."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Failed to schedule morning digest: \(error)")
            } else {
                print("✅ Morning digest scheduled for \(hour):\(String(format: "%02d", minute))")
            }
        }
    }
    
    func cancelMorningDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
}
