//
//  EditableContact.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import Foundation
import SwiftData

/// A manager within a contact/community
struct ContactManager: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var phone: String
    var email: String

    init(id: UUID = UUID(), name: String = "", phone: String = "", email: String = "") {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
    }
}

/// Editable contact for construction communities
@Model
final class EditableContact {
    var id: UUID = UUID()
    var community: String = ""
    var city: String = ""
    var region: String = ""  // "East Side", "Central", "West Side"
    var sortOrder: Int = 0
    var managersJSON: String = "[]"  // JSON-encoded array of ContactManager
    var createdAt: Date = Date()

    init(
        community: String = "",
        city: String = "",
        region: String = "",
        sortOrder: Int = 0,
        managers: [ContactManager] = []
    ) {
        self.id = UUID()
        self.community = community
        self.city = city
        self.region = region
        self.sortOrder = sortOrder
        self.managersJSON = Self.encodeManagers(managers)
        self.createdAt = Date()
    }

    /// Decode managers from JSON
    var managers: [ContactManager] {
        get {
            guard !managersJSON.isEmpty,
                  let data = managersJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([ContactManager].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            managersJSON = Self.encodeManagers(newValue)
        }
    }

    /// Encode managers to JSON
    private static func encodeManagers(_ managers: [ContactManager]) -> String {
        guard let data = try? JSONEncoder().encode(managers),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Default Contact Data Seeding

struct DefaultContactData {
    /// Check if default contacts need to be seeded
    static func seedContacts(context: ModelContext) {
        // Check if contacts already exist
        let descriptor = FetchDescriptor<EditableContact>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else { return }

        // Seed from existing PulteContactData
        var sortOrder = 0

        // East Side contacts
        for contact in PulteContactData.eastSide {
            let managers = contact.managers.map { manager in
                ContactManager(name: manager.name, phone: manager.phone, email: manager.email)
            }
            let editable = EditableContact(
                community: contact.community,
                city: contact.city,
                region: "East Side",
                sortOrder: sortOrder,
                managers: managers
            )
            context.insert(editable)
            sortOrder += 1
        }

        // Central contacts
        for contact in PulteContactData.central {
            let managers = contact.managers.map { manager in
                ContactManager(name: manager.name, phone: manager.phone, email: manager.email)
            }
            let editable = EditableContact(
                community: contact.community,
                city: contact.city,
                region: "Central",
                sortOrder: sortOrder,
                managers: managers
            )
            context.insert(editable)
            sortOrder += 1
        }

        // West Side contacts
        for contact in PulteContactData.westSide {
            let managers = contact.managers.map { manager in
                ContactManager(name: manager.name, phone: manager.phone, email: manager.email)
            }
            let editable = EditableContact(
                community: contact.community,
                city: contact.city,
                region: "West Side",
                sortOrder: sortOrder,
                managers: managers
            )
            context.insert(editable)
            sortOrder += 1
        }

        try? context.save()
        print("✅ Seeded \(sortOrder) default contacts")
    }
}
