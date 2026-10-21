//
//  Identifiers.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Represents the public 4-to-5 digit bus stop code displayed on physical signs in Israel (e.g., 5997).
nonisolated public struct MOTStopCode: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(_ value: Int) {
        self.rawValue = value
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
nonisolated public struct MOTStopInternalID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(_ value: Int) {
        self.rawValue = value
    }

    public init?(_ string: String) {
        guard let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        self.rawValue = value
    }

    public var description: String {
        return String(rawValue)
    }
}

/// Represents a route identifier in the MOT scheduler system (e.g., 33285).
nonisolated public struct MOTRouteID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(_ value: Int) {
        self.rawValue = value
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
nonisolated public struct MOTRouteDesc: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ value: String) {
        self.rawValue = value
    }

    public var description: String {
        return rawValue
    }
}

/// Represents a scoped transit agency ID in Israel (e.g. 16 for Superbus, 3 for Egged).
nonisolated public struct MOTAgencyID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(_ value: Int) {
        self.rawValue = value
    }

    public var description: String {
        return String(rawValue)
    }
}

/// Identifiers namespace and utilities for scoping IDs in OneBusAway
nonisolated public enum MOTIdentityFormatter {
    public static func scopedStopID(code: MOTStopCode, internalID: MOTStopInternalID? = nil) -> String {
        if let internalID = internalID {
            return "mot:stop:\(code.rawValue)_\(internalID.rawValue)"
        }
        return "mot:stop:\(code.rawValue)"
    }

    public static func scopedRouteID(id: MOTRouteID) -> String {
        return "mot:route:\(id.rawValue)"
    }

    public static func scopedAgencyID(id: MOTAgencyID) -> String {
        return "mot:agency:\(id.rawValue)"
    }

    public static func scopedShapeID(routeID: MOTRouteID) -> String {
        return "mot:shape:\(routeID.rawValue)"
    }

    public static func scopedTripID(routeID: MOTRouteID, suffix: String) -> String {
        return "mot:trip:\(routeID.rawValue)_\(suffix)"
    }

    public static func parseStopCode(fromScopedID scopedID: String) -> MOTStopCode? {
        let stripped: String
        if scopedID.hasPrefix("mot:stop:") {
            stripped = String(scopedID.dropFirst("mot:stop:".count))
        } else {
            stripped = scopedID
        }
        let codePart = stripped.split(separator: "_").first.map(String.init) ?? stripped
        return MOTStopCode(codePart)
    }

    public static func parseStopInternalID(fromScopedID scopedID: String) -> MOTStopInternalID? {
        let stripped: String
        if scopedID.hasPrefix("mot:stop:") {
            stripped = String(scopedID.dropFirst("mot:stop:".count))
        } else {
            stripped = scopedID
        }
        let parts = stripped.split(separator: "_")
        guard parts.count >= 2, let internalPart = parts.dropFirst().first else {
            return nil
        }
        return MOTStopInternalID(String(internalPart))
    }

    public static func parseRouteID(fromScopedID scopedID: String) -> MOTRouteID? {
        if scopedID.hasPrefix("mot:route:") {
            let num = scopedID.dropFirst("mot:route:".count)
            return MOTRouteID(String(num))
        }
        return MOTRouteID(scopedID)
    }

    public static func parseRouteIDFromShapeID(_ shapeID: String) -> MOTRouteID? {
        let stripped: String
        if shapeID.hasPrefix("mot:shape:") {
            stripped = String(shapeID.dropFirst("mot:shape:".count))
        } else if shapeID.hasPrefix("mot:route:") {
            stripped = String(shapeID.dropFirst("mot:route:".count))
        } else {
            stripped = shapeID
        }
        return MOTRouteID(stripped)
    }

    public static func parseRouteIDFromTripID(_ tripID: String) -> MOTRouteID? {
        let stripped: String
        if tripID.hasPrefix("mot:trip:") {
            stripped = String(tripID.dropFirst("mot:trip:".count))
        } else {
            stripped = tripID
        }
        let parts = stripped.split(separator: "_")
        guard let first = parts.first else { return nil }
        return MOTRouteID(String(first))
    }
}
