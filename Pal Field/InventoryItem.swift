//
//  InventoryItem.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import Foundation
import SwiftData

enum InventoryStatus: String, CaseIterable, Codable {
    case goodStock = "Good Stock"
    case needRestocked = "Need re-stocked"
}

enum SupplyCompany: String, CaseIterable, Identifiable, Codable {
    case sns = "SNS"
    case guardian = "Guardian"

    var id: String { rawValue }
}

enum InventoryCategory: String, CaseIterable, Identifiable, Codable {
    case cat6 = "Cat6"
    case coax = "Coax"
    case onqPanels = "OnQ Panels"
    case hdmi15 = "HDMI 15'"
    case hdmi25 = "HDMI 25\""
    case wire18_2 = "18/2"
    case wire16_4 = "16/4"
    case wire16_2 = "16/2"

    var id: String { rawValue }

    var displayName: String { rawValue }

    // Categories that use spools (measured in feet)
    var usesFeet: Bool {
        switch self {
        case .cat6, .coax, .wire18_2, .wire16_4, .wire16_2:
            return true
        case .onqPanels, .hdmi15, .hdmi25:
            return false
        }
    }

    // Categories available for each supplier
    static func categories(for supplier: SupplyCompany) -> [InventoryCategory] {
        switch supplier {
        case .sns:
            return [.cat6, .coax, .onqPanels, .hdmi15, .hdmi25]
        case .guardian:
            return [.cat6, .coax, .onqPanels, .hdmi15, .hdmi25, .wire18_2, .wire16_4, .wire16_2]
        }
    }
}

@Model
final class InventoryItem {
    var id: UUID = UUID()
    var supplier: String = "SNS"
    var category: String = "Cat6"
    var itemNumber: Int = 1
    var quantity: Int = 0
    var lengthFeet: Int = 0
    var status: String = "Good Stock"
    var notes: String = ""
    var createdAt: Date = Date()

    // Owner tracking for multi-user support
    var ownerEmail: String = ""
    var ownerName: String = ""

    init(
        supplier: String = "SNS",
        category: String = "Cat6",
        itemNumber: Int = 1,
        quantity: Int = 0,
        lengthFeet: Int = 0,
        status: String = "Good Stock",
        notes: String = ""
    ) {
        self.id = UUID()
        self.supplier = supplier
        self.category = category
        self.itemNumber = itemNumber
        self.quantity = quantity
        self.lengthFeet = lengthFeet
        self.status = status
        self.notes = notes
        self.createdAt = Date()
    }

    var displayName: String {
        if let cat = InventoryCategory(rawValue: category), cat.usesFeet {
            return "Spool \(itemNumber)"
        }
        return "\(category) #\(itemNumber)"
    }

    var usesFeet: Bool {
        InventoryCategory(rawValue: category)?.usesFeet ?? false
    }

    /// Check if item needs restocking based on thresholds
    var needsRestock: Bool {
        guard let cat = InventoryCategory(rawValue: category) else { return false }

        switch cat {
        case .cat6, .coax, .wire18_2, .wire16_4, .wire16_2:
            // Wire below 100 ft needs restock
            return lengthFeet < 100
        case .onqPanels:
            // OnQ Panels below 5 needs restock
            return quantity < 5
        case .hdmi15, .hdmi25:
            // HDMI below 6 needs restock
            return quantity < 6
        }
    }

    /// Auto-update status based on thresholds
    func updateStatusBasedOnValue() {
        if needsRestock {
            status = InventoryStatus.needRestocked.rawValue
        } else {
            status = InventoryStatus.goodStock.rawValue
        }
    }
}
