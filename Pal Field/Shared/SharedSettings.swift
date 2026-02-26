//
//  SharedSettings.swift
//  Pal Field
//
//  Read-only settings for widgets and extensions using shared UserDefaults
//

import Foundation

/// Read-only settings accessor for widgets and extensions
/// Reads from the shared App Group UserDefaults
struct SharedSettings {

    private let defaults: UserDefaults?

    init() {
        self.defaults = AppGroupConstants.sharedDefaults
    }

    // MARK: - Basic Info

    var companyName: String {
        defaults?.string(forKey: "companyName") ?? ""
    }

    var workerName: String {
        defaults?.string(forKey: "workerName") ?? "Andrew Stewart"
    }

    var homeAddress: String {
        defaults?.string(forKey: "homeAddress") ?? ""
    }

    // MARK: - Pay Tier

    var payTierValue: Int {
        defaults?.integer(forKey: "payTier") ?? 2
    }

    // MARK: - Pricing Methods (mirrors Settings.swift)

    func priceForWireRun() -> Double {
        switch payTierValue {
        case 1: return 9.0
        case 3: return 10.0
        default: return 9.0
        }
    }

    func priceForEnclosure() -> Double {
        switch payTierValue {
        case 1: return 9.0
        case 3: return 13.0
        default: return 12.0
        }
    }

    func priceForFlatPanelStud() -> Double {
        switch payTierValue {
        case 1: return 20.0
        case 3: return 25.0
        default: return 20.0
        }
    }

    func priceForFlatPanelWall() -> Double {
        switch payTierValue {
        case 1: return 20.0
        case 3: return 30.0
        default: return 25.0
        }
    }

    func priceForFlatPanelRemote() -> Double {
        switch payTierValue {
        case 1: return 20.0
        case 3: return 35.0
        default: return 30.0
        }
    }

    func priceForFlexTube() -> Double {
        switch payTierValue {
        case 1: return 30.0
        case 3: return 40.0
        default: return 35.0
        }
    }

    func priceForMediaBox() -> Double {
        return 12.0
    }

    func priceForDryRun() -> Double {
        return 25.0
    }

    func priceForServiceRun() -> Double {
        return 20.0
    }

    func tripChargePerMile() -> Double {
        return 0.75
    }

    func freeMiles() -> Double {
        return 20.0
    }

    // MARK: - Job Total Calculation

    /// Calculates the total for a job using shared settings pricing
    func calculateJobTotal(
        wireRuns: Int,
        enclosure: Int,
        flatPanelStud: Int,
        flatPanelWall: Int,
        flatPanelRemote: Int,
        flexTube: Int,
        mediaBox: Int,
        dryRun: Int,
        serviceRun: Int
    ) -> Double {
        return Double(wireRuns) * priceForWireRun() +
               Double(enclosure) * priceForEnclosure() +
               Double(flatPanelStud) * priceForFlatPanelStud() +
               Double(flatPanelWall) * priceForFlatPanelWall() +
               Double(flatPanelRemote) * priceForFlatPanelRemote() +
               Double(flexTube) * priceForFlexTube() +
               Double(mediaBox) * priceForMediaBox() +
               Double(dryRun) * priceForDryRun() +
               Double(serviceRun) * priceForServiceRun()
    }
}
