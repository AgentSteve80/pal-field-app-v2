//
//  SyncModels.swift
//  Pal Field
//
//  Sync status enum and protocol for SwiftData models that sync to Convex.
//  These fields are added to existing models via extensions.
//

import Foundation

// MARK: - Sync Status

enum SyncStatus: Int, Codable {
    case synced = 0      // Up to date with Convex
    case pending = 1     // Local changes need to be pushed
    case conflict = 2    // Conflict detected (resolved by last-write-wins)

    var displayName: String {
        switch self {
        case .synced: return "Synced"
        case .pending: return "Pending"
        case .conflict: return "Conflict"
        }
    }

    var icon: String {
        switch self {
        case .synced: return "checkmark.icloud"
        case .pending: return "arrow.triangle.2.circlepath.icloud"
        case .conflict: return "exclamationmark.icloud"
        }
    }
}

// MARK: - Syncable Protocol

/// Protocol for SwiftData models that can sync to Convex
protocol ConvexSyncable {
    /// Convex document ID (nil if never synced)
    var convexId: String? { get set }

    /// Current sync status
    var syncStatusRaw: Int { get set }

    /// Last modification timestamp (for last-write-wins conflict resolution)
    var updatedAt: Date { get set }
}

extension ConvexSyncable {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    /// Mark this record as needing sync
    mutating func markPending() {
        syncStatusRaw = SyncStatus.pending.rawValue
        updatedAt = Date()
    }

    /// Mark this record as synced with Convex
    mutating func markSynced(convexId: String) {
        self.convexId = convexId
        syncStatusRaw = SyncStatus.synced.rawValue
    }
}

// MARK: - Convex API Types

/// Wrapper for Convex HTTP API request
struct ConvexRequest: Encodable {
    let path: String
    let args: [String: AnyCodable]
    let format: String = "json"
}

/// Wrapper for Convex HTTP API response
struct ConvexResponse: Decodable {
    let status: String?
    let value: AnyCodable?
    let errorMessage: String?
}

/// Type-erased Codable wrapper for JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if value is NSNull {
            try container.encodeNil()
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
