//
//  UserRole.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import Foundation
import SwiftUI

enum UserRole: String, CaseIterable {
    case developer = "Developer"
    case admin = "Admin"
    case supervisor = "Supervisor"
    case standard = "Standard"

    /// Determine role based on email address
    static func role(for email: String) -> UserRole {
        switch email.lowercased() {
        case "astewart@pallowvoltage.com":
            return .developer
        case "jshepherd@pallowvoltage.com", "agunst@pallowvoltage.com":
            return .admin
        case "bstahl@pallowvoltage.com":
            return .supervisor
        default:
            return .standard
        }
    }

    /// Whether this role can edit builders and contacts
    var canEdit: Bool {
        self == .developer || self == .admin
    }

    /// Whether this role can view all users' data
    var canViewAllUsers: Bool {
        self != .standard
    }

    /// Display description for the role
    var description: String {
        switch self {
        case .developer:
            return "Full access with developer options"
        case .admin:
            return "Edit builders, contacts, view all data"
        case .supervisor:
            return "View all users' data (read-only)"
        case .standard:
            return "Access to your own data only"
        }
    }

    /// Color associated with each role for chat display
    var color: Color {
        switch self {
        case .developer:
            return .purple
        case .admin:
            return .blue
        case .supervisor:
            return .orange
        case .standard:
            return Color(red: 76/255, green: 140/255, blue: 43/255) // brandGreen
        }
    }
}
