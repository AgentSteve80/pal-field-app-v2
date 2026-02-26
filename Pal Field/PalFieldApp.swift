//
//  PalFieldApp.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 11/13/25.
//

import SwiftUI
import SwiftData
import GoogleSignIn
import UserNotifications
import ClerkSDK

@main
struct PalFieldApp: App {
    var settings = Settings()
    let container: ModelContainer
    let backgroundChecker = BackgroundEmailChecker.shared

    init() {
        // Request notification permission (background task registered via .backgroundTask modifier)
        backgroundChecker.requestNotificationPermission()

        // Use shared container URL for widgets access
        let containerURL = AppGroupConstants.sharedContainerURL

        do {
            // Schema for CloudKit-synced models
            let syncedSchema = Schema([Job.self, Invoice.self, Expense.self, MileageTrip.self, InventoryItem.self, EditableBuilder.self, TeamChatMessage.self, EditableContact.self, ChatUser.self])

            // Schema for local-only models (Gmail cache shouldn't sync)
            let localSchema = Schema([CachedEmail.self])

            // CloudKit configuration for synced data
            let cloudConfig = ModelConfiguration(
                "CloudSync",
                schema: syncedSchema,
                cloudKitDatabase: .private("iCloud.com.pallowvoltage.fieldapp")
            )
            print("☁️ CloudKit sync enabled with container: iCloud.com.pallowvoltage.fieldapp")

            // Local configuration for cached emails (no sync)
            let localStoreURL = containerURL?.appendingPathComponent("LocalCache.store")
            let localConfig: ModelConfiguration
            if let localStoreURL = localStoreURL {
                localConfig = ModelConfiguration(
                    "LocalCache",
                    schema: localSchema,
                    url: localStoreURL,
                    cloudKitDatabase: .none
                )
            } else {
                localConfig = ModelConfiguration(
                    "LocalCache",
                    schema: localSchema,
                    cloudKitDatabase: .none
                )
            }
            print("📁 Local cache configured for emails")

            // Create container with both configurations
            let fullSchema = Schema([Job.self, Invoice.self, Expense.self, CachedEmail.self, MileageTrip.self, InventoryItem.self, EditableBuilder.self, TeamChatMessage.self, EditableContact.self, ChatUser.self])
            container = try ModelContainer(for: fullSchema, configurations: [cloudConfig, localConfig])
            print("✅ ModelContainer created with CloudKit sync + local cache")

        } catch {
            print("⚠️ Failed to create ModelContainer with CloudKit: \(error)")
            print("⚠️ Falling back to local-only storage...")

            // Fallback to local-only storage
            do {
                let schema = Schema([Job.self, Invoice.self, Expense.self, CachedEmail.self, MileageTrip.self, InventoryItem.self, EditableBuilder.self, TeamChatMessage.self, EditableContact.self, ChatUser.self])
                let storeURL = containerURL?.appendingPathComponent("PalField.store")

                let configuration: ModelConfiguration
                if let storeURL = storeURL {
                    configuration = ModelConfiguration(
                        schema: schema,
                        url: storeURL,
                        allowsSave: true,
                        cloudKitDatabase: .none
                    )
                } else {
                    configuration = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false,
                        allowsSave: true,
                        cloudKitDatabase: .none
                    )
                }
                container = try ModelContainer(for: schema, configurations: [configuration])
                print("✅ Fallback: Using local-only storage")
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ClerkProvider(publishableKey: "pk_test_c3VubnktbWFtbWFsLTEwLmNsZXJrLmFjY291bnRzLmRldiQ") {
                AppLaunchView()
                    .preferredColorScheme(settings.darkMode ? .dark : .light)
                    .environmentObject(settings)
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
                    .onAppear {
                        // Schedule background email checking when app launches
                        backgroundChecker.scheduleBackgroundRefresh()
                        // Request notification permissions on first launch
                        NotificationManager.shared.requestPermission()

                        // Configure Clerk auth & Convex sync
                        ClerkAuthManager.shared.configure()
                        ConvexSyncManager.shared.configure(container: container)

                        // Start network monitoring
                        _ = NetworkMonitor.shared
                    }
            }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh("com.palfield.emailcheck")) {
            await BackgroundEmailChecker.shared.performBackgroundCheck()
        }
    }
}

// MARK: - App Launch View with Splash Screen

struct AppLaunchView: View {
    @State private var splashFinished = false
    @AppStorage("hasCompletedOnboarding") private var isOnboardingComplete = false
    @ObservedObject private var authManager = ClerkAuthManager.shared
    @State private var showingSignIn = false
    @AppStorage("hasSkippedSignIn") private var hasSkippedSignIn = false

    var body: some View {
        ZStack {
            if isOnboardingComplete {
                // Main content (always rendered underneath — never gated behind auth)
                ContentView()
                    .opacity(splashFinished ? 1 : 0)

                // Splash screen overlay
                if !splashFinished {
                    SplashScreenView(isFinished: $splashFinished)
                        .transition(.opacity)
                }
            } else {
                // Show onboarding for new users
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
            }
        }
        .sheet(isPresented: $showingSignIn) {
            SignInView()
        }
        .onAppear {
            // After onboarding, prompt sign-in once if not authenticated and haven't skipped
            if isOnboardingComplete && !authManager.isAuthenticated && !hasSkippedSignIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingSignIn = true
                    hasSkippedSignIn = true  // Only show auto-prompt once
                }
            }
        }
    }
}
