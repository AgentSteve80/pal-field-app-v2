//
//  SharedModelContainer.swift
//  Pal Field
//
//  Creates a shared ModelContainer for widgets and App Intents to access data
//

import Foundation
import SwiftData

/// Creates a ModelContainer configured to use the shared App Group location
/// This allows widgets and extensions to read the same SwiftData store as the main app
struct SharedModelContainer {

    /// Creates and returns a ModelContainer at the shared App Group location
    /// - Returns: A configured ModelContainer, or nil if creation fails
    static func create() -> ModelContainer? {
        guard let containerURL = AppGroupConstants.sharedContainerURL else {
            print("❌ Widget: Failed to get shared container URL")
            return nil
        }

        do {
            // Widget schema - excludes CachedEmail (not needed for widget data)
            let schema = Schema([Job.self, Invoice.self, Expense.self, MileageTrip.self, InventoryItem.self])
            let storeURL = containerURL.appendingPathComponent("PalField.store")
            print("📱 Widget: Loading data from \(storeURL.path)")

            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none  // Local only - no CloudKit sync
            )

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("❌ Widget: Failed to create shared ModelContainer: \(error)")
            return nil
        }
    }

    /// Creates a read-only ModelContainer for widgets (no writes)
    static func createReadOnly() -> ModelContainer? {
        guard let containerURL = AppGroupConstants.sharedContainerURL else {
            print("❌ Widget: Failed to get shared container URL")
            return nil
        }

        do {
            // Widget schema - excludes CachedEmail (not needed for widget data)
            let schema = Schema([Job.self, Invoice.self, Expense.self, MileageTrip.self, InventoryItem.self])
            let storeURL = containerURL.appendingPathComponent("PalField.store")
            print("📱 Widget: Loading read-only data from \(storeURL.path)")

            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: false,
                cloudKitDatabase: .none  // Local only - no CloudKit sync
            )

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("❌ Widget: Failed to create read-only ModelContainer: \(error)")
            return nil
        }
    }
}
