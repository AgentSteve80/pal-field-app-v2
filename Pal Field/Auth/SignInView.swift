//
//  SignInView.swift
//  Pal Field
//
//  Sign-in screen using Clerk iOS SDK.
//  Supports password + MFA (email code, TOTP, backup code).
//  Always allows skipping to local-only mode.
//

import SwiftUI
import ClerkKit

struct SignInView: View {
    @ObservedObject private var authManager = ClerkAuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var mfaCode = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    // MFA state
    @State private var needsMFA = false
    @State private var currentSignIn: SignIn?
    @State private var mfaType: MFAType = .emailCode
    @State private var isSendingCode = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    enum MFAType: String, CaseIterable {
        case emailCode = "Email Code"
        case totp = "Authenticator App"
        case backupCode = "Backup Code"
    }

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

                    Text(needsMFA ? "Enter verification code" : "Sign in to sync your data")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if needsMFA {
                    mfaView
                } else {
                    signInForm
                }

                Spacer()

                // Skip option — always available
                VStack(spacing: 8) {
                    Button {
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

    // MARK: - Sign In Form

    private var signInForm: some View {
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
    }

    // MARK: - MFA View

    private var mfaView: some View {
        VStack(spacing: 16) {
            // MFA type picker (if multiple options)
            Picker("Verification Method", selection: $mfaType) {
                ForEach(MFAType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            if mfaType == .emailCode {
                Text("A code was sent to your email")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                Button {
                    resendEmailCode()
                } label: {
                    if isSendingCode {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Resend Code")
                            .font(.caption)
                            .foregroundStyle(brandGreen)
                    }
                }
                .disabled(isSendingCode)
            } else if mfaType == .totp {
                Text("Enter code from your authenticator app")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Text("Enter one of your backup codes")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            TextField("Verification Code", text: $mfaCode)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.monospaced())
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                verifyMFA()
            } label: {
                if isSigningIn {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Verify")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(brandGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(isSigningIn || mfaCode.isEmpty)
            .opacity(mfaCode.isEmpty ? 0.6 : 1)
            .padding(.horizontal, 32)

            Button {
                // Go back to sign-in
                needsMFA = false
                currentSignIn = nil
                mfaCode = ""
                errorMessage = nil
            } label: {
                Text("← Back to sign in")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Actions

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
                    await handleComplete(signInResult)
                } else if signInResult.status == .needsSecondFactor {
                    // MFA required
                    print("🔐 SignIn: MFA required — showing verification screen")
                    await MainActor.run {
                        currentSignIn = signInResult
                        needsMFA = true
                        isSigningIn = false

                        // Auto-send email code
                        if mfaType == .emailCode {
                            resendEmailCode()
                        }
                    }
                } else {
                    await MainActor.run {
                        print("🔐 SignIn: Unexpected status = \(signInResult.status)")
                        errorMessage = "Unexpected status: \(signInResult.status). Please try again."
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

    private func verifyMFA() {
        guard var signIn = currentSignIn else { return }
        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                print("🔐 MFA: Verifying \(mfaType.rawValue) code...")

                switch mfaType {
                case .emailCode:
                    signIn = try await signIn.verifyMfaCode(mfaCode, type: .emailCode)
                case .totp:
                    signIn = try await signIn.verifyMfaCode(mfaCode, type: .totp)
                case .backupCode:
                    signIn = try await signIn.verifyMfaCode(mfaCode, type: .backupCode)
                }

                print("🔐 MFA: Result status = \(signIn.status)")

                if signIn.status == .complete {
                    await handleComplete(signIn)
                } else {
                    await MainActor.run {
                        errorMessage = "Verification incomplete. Please try again."
                        isSigningIn = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("🔐 MFA: FAILED — \(error)")
                    errorMessage = "Invalid code. Please try again."
                    mfaCode = ""
                    isSigningIn = false
                }
            }
        }
    }

    private func resendEmailCode() {
        guard var signIn = currentSignIn else { return }
        isSendingCode = true

        Task {
            do {
                print("🔐 MFA: Sending email code...")
                signIn = try await signIn.sendMfaEmailCode()
                await MainActor.run {
                    currentSignIn = signIn
                    isSendingCode = false
                    print("🔐 MFA: Email code sent")
                }
            } catch {
                await MainActor.run {
                    print("🔐 MFA: Send code failed — \(error)")
                    isSendingCode = false
                    errorMessage = "Failed to send code: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleComplete(_ signInResult: SignIn) async {
        print("🔐 SignIn: Status complete!")
        let clerk = Clerk.shared

        // Try to activate the session explicitly
        if let sessionId = signInResult.createdSessionId {
            print("🔐 SignIn: Activating session \(sessionId)...")
            do {
                try await clerk.auth.setActive(sessionId: sessionId)
            } catch {
                print("🔐 SignIn: setActive failed: \(error)")
            }
        } else {
            let sessions = clerk.auth.sessions
            print("🔐 SignIn: No createdSessionId. Sessions: \(sessions.count)")
            if let first = sessions.first {
                print("🔐 SignIn: Activating first session \(first.id)...")
                try? await clerk.auth.setActive(sessionId: first.id)
            }
        }

        // Wait for SDK state
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        let hasSession = clerk.session != nil
        let hasUser = clerk.user != nil
        print("🔐 SignIn: session=\(hasSession), user=\(hasUser)")

        // Verify Convex JWT
        if let session = clerk.session {
            let jwt = try? await session.getToken(.init(template: "convex"))
            print("🔐 SignIn: Convex JWT = \(jwt != nil)")
        }

        await MainActor.run {
            if hasUser {
                authManager.handleSessionChange()
            } else {
                // Force auth from email
                UserDefaults.standard.set(email, forKey: "clerkCachedEmail")
                authManager.forceAuthenticated()
            }
            isSigningIn = false
            dismiss()
        }
    }
}

#Preview {
    SignInView()
}
