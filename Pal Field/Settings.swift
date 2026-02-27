import Foundation
import Combine
import SwiftUI

enum PayTier: Int, CaseIterable, Identifiable {
    case tier1 = 1
    case tier2 = 2
    case tier3 = 3

    var id: Int { rawValue }

    var displayName: String {
        "Tier \(rawValue)"
    }
}

enum TaxFilingStatus: String, CaseIterable, Identifiable {
    case single = "Single"
    case marriedFilingJointly = "Married Filing Jointly"
    case marriedFilingSeparately = "Married Filing Separately"
    case headOfHousehold = "Head of Household"

    var id: String { rawValue }
}

enum USState: String, CaseIterable, Identifiable {
    case alabama = "Alabama"
    case alaska = "Alaska"
    case arizona = "Arizona"
    case arkansas = "Arkansas"
    case california = "California"
    case colorado = "Colorado"
    case connecticut = "Connecticut"
    case delaware = "Delaware"
    case florida = "Florida"
    case georgia = "Georgia"
    case hawaii = "Hawaii"
    case idaho = "Idaho"
    case illinois = "Illinois"
    case indiana = "Indiana"
    case iowa = "Iowa"
    case kansas = "Kansas"
    case kentucky = "Kentucky"
    case louisiana = "Louisiana"
    case maine = "Maine"
    case maryland = "Maryland"
    case massachusetts = "Massachusetts"
    case michigan = "Michigan"
    case minnesota = "Minnesota"
    case mississippi = "Mississippi"
    case missouri = "Missouri"
    case montana = "Montana"
    case nebraska = "Nebraska"
    case nevada = "Nevada"
    case newHampshire = "New Hampshire"
    case newJersey = "New Jersey"
    case newMexico = "New Mexico"
    case newYork = "New York"
    case northCarolina = "North Carolina"
    case northDakota = "North Dakota"
    case ohio = "Ohio"
    case oklahoma = "Oklahoma"
    case oregon = "Oregon"
    case pennsylvania = "Pennsylvania"
    case rhodeIsland = "Rhode Island"
    case southCarolina = "South Carolina"
    case southDakota = "South Dakota"
    case tennessee = "Tennessee"
    case texas = "Texas"
    case utah = "Utah"
    case vermont = "Vermont"
    case virginia = "Virginia"
    case washington = "Washington"
    case westVirginia = "West Virginia"
    case wisconsin = "Wisconsin"
    case wyoming = "Wyoming"

    var id: String { rawValue }

    var taxRate: Double {
        switch self {
        case .alaska, .florida, .nevada, .southDakota, .tennessee, .texas, .washington, .wyoming:
            return 0.0 // No state income tax
        case .newHampshire:
            return 0.05 // Only on interest and dividends
        case .indiana:
            return 0.0315
        case .pennsylvania:
            return 0.0307
        case .michigan:
            return 0.0425
        case .arizona:
            return 0.025
        case .colorado:
            return 0.044
        case .illinois:
            return 0.0495
        case .northCarolina:
            return 0.0475
        case .utah:
            return 0.0485
        case .california:
            return 0.093 // Top marginal rate (simplified)
        case .newYork:
            return 0.0685
        default:
            return 0.05 // Default estimate for other states
        }
    }
}

class Settings: ObservableObject {

    static let shared = Settings()

    /// Shared UserDefaults for widgets and extensions
    private let sharedDefaults = AppGroupConstants.sharedDefaults

    #if !WIDGET_EXTENSION
    /// Current user's role based on their email
    var userRole: UserRole {
        UserRole.role(for: GmailAuthManager.shared.userEmail)
    }

