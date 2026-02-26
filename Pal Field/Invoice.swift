//
//  Invoice.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import Foundation
import SwiftData

@Model
final class Invoice {
    var id: UUID = UUID()
    var weekStart: Date = Date()
    var weekEnd: Date = Date()
    var total: Double = 0.0
    var jobCount: Int = 0
    var pdfData: Data = Data()
    var createdAt: Date = Date()

    // Owner tracking for multi-user support
    var ownerEmail: String = ""
    var ownerName: String = ""

    // Convex sync fields
    var convexId: String?
    var syncStatusRaw: Int = 1
    var updatedAt: Date = Date()

    init(weekStart: Date = Date(), weekEnd: Date = Date(), total: Double = 0.0, jobCount: Int = 0, pdfData: Data = Data()) {
        self.id = UUID()
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.total = total
        self.jobCount = jobCount
        self.pdfData = pdfData
        self.createdAt = Date()
    }

    var weekRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd)), \(Calendar.current.component(.year, from: weekStart))"
    }

    var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return "Invoice_\(formatter.string(from: weekStart))_to_\(formatter.string(from: weekEnd))-\(Calendar.current.component(.year, from: weekStart)).pdf"
    }
}
