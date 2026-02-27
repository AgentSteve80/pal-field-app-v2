//
//  ClerkAuthManager.swift
//  Pal Field
//
//  Manages Clerk authentication state. Caches tokens locally so the app
//  works offline after first sign-in. Does NOT gate any existing functionality.
//

import Foundation
import SwiftUI
import Combine
import ClerkKit

@MainActor
final class ClerkAuthManager: ObservableObject {
    static let shared = ClerkAuthManager()

    // MARK: - Published State

    /// Whether a valid Clerk session exists (cached or live)
    @Published var isAuthenticated: Bool = false

    /// Current user's Clerk ID
    @Published var clerkUserId: String?

    /// Current user's email from Clerk
    @Published var clerkEmail: String?

    /// Current user's display name
    @Published var clerkDisplayName: String?

    /// User role from Convex (cached locally)
    @Published var userRole: String = "tech"

    /// Whether Clerk SDK is still loading
    @Published var isLoading: Bool = true

    /// Error message for display
    @Published var errorMessage: String?

    // MARK: - Private

    /// Keys for local token cache
    private let cachedTokenKey = "clerkCachedSessionToken"
    private let cachedUserIdKey = "clerkCachedUserId"
    private let cachedEmailKey = "clerkCachedEmail"
    private let cachedDisplayNameKey = "clerkCachedDisplayName"
    private let cachedRoleKey = "clerkCachedRole"

    private var observationTask: Task<Void, Never>?

    private init() {
        // Load cached auth state immediately (offline support)
        loadCachedAuth()
    }

    // MARK: - Public API

    /// Configure and start observing Clerk state — call once at app launch
    func configure() {
        startObserving()
    }

    /// Get a fresh JWT token for Convex API calls.
    /// Returns cached token if offline.
    /// Get a JWT for Convex API calls (uses the "convex" JWT template)
    func getToken() async -> String? {
        let clerk = Clerk.shared

        // Try to get a fresh token from Clerk session using the Convex JWT template
        if let session = clerk.session {
            do {
                let jwt = try await session.getToken(template: "convex")
                if let jwt {
                    UserDefaults.standard.set(jwt, forKey: cachedTokenKey)
                }
                return jwt
            } catch {
                print("⚠️ ClerkAuth: Failed to get fresh token: \(error)")
            }
        }

        // Fall back to cached token
        return UserDefaults.standard.string(forKey: cachedTokenKey)
    }

    /// Sign out — clears cached tokens
    func signOut() async {
        let clerk = Clerk.shared
        do {
            try await clerk.auth.signOut()
        } catch {
            print("⚠️ ClerkAuth: Sign out error: \(error)")
        }

        clearCachedAuth()
        isAuthenticated = false
        clerkUserId = nil
        clerkEmail = nil
        clerkDisplayName = nil
        userRole = "tech"
    }

    /// Whether we have any cached credentials (for offline access)
    var hasCachedCredentials: Bool {
        UserDefaults.standard.string(forKey: cachedTokenKey) != nil
    }

    // MARK: - Private Helpers

    private func loadCachedAuth() {
        if let userId = UserDefaults.standard.string(forKey: cachedUserIdKey) {
            clerkUserId = userId
            clerkEmail = UserDefaults.standard.string(forKey: cachedEmailKey)
            clerkDisplayName = UserDefaults.standard.string(forKey: cachedDisplayNameKey)
            userRole = UserDefaults.standard.string(forKey: cachedRoleKey) ?? "tech"
            isAuthenticated = true
        }
        isLoading = false
    }

    private func cacheAuth(userId: String, email: String?, displayName: String?) {
        UserDefaults.standard.set(userId, forKey: cachedUserIdKey)
        if let email { UserDefaults.standard.set(email, forKey: cachedEmailKey) }
        if let displayName { UserDefaults.standard.set(displayName, forKey: cachedDisplayNameKey) }
    }

    private func clearCachedAuth() {
        UserDefaults.standard.removeObject(forKey: cachedTokenKey)
        UserDefaults.standard.removeObject(forKey: cachedUserIdKey)
        UserDefaults.standard.removeObject(forKey: cachedEmailKey)
        UserDefaults.standard.removeObject(forKey: cachedDisplayNameKey)
        UserDefaults.standard.removeObject(forKey: cachedRoleKey)
    }

    private func startObserving() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            // Poll Clerk state periodically until we get a user or task is cancelled
            while !Task.isCancelled {
                self?.handleSessionChange()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
        // Also check immediately
        handleSessionChange()
    }

    func handleSessionChange() {
        let clerk = Clerk.shared
        if let user = clerk.user {
            let userId = user.id
            let email = user.primaryEmailAddress?.emailAddress
            let firstName = user.firstName ?? ""
            let lastName = user.lastName ?? ""
            let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

            clerkUserId = userId
            clerkEmail = email
            clerkDisplayName = displayName.isEmpty ? email : displayName
            isAuthenticated = true
            isLoading = false

            // Only cache if this is a new sign-in (not every poll)
            if clerkUserId != userId || !isAuthenticated {
                cacheAuth(userId: userId, email: email, displayName: displayName.isEmpty ? nil : displayName)

                Task {
                    await ConvexSyncManager.shared.upsertUser()
                }
            }
        } else if clerk.session == nil && !hasCachedCredentials {
            isAuthenticated = false
            isLoading = false
        }
    }

    /// Update cached role from Convex
    func updateCachedRole(_ role: String) {
        userRole = role
        UserDefaults.standard.set(role, forKey: cachedRoleKey)
    }
}
