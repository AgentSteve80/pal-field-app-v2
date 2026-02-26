//
//  Job.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 11/13/25.
//

import Foundation
import SwiftData

@Model
final class Job {
    var id: UUID = UUID()  // Removed .unique for CloudKit compatibility
    var jobNumber: String = ""
    var jobDate: Date = Date()
    var lotNumber: String = ""
    var address: String = ""
    var subdivision: String = ""
    var prospect: String = ""
    var wireRuns: Int = 0
    var enclosure: Int = 0
    var flatPanelStud: Int = 0
    var flatPanelWall: Int = 0
    var flatPanelRemote: Int = 0
    var flexTube: Int = 0
    var mediaBox: Int = 0
    var dryRun: Int = 0
    var serviceRun: Int = 0
    var miles: Double = 0.0
    var payTierValue: Int = 2  // Store tier at time of job creation

    // Builder info (parsed from email)
    var builderCompany: String = ""  // Epcon, Beazer, Drees, Pulte, MI

    // Owner tracking for multi-user support
    var ownerEmail: String = ""
    var ownerName: String = ""

    // Closeout fields
    var isCloseoutComplete: Bool = false
    var closeoutDate: Date?
    var completionPercentage: Int = 100
    var doorbellType: String = "18/2"  // "18/2" or "cat5e"
    var hasWhip: Bool = true
    var tradesOnsite: String = ""      // "framers, electricians"
    var wapUpstairs: String = ""       // "outside mbr"
    var wapDownstairs: String = ""     // "hallway/kitchen"
    var superNotes: String = ""        // "Super approved onQ location"
    var partsUsedJSON: String = ""     // JSON: [{"name":"Enp3050","qty":"1"},...]
    var ftdmCount: Int = 0             // Flextube to Dmark count

    func itemsSubtotal(settings: Settings) -> Double {
        Double(wireRuns) * settings.priceForWireRun() +
        Double(enclosure) * settings.priceForEnclosure() +
        Double(flatPanelStud) * settings.priceForFlatPanelStud() +
        Double(flatPanelWall) * settings.priceForFlatPanelWall() +
        Double(flatPanelRemote) * settings.priceForFlatPanelRemote() +
        Double(flexTube) * settings.priceForFlexTube() +
        Double(mediaBox) * settings.priceForMediaBox() +
        Double(dryRun) * settings.priceForDryRun() +
        Double(serviceRun) * settings.priceForServiceRun()
    }

    func milesCharge(settings: Settings) -> Double {
        let chargeableMiles = max(0, miles - settings.freeMiles())
        return chargeableMiles * settings.tripChargePerMile()
    }

    func total(settings: Settings) -> Double {
        itemsSubtotal(settings: settings)
    }

    init(jobNumber: String = "", jobDate: Date = .now, lotNumber: String = "", address: String = "", subdivision: String = "", prospect: String = "", wireRuns: Int = 0, enclosure: Int = 0, flatPanelStud: Int = 0, flatPanelWall: Int = 0, flatPanelRemote: Int = 0, flexTube: Int = 0, mediaBox: Int = 0, dryRun: Int = 0, serviceRun: Int = 0, miles: Double = 0.0, payTierValue: Int = 2) {
        self.jobNumber = jobNumber
        self.jobDate = jobDate
        self.lotNumber = lotNumber
        self.address = address
        self.subdivision = subdivision
        self.prospect = prospect
        self.wireRuns = wireRuns
        self.enclosure = enclosure
        self.flatPanelStud = flatPanelStud
        self.flatPanelWall = flatPanelWall
        self.flatPanelRemote = flatPanelRemote
        self.flexTube = flexTube
        self.mediaBox = mediaBox
        self.dryRun = dryRun
        self.serviceRun = serviceRun
        self.miles = miles
        self.payTierValue = payTierValue
    }
    
    // MARK: - Closeout Helpers

    /// Decode parts from JSON
    var closeoutParts: [CloseoutPart] {
        get {
            guard !partsUsedJSON.isEmpty,
                  let data = partsUsedJSON.data(using: .utf8),
                  let parts = try? JSONDecoder().decode([CloseoutPart].self, from: data) else {
                return []
            }
            return parts
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                partsUsedJSON = json
            }
        }
    }

    /// Formatted billing summary for closeout email
    var billingSummary: String {
        var lines: [String] = []
        if enclosure > 0 { lines.append("Enclosure-\(enclosure)") }
        if ftdmCount > 0 { lines.append("Ftdm-\(ftdmCount)") }
        if wireRuns > 0 { lines.append("Wires-\(wireRuns)") }
        if flatPanelStud > 0 { lines.append("Ssfpp-\(flatPanelStud)") }
        if flatPanelWall > 0 { lines.append("Swfpp-\(flatPanelWall)") }
        if flatPanelRemote > 0 { lines.append("Rfpp-\(flatPanelRemote)") }
        if flexTube > 0 { lines.append("Flextube-\(flexTube)") }
        if mediaBox > 0 { lines.append("Mediabox-\(mediaBox)") }
        return lines.joined(separator: "\n")
    }

    /// Formatted parts list for closeout email
    var partsListFormatted: String {
        closeoutParts.map { "\($0.quantity) \($0.name)" }.joined(separator: "\n")
    }

    // MARK: - Job Number Helpers

    /// Extract the numeric portion of a job number (e.g., "JB123" -> 123)
    var jobNumberValue: Int? {
        let digits = jobNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits)
    }
    
    /// Generate the next sequential job number based on existing jobs
    /// Jobs are numbered weekly: JB1, JB2, JB3... resetting every Monday
    static func generateNextJobNumber(existingJobs: [Job]) -> String {
        let calendar = Calendar.current

        // Get the start of the current week (Monday)
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return "JB1"
        }

        // Adjust to Monday if needed (some locales start week on Sunday)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
        components.weekday = 2 // Monday
        guard let mondayStart = calendar.date(from: components) else {
            return "JB1"
        }

        // Get the end of the current week (Sunday)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: mondayStart) else {
            return "JB1"
        }

        // Filter jobs to only those from the current week
        let jobsThisWeek = existingJobs.filter { job in
            job.jobDate >= mondayStart && job.jobDate < weekEnd
        }

        // Find the highest job number from this week
        let highestNumber = jobsThisWeek.compactMap { $0.jobNumberValue }.max() ?? 0

        return "JB\(highestNumber + 1)"
    }
}

// MARK: - Closeout Part Model

struct CloseoutPart: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String = ""       // "Enp3050", "hdmi 15'"
    var quantity: String = "1"  // "1", "2"

    enum CodingKeys: String, CodingKey {
        case id, name, quantity
    }
}
