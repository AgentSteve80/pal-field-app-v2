//
//  Expense.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID = UUID()
    var date: Date = Date()
    var category: String = "Other"
    var amount: Double = 0.0
    var merchant: String = ""
    var notes: String = ""
    var receiptImageData: Data?
    var ownerEmail: String = ""
    var ownerName: String = ""

    init(
        date: Date = Date(),
        category: String = "Other",
        amount: Double = 0.0,
        merchant: String = "",
        notes: String = "",
        receiptImageData: Data? = nil,
        ownerEmail: String = "",
        ownerName: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.category = category
        self.amount = amount
        self.merchant = merchant
        self.notes = notes
        self.receiptImageData = receiptImageData
        self.ownerEmail = ownerEmail
        self.ownerName = ownerName
    }
}

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case gas = "Gas"
    case supplies = "Supplies"
    case meals = "Meals"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gas: return "fuelpump.fill"
        case .supplies: return "cart.fill"
        case .meals: return "fork.knife"
        case .other: return "dollarsign.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .gas: return "blue"
        case .supplies: return "orange"
        case .meals: return "green"
        case .other: return "purple"
        }
    }
}
