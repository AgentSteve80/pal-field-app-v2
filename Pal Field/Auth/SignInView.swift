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
                let signIn = try await clerk.auth.signInWithPassword(identifier: email, password: password)

                // Log what we got back
                print("🔐 SignIn: signInWithPassword returned — status=\(signIn.status)")
                print("🔐 SignIn: createdSessionId=\(signIn.createdSessionId ?? "nil")")
                print("🔐 SignIn: firstFactorVerification=\(String(describing: signIn.firstFactorVerification))")
                print("🔐 SignIn: secondFactorVerification=\(String(describing: signIn.secondFactorVerification))")
                print("🔐 SignIn: supportedSecondFactors=\(String(describing: signIn.supportedSecondFactors))")
                print("🔐 SignIn: identifier=\(signIn.identifier ?? "nil")")
                print("🔐 SignIn: clerk.session=\(clerk.session?.id ?? "nil"), clerk.user=\(clerk.user?.id ?? "nil")")
                await MainActor.run {
                    authManager.handleSessionChange()
                    print("🔐 SignIn: isAuthenticated=\(authManager.isAuthenticated)")
                    isSigningIn = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
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
