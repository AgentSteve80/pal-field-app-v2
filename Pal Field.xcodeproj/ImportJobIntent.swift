//
//  ImportJobIntent.swift
//  Pal Field
//
//  Created by Andrew Stewart on 12/13/25.
//

import AppIntents
import SwiftData

/// App Intent to import a job from email text
/// Can be triggered via Shortcuts automation
struct ImportJobIntent: AppIntent {
    static var title: LocalizedStringResource = "Import Job from Email"
    static var description = IntentDescription("Parse and import a job from email text")
    
    @Parameter(title: "Email Text", description: "The email content containing job details")
    var emailText: String
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Get the shared model container
        guard let container = try? ModelContainer(for: Job.self) else {
            return .result(value: "Error: Could not access database")
        }
        
        let context = ModelContext(container)
        
        // Get settings (you might need to adjust this based on your Settings implementation)
        let settings = Settings.shared
        
        // Parse the email
        let parser = EmailJobParser()
        guard let job = await parser.parseJobEmail(emailText, settings: settings) else {
            return .result(value: "❌ Could not parse job from email. Check format.")
        }
        
        // Save to database
        context.insert(job)
        
        do {
            try context.save()
            let total = job.total(settings: settings)
            return .result(value: "✅ Imported Job \(job.jobNumber) - Lot \(job.lotNumber) - $\(String(format: "%.2f", total))")
        } catch {
            return .result(value: "❌ Error saving job: \(error.localizedDescription)")
        }
    }
}

/// Quick action to open email import view
struct OpenEmailImportIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Email Import"
    static var description = IntentDescription("Open the email import view in Pal Field")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // This will open your app
        // You can use URL schemes or deep linking if needed
        return .result()
    }
}

// MARK: - App Shortcuts
struct PalFieldShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ImportJobIntent(),
            phrases: [
                "Import job with \(.applicationName)",
                "Add job from email in \(.applicationName)"
            ],
            shortTitle: "Import Job",
            systemImageName: "envelope.badge.fill"
        )
    }
}
