//
//  ConvexSyncManager.swift
//  Pal Field
//
//  Background sync engine that pushes/pulls data between SwiftData and Convex.
//  Uses Convex HTTP API. Runs entirely in the background — never blocks the UI.
//  SwiftData remains the source of truth.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ConvexSyncManager: ObservableObject {
    static let shared = ConvexSyncManager()

    // MARK: - Configuration

    private let convexUrl = "https://brazen-seal-477.convex.cloud"
    private let maxRetries = 5

    // MARK: - Published State

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: Int = 0
    @Published var lastError: String?

    // MARK: - Private

    private var modelContainer: ModelContainer?
    private var networkObserver: AnyCancellable?
    private var retryCount: Int = 0
    private var syncTask: Task<Void, Never>?

    private init() {
        // Listen for connectivity restored
        networkObserver = NotificationCenter.default.publisher(for: .networkConnectivityRestored)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.triggerSync()
                }
            }
    }

    // MARK: - Setup

    func configure(container: ModelContainer) {
        self.modelContainer = container
        if NetworkMonitor.shared.isConnected {
            triggerSync()
        }
    }

    // MARK: - Public API

    /// Trigger a full sync cycle (background, non-blocking)
    func triggerSync() {
        guard !isSyncing else { return }
        guard NetworkMonitor.shared.isConnected else {
            print("📡 ConvexSync: Offline, skipping sync")
            return
        }

        syncTask?.cancel()
        syncTask = Task {
            await performSync()
        }
    }

    /// Upsert the current user to Convex after Clerk sign-in
    func upsertUser() async {
        guard NetworkMonitor.shared.isConnected else { return }
        let auth = ClerkAuthManager.shared

        guard let token = await auth.getToken(),
              let email = auth.clerkEmail else { return }

        let args: [String: Any] = [
            "email": email,
            "name": auth.clerkDisplayName ?? "",
            "clerkId": auth.clerkUserId ?? ""
        ]

        do {
            let response = try await callMutation("appSync:upsertUser", args: args, token: token)
            // If response includes a role, cache it
            if let value = response.value?.value as? [String: Any],
               let role = value["role"] as? String {
                auth.updateCachedRole(role)
            }
            print("✅ ConvexSync: User upserted")
        } catch {
            print("⚠️ ConvexSync: User upsert failed: \(error)")
        }
    }

    // MARK: - Sync Engine

    private func performSync() async {
        guard let container = modelContainer else { return }

        isSyncing = true
        lastError = nil

        do {
            guard let token = await ClerkAuthManager.shared.getToken() else {
                lastError = "No auth token available"
                isSyncing = false
                return
            }

            // Always ensure user exists in Convex
            await upsertUser()

            // Upload pending local changes
            try await uploadPendingJobs(container: container, token: token)
            try await uploadPendingInvoices(container: container, token: token)
            try await uploadPendingExpenses(container: container, token: token)
            try await uploadPendingMileageTrips(container: container, token: token)
            try await uploadPendingChatMessages(container: container, token: token)
            try await uploadPendingInventory(container: container, token: token)

            // Download server changes
            try await downloadJobs(container: container, token: token)
            try await downloadChatMessages(container: container, token: token)

            lastSyncDate = Date()
            retryCount = 0
            pendingChanges = 0
            print("✅ ConvexSync: Sync complete")

        } catch {
            lastError = error.localizedDescription
            print("⚠️ ConvexSync: Sync failed: \(error)")

            // Retry with exponential backoff
            if retryCount < maxRetries {
                retryCount += 1
                let delay = pow(2.0, Double(retryCount)) // 2, 4, 8, 16, 32 seconds
                try? await Task.sleep(for: .seconds(delay))
                if !Task.isCancelled {
                    await performSync()
                }
            }
        }

        isSyncing = false
    }

    // MARK: - Upload Methods

    private func uploadPendingJobs(container: ModelContainer, token: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Job>(predicate: #Predicate { $0.syncStatusRaw == 1 })
        let pendingJobs = try context.fetch(descriptor)

        for job in pendingJobs {
            let args: [String: Any] = [
                "localId": job.id.uuidString,
                "jobNumber": job.jobNumber,
                "jobDate": job.jobDate.timeIntervalSince1970 * 1000,
                "lotNumber": job.lotNumber,
                "address": job.address,
                "subdivision": job.subdivision,
                "prospect": job.prospect,
                "wireRuns": job.wireRuns,
                "enclosure": job.enclosure,
                "flatPanelStud": job.flatPanelStud,
                "flatPanelWall": job.flatPanelWall,
                "flatPanelRemote": job.flatPanelRemote,
                "flexTube": job.flexTube,
                "mediaBox": job.mediaBox,
                "dryRun": job.dryRun,
                "serviceRun": job.serviceRun,
                "miles": job.miles,
                "builderCompany": job.builderCompany,
                "ownerEmail": job.ownerEmail,
                "isCloseoutComplete": job.isCloseoutComplete,
                "totalAmount": job.total(settings: Settings.shared),
                "updatedAt": job.updatedAt.timeIntervalSince1970 * 1000
            ]

            let response = try await callMutation("appSync:upsertJob", args: args, token: token)
            if let value = response.value?.value as? [String: Any],
               let convexId = value["_id"] as? String {
                job.convexId = convexId
                job.syncStatusRaw = SyncStatus.synced.rawValue
            }
        }
        try context.save()
    }

    private func uploadPendingInvoices(container: ModelContainer, token: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Invoice>(predicate: #Predicate { $0.syncStatusRaw == 1 })
        let pending = try context.fetch(descriptor)

        for invoice in pending {
            let args: [String: Any] = [
                "localId": invoice.id.uuidString,
                "weekStart": invoice.weekStart.timeIntervalSince1970 * 1000,
                "weekEnd": invoice.weekEnd.timeIntervalSince1970 * 1000,
                "total": invoice.total,
                "jobCount": invoice.jobCount,
                "ownerEmail": invoice.ownerEmail,
                "updatedAt": invoice.updatedAt.timeIntervalSince1970 * 1000
            ]

            let response = try await callMutation("appSync:upsertInvoice", args: args, token: token)
            if let value = response.value?.value as? [String: Any],
               let convexId = value["_id"] as? String {
                invoice.convexId = convexId
                invoice.syncStatusRaw = SyncStatus.synced.rawValue
            }
        }
        try context.save()
    }

    private func uploadPendingExpenses(container: ModelContainer, token: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.syncStatusRaw == 1 })
        let pending = try context.fetch(descriptor)

        for expense in pending {
            // Sync metadata only — no receipt image data
            let args: [String: Any] = [
                "localId": expense.id.uuidString,
                "date": expense.date.timeIntervalSince1970 * 1000,
                "category": expense.category,
                "amount": expense.amount,
                "merchant": expense.merchant,
                "notes": expense.notes,
                "ownerEmail": expense.ownerEmail,
                "updatedAt": expense.updatedAt.timeIntervalSince1970 * 1000
            ]

            let response = try await callMutation("appSync:upsertExpense", args: args, token: token)
            if let value = response.value?.value as? [String: Any],
               let convexId = value["_id"] as? String {
                expense.convexId = convexId
                expense.syncStatusRaw = SyncStatus.synced.rawValue
            }
        }
        try context.save()
    }

    private func uploadPendingMileageTrips(container: ModelContainer, token: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MileageTrip>(predicate: #Predicate { $0.syncStatusRaw == 1 })
        let pending = try context.fetch(descriptor)

        for trip in pending {
            var args: [String: Any] = [
                "localId": trip.id.uuidString,
                "startDate": trip.startDate.timeIntervalSince1970 * 1000,
                "miles": trip.miles,
                "purpose": trip.purpose,
                "notes": trip.notes,
                "ownerEmail": trip.ownerEmail,
                "updatedAt": trip.updatedAt.timeIntervalSince1970 * 1000
            ]
            if let endDate = trip.endDate {
                args["endDate"] = endDate.timeIntervalSince1970 * 1000
            }

            let response = try await callMutation("appSync:upsertMileageTrip", args: args, token: token)
            if let value = response.value?.value as? [String: Any],
               let convexId = value["_id"] as? String {
                trip.convexId = convexId
                trip.syncStatusRaw = SyncStatus.synced.rawValue
            }
        }
        try context.save()
    }

    private func uploadPendingChatMessages(container: ModelContainer, token: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TeamChatMessage>(predicate: #Predicate { $0.syncStatusRaw == 1 })
        let pending = try context.fetch(descriptor)

        for message in pending {
            let args: [String: Any] = [
                "localId": message.id.uuidString,
                "senderName": message.senderName,
                "senderEmail": message.senderEmail,
                "messageText": message.messageText,
                "timestamp": message.timestamp.timeIntervalSince1970 * 1000,
                "recipientEmail": message.recipientEmail,
                "isDirectMessage": message.isDirectMessage,
                "updatedAt": message.updatedAt.timeIntervalSince1970 * 1000
            ]

            let response = try await callMutation("appSync:upsertChatMessage", args: args, token: token)
            if let value = response.value?.value as? [String: Any],
               let convexId = value["_id"] as? String {
                message.convexId = convexId
                message.syncStatusRaw = SyncStatus.synced.rawValue
            }
        }
        try context.save()
    }

    private func uploadPendingInventory(container: ModelContainer, token: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<InventoryItem>(predicate: #Predicate { $0.syncStatusRaw == 1 })
        let pending = try context.fetch(descriptor)

        for item in pending {
            let args: [String: Any] = [
                "localId": item.id.uuidString,
                "supplier": item.supplier,
                "category": item.category,
                "itemNumber": item.itemNumber,
                "quantity": item.quantity,
                "lengthFeet": item.lengthFeet,
                "status": item.status,
                "notes": item.notes,
                "ownerEmail": item.ownerEmail
            ]

            let response = try await callMutation("appSync:upsertInventory", args: args, token: token)
            if let value = response.value?.value as? [String: Any],
               let convexId = value["_id"] as? String {
                item.convexId = convexId
                item.syncStatusRaw = 0 // synced
            }
        }
        try context.save()
    }

    // MARK: - Download Methods

    private func downloadJobs(container: ModelContainer, token: String) async throws {
        let lastSync = lastSyncDate?.timeIntervalSince1970 ?? 0
        let args: [String: Any] = ["since": lastSync * 1000]

        let response = try await callQuery("appSync:listJobsForApp", args: args, token: token)
        guard let jobs = response.value?.value as? [[String: Any]] else { return }

        let context = ModelContext(container)
        for jobData in jobs {
            guard let convexId = jobData["_id"] as? String else { continue }
            let serverUpdatedAt = (jobData["updatedAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()

            // Check if we already have this job locally
            let descriptor = FetchDescriptor<Job>(predicate: #Predicate { $0.convexId == convexId })
            let existing = try context.fetch(descriptor)

            if let local = existing.first {
                // Last-write-wins: only overwrite if server is newer
                if serverUpdatedAt > local.updatedAt {
                    updateJobFromServer(local, data: jobData)
                    local.syncStatusRaw = SyncStatus.synced.rawValue
                }
            } else {
                // New job from server (admin-assigned)
                let newJob = Job()
                updateJobFromServer(newJob, data: jobData)
                newJob.convexId = convexId
                newJob.syncStatusRaw = SyncStatus.synced.rawValue
                context.insert(newJob)
            }
        }
        try context.save()
    }

    private func downloadChatMessages(container: ModelContainer, token: String) async throws {
        let lastSync = lastSyncDate?.timeIntervalSince1970 ?? 0
        let args: [String: Any] = ["since": lastSync * 1000]

        let response = try await callQuery("appSync:listChatMessagesForApp", args: args, token: token)
        guard let messages = response.value?.value as? [[String: Any]] else { return }

        let context = ModelContext(container)
        for msgData in messages {
            guard let convexId = msgData["_id"] as? String else { continue }

            let descriptor = FetchDescriptor<TeamChatMessage>(predicate: #Predicate { $0.convexId == convexId })
            let existing = try context.fetch(descriptor)

            if existing.isEmpty {
                // New message from server
                let msg = TeamChatMessage(
                    senderName: msgData["senderName"] as? String ?? "",
                    senderEmail: msgData["senderEmail"] as? String ?? "",
                    message: msgData["messageText"] as? String ?? ""
                )
                if let recipientEmail = msgData["recipientEmail"] as? String, !recipientEmail.isEmpty {
                    msg.recipientEmail = recipientEmail
                    msg.isDirectMessage = true
                }
                if let ts = msgData["timestamp"] as? Double {
                    msg.timestamp = Date(timeIntervalSince1970: ts / 1000)
                }
                msg.convexId = convexId
                msg.syncStatusRaw = SyncStatus.synced.rawValue
                context.insert(msg)
            }
        }
        try context.save()
    }

    // MARK: - Helpers

    private func updateJobFromServer(_ job: Job, data: [String: Any]) {
        job.jobNumber = data["jobNumber"] as? String ?? job.jobNumber
        if let dateStr = data["jobDate"] as? String {
            // Convex stores jobDate as ISO date string "2026-02-28"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateStr) { job.jobDate = date }
        } else if let ts = data["jobDate"] as? Double {
            job.jobDate = Date(timeIntervalSince1970: ts / 1000)
        }
        job.lotNumber = data["lotNumber"] as? String ?? job.lotNumber
        job.address = data["address"] as? String ?? job.address
        job.subdivision = data["subdivision"] as? String ?? job.subdivision
        // Convex stores "prospect" as "prospectNumber"
        job.prospect = data["prospectNumber"] as? String ?? data["prospect"] as? String ?? job.prospect
        // Convex uses plural field names for counts
        job.wireRuns = data["wireRuns"] as? Int ?? job.wireRuns
        job.enclosure = data["enclosures"] as? Int ?? data["enclosure"] as? Int ?? job.enclosure
        job.flatPanelStud = data["flatPanelsStud"] as? Int ?? data["flatPanelStud"] as? Int ?? job.flatPanelStud
        job.flatPanelWall = data["flatPanelsWall"] as? Int ?? data["flatPanelWall"] as? Int ?? job.flatPanelWall
        job.flatPanelRemote = data["flatPanelsRemote"] as? Int ?? data["flatPanelRemote"] as? Int ?? job.flatPanelRemote
        job.flexTube = data["flexTube"] as? Int ?? job.flexTube
        job.mediaBox = data["mediaBox"] as? Int ?? job.mediaBox
        job.dryRun = data["dryRuns"] as? Int ?? data["dryRun"] as? Int ?? job.dryRun
        job.serviceRun = data["serviceRun"] as? Int ?? job.serviceRun
        // Convex stores miles as "mileageFromHome"
        job.miles = data["mileageFromHome"] as? Double ?? data["miles"] as? Double ?? job.miles
        job.builderCompany = data["builderCompany"] as? String ?? job.builderCompany
        job.ownerEmail = data["ownerEmail"] as? String ?? job.ownerEmail
        // Convex stores status as string, map to bool
        if let status = data["status"] as? String {
            job.isCloseoutComplete = (status == "completed")
        } else {
            job.isCloseoutComplete = data["isCloseoutComplete"] as? Bool ?? job.isCloseoutComplete
        }
        if let ts = data["updatedAt"] as? Double { job.updatedAt = Date(timeIntervalSince1970: ts / 1000) }
    }

    // MARK: - Convex HTTP API

    private func callMutation(_ path: String, args: [String: Any], token: String) async throws -> ConvexResponse {
        try await callConvex(endpoint: "mutation", path: path, args: args, token: token)
    }

    private func callQuery(_ path: String, args: [String: Any], token: String) async throws -> ConvexResponse {
        try await callConvex(endpoint: "query", path: path, args: args, token: token)
    }

    private func callConvex(endpoint: String, path: String, args: [String: Any], token: String) async throws -> ConvexResponse {
        let url = URL(string: "\(convexUrl)/api/\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "path": path,
            "args": args,
            "format": "json"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ConvexSyncError.serverError(http.statusCode, errorBody)
        }

        return try JSONDecoder().decode(ConvexResponse.self, from: data)
    }
}

// MARK: - Errors

enum ConvexSyncError: LocalizedError {
    case serverError(Int, String)
    case noToken

    var errorDescription: String? {
        switch self {
        case .serverError(let code, let msg): return "Convex error \(code): \(msg)"
        case .noToken: return "No authentication token available"
        }
    }
}
