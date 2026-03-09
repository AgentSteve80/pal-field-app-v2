//
//  SignInView.swift
//  Pal Field
//
//  Sign-in screen using Clerk iOS SDK.
//  Shows on first launch or when no cached session exists.
//  Always allows skipping to local-only mode.
//

import SwiftUI
import ClerkKit

struct SignInView: View {
    @ObservedObject private var authManager = ClerkAuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showingSignUp = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo area
                VStack(spacing: 12) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(brandGreen)

                    Text("Pal Field")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Sign in to sync your data")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Sign in form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        signIn()
                    } label: {
                        if isSigningIn {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isSigningIn || email.isEmpty || password.isEmpty)
                    .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Skip option — always available
                VStack(spacing: 8) {
                    Button {
                        // Skip sign-in, continue in local-only mode
                        dismiss()
                    } label: {
                        Text("Continue without signing in")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Text("You can sign in later from Settings")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func signIn() {
        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                let clerk = Clerk.shared
                print("🔐 SignIn: Attempting sign-in for \(email)...")
                let signInResult = try await clerk.auth.signInWithPassword(identifier: email, password: password)
                print("🔐 SignIn: Result status = \(signInResult.status)")

                if signInResult.status == .complete {
                    print("🔐 SignIn: Status complete!")
                    
                    // Try to activate the session explicitly
                    if let sessionId = signInResult.createdSessionId {
                        print("🔐 SignIn: Activating created session \(sessionId)...")
                        try await clerk.auth.setActive(sessionId: sessionId)
                    } else {
                        // No createdSessionId — try getting it from sessions list
                        let sessions = clerk.auth.sessions
                        print("🔐 SignIn: No createdSessionId. Available sessions: \(sessions.count)")
                        if let firstSession = sessions.first {
                            print("🔐 SignIn: Activating first session \(firstSession.id)...")
                            try await clerk.auth.setActive(sessionId: firstSession.id)
                        }
                    }

                    // Wait for SDK state to propagate
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                    
                    // Check state
                    let hasSession = clerk.session != nil
                    let hasUser = clerk.user != nil
                    let sessions = clerk.auth.sessions
                    print("🔐 SignIn: session=\(hasSession), user=\(hasUser), sessions=\(sessions.count)")
                    
                    // Try getting a Convex JWT to verify
                    if let session = clerk.session {
                        let convexToken = try? await session.getToken(.init(template: "convex"))
                        print("🔐 SignIn: Convex JWT = \(convexToken != nil)")
                    }
                    
                    await MainActor.run {
                        // Force auth state update
                        if hasUser {
                            authManager.handleSessionChange()
                        } else {
                            // User is nil but sign-in succeeded — cache what we know and force auth
                            print("🔐 SignIn: clerk.user is nil, caching from sign-in email")
                            // We at least know the email they signed in with
                            UserDefaults.standard.set(email, forKey: "clerkCachedEmail")
                            UserDefaults.standard.set(signInResult.id ?? "unknown", forKey: "clerkCachedUserId")
                            authManager.forceAuthenticated()
                        }
                        
                        isSigningIn = false
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        print("🔐 SignIn: Incomplete — status = \(signInResult.status)")
                        errorMessage = "Sign-in incomplete (status: \(signInResult.status)). Please try again."
                        isSigningIn = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("🔐 SignIn: FAILED — \(error)")
                    errorMessage = "Sign-in failed: \(error.localizedDescription)"
                    isSigningIn = false
                }
            }
        }
    }
}

#Preview {
    SignInView()
}
