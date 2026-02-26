//
//  GmailAuthManager.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import Foundation
import Combine
import GoogleSignIn
import UIKit

// MARK: - Google Sign-In URL Scheme
// IMPORTANT: Add the following reversed client ID as a URL Scheme in
// Target > Info > URL Types. This is required for the sign-in redirect.
// Reversed Client ID (copy into URL Schemes):
// com.googleusercontent.apps.814472950392-aec7v85kqa58uj43pqjf73q8gvft0i31
private let reversedClientID = "com.googleusercontent.apps.814472950392-aec7v85kqa58uj43pqjf73q8gvft0i31"

@MainActor
class GmailAuthManager: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var authError: String?
    @Published var accessDenied: Bool = false
    @Published var pendingAccessCheck: Bool = false  // True when signed in but not yet verified

    private let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.send"
    ]
    private let clientID = "814472950392-aec7v85kqa58uj43pqjf73q8gvft0i31.apps.googleusercontent.com"

    // Singleton instance
    static let shared = GmailAuthManager()

    private init() {
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Check for existing auth
        checkExistingAuth()
    }

    // MARK: - Access Control

    /// Check if an email is allowed to use the app
    /// - @pallowvoltage.com emails are always allowed
    /// - Other emails must be in the ChatUser database
    func isEmailAllowed(_ email: String, authorizedEmails: [String]) -> Bool {
        let lowercasedEmail = email.lowercased()

        // @pallowvoltage.com emails are always allowed
        if lowercasedEmail.hasSuffix("@pallowvoltage.com") {
            return true
        }

        // Check if email is in the authorized list (from ChatUser)
        return authorizedEmails.contains { $0.lowercased() == lowercasedEmail }
    }

    /// Deny access and sign out
    func denyAccess() {
        accessDenied = true
        signOut()
    }

    /// Clear access denied state
    func clearAccessDenied() {
        accessDenied = false
    }

    // MARK: - Public Methods

    /// Check if user is already signed in
    func checkExistingAuth() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let user = user {
                    let email = user.profile?.email ?? ""
                    self.userEmail = email

                    // If @pallowvoltage.com, allow immediately
                    if email.lowercased().hasSuffix("@pallowvoltage.com") {
                        self.isSignedIn = true
                        self.pendingAccessCheck = false
                        print("✅ Restored Gmail session (org user): \(self.userEmail)")
                    } else {
                        // External email - needs verification against ChatUser
                        self.isSignedIn = true
                        self.pendingAccessCheck = true
                        print("⏳ Restored Gmail session (pending verification): \(self.userEmail)")
                    }
                } else {
                    self.isSignedIn = false
                    self.pendingAccessCheck = false
                    if let error = error {
                        print("⚠️ No previous session: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Sign in with Google
    /// Returns the email for access verification by the caller
    func signIn() async throws -> String {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw GmailError.noViewController
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: scopes
            )

            let email = result.user.profile?.email ?? ""
            self.userEmail = email
            self.authError = nil
            self.accessDenied = false

            // If @pallowvoltage.com, allow immediately
            if email.lowercased().hasSuffix("@pallowvoltage.com") {
                self.isSignedIn = true
                self.pendingAccessCheck = false
                print("✅ Gmail sign-in successful (org user): \(self.userEmail)")
            } else {
                // External email - caller must verify against ChatUser
                self.isSignedIn = true
                self.pendingAccessCheck = true
                print("⏳ Gmail sign-in successful (pending verification): \(self.userEmail)")
            }

            return email
        } catch {
            self.authError = error.localizedDescription
            print("❌ Gmail sign-in failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Confirm access after verification (call when external email is found in ChatUser)
    func confirmAccess() {
        pendingAccessCheck = false
        print("✅ Access confirmed for: \(userEmail)")
    }

    /// Sign out
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = ""
        print("👋 Signed out of Gmail")
    }

    /// Get current access token for API calls
    func getAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GmailError.notAuthenticated
        }

        // Refresh token if needed
        do {
            try await user.refreshTokensIfNeeded()
        } catch {
            print("❌ Token refresh failed: \(error.localizedDescription)")
            throw GmailError.noAccessToken
        }

        let accessToken = user.accessToken.tokenString
        if accessToken.isEmpty {
            throw GmailError.noAccessToken
        }
        return accessToken
    }

    /// Check if user has granted the required Gmail scope
    func hasRequiredScope() -> Bool {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            return false
        }

        return user.grantedScopes?.contains("https://www.googleapis.com/auth/gmail.readonly") ?? false
    }
}

