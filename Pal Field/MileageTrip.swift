//
//  MileageTrip.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import Foundation
import SwiftData

@Model
final class MileageTrip {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var miles: Double = 0.0
    var purpose: String = "Work"
    var notes: String = ""
    var ownerEmail: String = ""
    var ownerName: String = ""

    init(startDate: Date = Date(), endDate: Date? = nil, miles: Double = 0, purpose: String = "Work", notes: String = "", ownerEmail: String = "", ownerName: String = "") {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.miles = miles
        self.purpose = purpose
        self.notes = notes
        self.ownerEmail = ownerEmail
        self.ownerName = ownerName
    }

    var isActive: Bool {
        endDate == nil
    }

    var duration: TimeInterval? {
        guard let end = endDate else { return nil }
        return end.timeIntervalSince(startDate)
    }
}