    /// Current user's email for user-specific settings
    var currentUserEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }
    #else
    /// For widget extension, get email from shared defaults
    var currentUserEmail: String {
        sharedDefaults?.string(forKey: "currentUserEmail") ?? ""
    }
    #endif

    /// Admin mode toggle - only affects UI, not actual permissions
    @Published var adminModeEnabled: Bool {
        didSet { syncToShared(adminModeEnabled, forKey: "adminModeEnabled") }
    }

    /// Helper to create user-specific key
    private func userKey(_ baseKey: String) -> String {
        let email = currentUserEmail
        return email.isEmpty ? baseKey : "\(email)_\(baseKey)"
    }

    /// Helper to write to both standard and shared UserDefaults
    private func syncToShared<T>(_ value: T, forKey key: String) {
        let userSpecificKey = userKey(key)
        UserDefaults.standard.set(value, forKey: userSpecificKey)
        sharedDefaults?.set(value, forKey: userSpecificKey)
    }

    /// Save directly without email prefix — for personal info that shouldn't be per-account
    private func syncDirect<T>(_ value: T, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        sharedDefaults?.set(value, forKey: key)
    }

    @Published var companyName: String {
        didSet { syncDirect(companyName, forKey: "companyName") }
    }

    @Published var homeAddress: String {
        didSet { syncDirect(homeAddress, forKey: "homeAddress") }
    }

    @Published var workerName: String {
        didSet { syncDirect(workerName, forKey: "workerName") }
    }

    @Published var phoneNumber: String {
        didSet { syncDirect(phoneNumber, forKey: "phoneNumber") }
    }

    @Published var payNumber: String {
        didSet { syncDirect(payNumber, forKey: "payNumber") }
    }

    @Published var darkMode: Bool {
        didSet { syncDirect(darkMode, forKey: "darkMode") }
    }

    @Published var payTier: PayTier {
        didSet { syncToShared(payTier.rawValue, forKey: "payTier") }
    }

    @Published var gmailFilterSender: String {
        didSet { syncToShared(gmailFilterSender, forKey: "gmailFilterSender") }
    }

    // Tax settings
    @Published var taxFilingStatus: TaxFilingStatus {
        didSet { syncToShared(taxFilingStatus.rawValue, forKey: "taxFilingStatus") }
    }

    @Published var taxState: USState {
        didSet { syncToShared(taxState.rawValue, forKey: "taxState") }
    }

    @Published var taxYear: Int {
        didSet { syncToShared(taxYear, forKey: "taxYear") }
    }

    @Published var estimatedOtherIncome: Double {
        didSet { syncToShared(estimatedOtherIncome, forKey: "estimatedOtherIncome") }
    }

    init() {
        // Initialize with empty defaults first (will be loaded properly in loadUserSettings)
        self.companyName = ""
        self.homeAddress = ""
        self.workerName = ""
        self.phoneNumber = ""
        self.payNumber = ""
        self.darkMode = false
        self.payTier = .tier2
        self.gmailFilterSender = ""
        self.taxFilingStatus = .single
        self.taxState = .indiana
        self.taxYear = 2025
        self.estimatedOtherIncome = 0
        self.adminModeEnabled = false

        // Load user-specific settings
        loadUserSettings()
    }

    /// Load settings for the current user (call this when user signs in)
    func loadUserSettings() {
        let email = currentUserEmail

        // Helper to get user-specific value
        func getValue<T>(_ key: String, default defaultValue: T) -> T {
            let userSpecificKey = email.isEmpty ? key : "\(email)_\(key)"
            if let value = UserDefaults.standard.object(forKey: userSpecificKey) as? T {
                return value
            }
            return defaultValue
        }

        func getStringValue(_ key: String, default defaultValue: String) -> String {
            let userSpecificKey = email.isEmpty ? key : "\(email)_\(key)"
            return UserDefaults.standard.string(forKey: userSpecificKey) ?? defaultValue
        }

        // Personal info — always use bare keys (not email-prefixed)
        self.companyName = UserDefaults.standard.string(forKey: "companyName") ?? ""
        self.homeAddress = UserDefaults.standard.string(forKey: "homeAddress") ?? ""
        self.workerName = UserDefaults.standard.string(forKey: "workerName") ?? ""
        self.phoneNumber = UserDefaults.standard.string(forKey: "phoneNumber") ?? ""
        self.payNumber = UserDefaults.standard.string(forKey: "payNumber") ?? ""
        self.darkMode = UserDefaults.standard.bool(forKey: "darkMode")

        let tierValue: Int = getValue("payTier", default: PayTier.tier2.rawValue)
        self.payTier = PayTier(rawValue: tierValue) ?? .tier2

        self.gmailFilterSender = getStringValue("gmailFilterSender", default: "")

        // Tax settings
        let filingStatusRaw = getStringValue("taxFilingStatus", default: TaxFilingStatus.single.rawValue)
        self.taxFilingStatus = TaxFilingStatus(rawValue: filingStatusRaw) ?? .single

        let stateRaw = getStringValue("taxState", default: USState.indiana.rawValue)
        self.taxState = USState(rawValue: stateRaw) ?? .indiana

        let savedTaxYear: Int = getValue("taxYear", default: 0)
        self.taxYear = savedTaxYear == 0 ? 2025 : savedTaxYear

        self.estimatedOtherIncome = getValue("estimatedOtherIncome", default: 0.0)

        // Admin mode (default off)
        self.adminModeEnabled = getValue("adminModeEnabled", default: false)

        // Save current user email to shared defaults for widgets
        sharedDefaults?.set(email, forKey: "currentUserEmail")

        // Migrate existing values to shared UserDefaults (for widgets/extensions)
        migrateToSharedDefaults()
    }

    /// One-time migration of existing settings to shared UserDefaults
    private func migrateToSharedDefaults() {
        guard let shared = sharedDefaults else { return }
        let email = currentUserEmail
        let migrationKey = email.isEmpty ? "settingsMigrated" : "\(email)_settingsMigrated"

        // Only migrate if not already done for this user
        if shared.object(forKey: migrationKey) == nil {
            syncToShared(companyName, forKey: "companyName")
            syncToShared(homeAddress, forKey: "homeAddress")
            syncToShared(workerName, forKey: "workerName")
            syncToShared(phoneNumber, forKey: "phoneNumber")
            syncToShared(payNumber, forKey: "payNumber")
            syncToShared(darkMode, forKey: "darkMode")
            syncToShared(payTier.rawValue, forKey: "payTier")
            syncToShared(gmailFilterSender, forKey: "gmailFilterSender")
            syncToShared(taxFilingStatus.rawValue, forKey: "taxFilingStatus")
            syncToShared(taxState.rawValue, forKey: "taxState")
            syncToShared(taxYear, forKey: "taxYear")
            syncToShared(estimatedOtherIncome, forKey: "estimatedOtherIncome")
            syncToShared(adminModeEnabled, forKey: "adminModeEnabled")
            shared.set(true, forKey: migrationKey)
        }
    }

    // Pricing based on pay tier
    func priceForWireRun() -> Double {
        switch payTier {
        case .tier1: return 9.0
        case .tier2: return 9.0
        case .tier3: return 10.0
        }
    }

    func priceForEnclosure() -> Double {
        switch payTier {
        case .tier1: return 9.0
        case .tier2: return 12.0
        case .tier3: return 13.0
        }
    }

    func priceForFlatPanelStud() -> Double {
        switch payTier {
        case .tier1: return 20.0
        case .tier2: return 20.0
        case .tier3: return 25.0
        }
    }

    func priceForFlatPanelWall() -> Double {
        switch payTier {
        case .tier1: return 20.0  // Same as FPP in Tier 1
        case .tier2: return 25.0
        case .tier3: return 30.0
        }
    }

    func priceForFlatPanelRemote() -> Double {
        switch payTier {
        case .tier1: return 20.0  // Same as FPP in Tier 1
        case .tier2: return 30.0
        case .tier3: return 35.0
        }
    }

    func priceForFlexTube() -> Double {
        switch payTier {
        case .tier1: return 30.0
        case .tier2: return 35.0
        case .tier3: return 40.0
        }
    }

    func priceForMediaBox() -> Double {
        return 12.0  // Same for all tiers
    }

    func priceForDryRun() -> Double {
        return 25.0  // Same for all tiers
    }

    func priceForServiceRun() -> Double {
        return 20.0  // 30 min service run, same for all tiers
    }

    func tripChargePerMile() -> Double {
        return 0.75  // Same for all tiers
    }

    func freeMiles() -> Double {
        return 20.0  // First 20 miles are free
    }
}
