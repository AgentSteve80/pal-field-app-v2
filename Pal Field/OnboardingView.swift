//
//  OnboardingView.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import GoogleSignIn

struct OnboardingView: View {
    @EnvironmentObject private var settings: Settings
    @Binding var isOnboardingComplete: Bool

    @State private var currentPage = 0
    @State private var isSigningIn = false
    @State private var signInError: String?

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator (2 pages only)
                HStack(spacing: 8) {
                    ForEach(0..<2) { index in
                        Circle()
                            .fill(index == currentPage ? brandGreen : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)

                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    WelcomePage()
                        .tag(0)

                    // Page 2: Sign In (required)
                    SignInPage(
                        isSigningIn: $isSigningIn,
                        signInError: $signInError,
                        onGoogleSignIn: signInWithGoogle
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                HStack {
                    Spacer()

                    // Only show Next on welcome page (page 0)
                    if currentPage == 0 {
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            HStack {
                                Text("Next")
                                Image(systemName: "arrow.right")
                            }
                            .foregroundStyle(brandGreen)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
    }

    private func signInWithGoogle() {
        isSigningIn = true
        signInError = nil

        Task {
            do {
                try await GmailAuthManager.shared.signIn()

                await MainActor.run {
                    isSigningIn = false

                    // Load user-specific settings for the newly signed-in user
                    Settings.shared.loadUserSettings()

                    // Get user info from the signed-in user and set name
                    if let user = GIDSignIn.sharedInstance.currentUser,
                       let name = user.profile?.name {
                        settings.workerName = name
                    }

                    // Complete onboarding - profile setup will show in ContentView
                    completeOnboarding()
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    // Check if user cancelled
                    if (error as NSError).code == GIDSignInError.canceled.rawValue {
                        // User cancelled, no error message needed
                    } else {
                        signInError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        // Mark that profile setup is needed
        UserDefaults.standard.set(false, forKey: "hasCompletedProfileSetup")
        withAnimation {
            isOnboardingComplete = true
        }
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bolt.fill")
                .font(.system(size: 80))
                .foregroundStyle(brandGreen)

            Text("Pal Field")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Track jobs, manage invoices,\nand connect with your team")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "doc.text.fill", title: "Job Tracking", description: "Manage all your palfield jobs")
                FeatureRow(icon: "dollarsign.circle.fill", title: "Invoicing", description: "Generate weekly invoices")
                FeatureRow(icon: "location.fill", title: "Mileage", description: "Auto-track your miles")
                FeatureRow(icon: "bubble.left.and.bubble.right.fill", title: "Team Chat", description: "Stay connected with crew")
            }
            .padding(.horizontal, 30)

            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(brandGreen)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Sign In Page

struct SignInPage: View {
    @Binding var isSigningIn: Bool
    @Binding var signInError: String?
    let onGoogleSignIn: () -> Void

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.fill")
                .font(.system(size: 60))
                .foregroundStyle(brandGreen)

            Text("Connect Your Email")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Sign in with Gmail to receive\njob notifications and sync emails")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

            // Google Sign In Button
            Button {
                onGoogleSignIn()
            } label: {
                HStack(spacing: 12) {
                    if isSigningIn {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "envelope.fill")
                            .font(.title3)
                    }
                    Text(isSigningIn ? "Signing in..." : "Sign in with Google")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSigningIn)
            .padding(.horizontal, 30)

            if let error = signInError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Profile Setup Sheet (shown after onboarding)

struct ProfileSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: Settings

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(brandGreen)

                            Text("Complete Your Profile")
                                .font(.title.bold())
                                .foregroundStyle(.white)

                            Text("This info is used for invoices\nand team identification")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Personal Info Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Personal Info")
                                .font(.headline)
                                .foregroundStyle(brandGreen)

                            ProfileTextField(title: "Full Name", text: $settings.workerName)
                            ProfileTextField(
                                title: "Company Name",
                                text: $settings.companyName,
                                placeholder: "Company Name or Full Name"
                            )
                            ProfileTextField(
                                title: "Home Address",
                                text: $settings.homeAddress,
                                placeholder: "Street, City, State ZIP",
                                subtitle: "Include city, state, and zip code for mileage calculations"
                            )
                            ProfileTextField(title: "Phone Number", text: $settings.phoneNumber, keyboardType: .phonePad)
                            ProfileTextField(title: "Pay Number", text: $settings.payNumber)
                        }
                        .padding(.horizontal)

                        // Pay Tier Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pay Tier")
                                .font(.headline)
                                .foregroundStyle(brandGreen)

                            Text("Select your current pay tier")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))

                            Picker("Pay Tier", selection: $settings.payTier) {
                                ForEach(PayTier.allCases) { tier in
                                    Text(tier.displayName).tag(tier)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 40)

                        // Save button
                        Button {
                            completeProfileSetup()
                        } label: {
                            Text("Save & Continue")
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(settings.workerName.isEmpty ? Color.gray : brandGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(settings.workerName.isEmpty)
                        .padding(.horizontal)

                        Button("Skip for Now") {
                            completeProfileSetup()
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .interactiveDismissDisabled()
        .preferredColorScheme(.dark)
    }

    private func completeProfileSetup() {
        UserDefaults.standard.set(true, forKey: "hasCompletedProfileSetup")
        dismiss()
    }
}

// MARK: - Profile Text Field

struct ProfileTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String? = nil
    var subtitle: String? = nil
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            TextField(placeholder ?? title, text: $text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
                .keyboardType(keyboardType)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
        .environmentObject(Settings())
}
