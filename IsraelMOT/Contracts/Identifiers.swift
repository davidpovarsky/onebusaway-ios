//
//  Identifiers.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Represents the public 4-to-5 digit bus stop code displayed on physical signs in Israel (e.g., 5997).
public struct MOTStopCode: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init?(_ string: String) {
        guard let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        self.rawValue = value
    }

    public var description: String {
        return String(rawValue)
    }
}

/// Represents the internal database identifier of a stop in the MOT system (e.g., 11622).
public struct MOTStopInternalID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public var description: String {
        return String(rawValue)
    }
}

/// Represents a route identifier in the MOT scheduler system (e.g., 33285).
public struct MOTRouteID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init?(_ string: String) {
        guard let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        self.rawValue = value
    }

    public var description: String {
        return String(rawValue)
    }
}

/// Represents the route description key (e.g., "15031-1-0"), used for live real-time queries.
public struct MOTRouteDesc: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String {
        return rawValue
    }
}

/// Represents a scoped transit agency ID in Israel (e.g. 16 for Superbus, 3 for Egged).
public struct MOTAgencyID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public var description: String {
        return String(rawValue)
    }
}

/// Identifiers namespace and utilities for scoping IDs in OneBusAway
public enum MOTIdentityFormatter {
    public static func scopedStopID(code: MOTStopCode) -> String {
        return "mot:stop:\(code.rawValue)"
    }

    public static func scopedRouteID(id: MOTRouteID) -> String {
        return "mot:route:\(id.rawValue)"
    }

    public static func scopedAgencyID(id: MOTAgencyID) -> String {
        return "mot:agency:\(id.rawValue)"
    }

    public static func parseStopCode(fromScopedID scopedID: String) -> MOTStopCode? {
        if scopedID.hasPrefix("mot:stop:") {
            let num = scopedID.dropFirst("mot:stop:".count)
            return MOTStopCode(String(num))
        }
        return MOTStopCode(scopedID)
    }

    public static func parseRouteID(fromScopedID scopedID: String) -> MOTRouteID? {
        if scopedID.hasPrefix("mot:route:") {
            let num = scopedID.dropFirst("mot:route:".count)
            return MOTRouteID(String(num))
        }
        return MOTRouteID(scopedID)
    }
}
