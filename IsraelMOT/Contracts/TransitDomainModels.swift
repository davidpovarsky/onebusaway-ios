//
//  TransitDomainModels.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

/// Multi-language name container representing official Hebrew, English and Arabic strings.
public struct TransitMultiLanguageName: Hashable, Codable, Sendable {
    public let he: String?
    public let en: String?
    public let ar: String?

    public init(he: String?, en: String?, ar: String?) {
        self.he = he
        self.en = en
        self.ar = ar
    }

    /// Resolves preferred display name based on locale. Defaults to Hebrew if present.
    public func localizedName(forLocale locale: Locale = .current) -> String {
        let lang = locale.language.languageCode?.identifier ?? "he"
        if lang == "he", let h = he, !h.isEmpty { return h }
        if lang == "en", let e = en, !e.isEmpty { return e }
        if lang == "ar", let a = ar, !a.isEmpty { return a }
        return he ?? en ?? ar ?? ""
    }
}

/// Normalized domain representation of a transit stop in Israel.
public struct TransitStop: Identifiable, Hashable, Codable, Sendable {
    public var id: MOTStopCode { code }
    public let code: MOTStopCode
    public let internalID: MOTStopInternalID?
    public let name: TransitMultiLanguageName
    public let cityName: String?
    public let streetName: String?
    public let location: CLLocationCoordinate2D
    public let platformNumber: String?
    public let isAccessible: Bool?
    public let routes: [TransitRouteSummary]

    public init(
        code: MOTStopCode,
        internalID: MOTStopInternalID? = nil,
        name: TransitMultiLanguageName,
        cityName: String? = nil,
        streetName: String? = nil,
        location: CLLocationCoordinate2D,
        platformNumber: String? = nil,
        isAccessible: Bool? = nil,
        routes: [TransitRouteSummary] = []
    ) {
        self.code = code
        self.internalID = internalID
        self.name = name
        self.cityName = cityName
        self.streetName = streetName
        self.location = location
        self.platformNumber = platformNumber
        self.isAccessible = isAccessible
        self.routes = routes
    }
}

/// Summary of a route serving a particular stop.
public struct TransitRouteSummary: Identifiable, Hashable, Codable, Sendable {
    public var id: MOTRouteID { routeID }
    public let routeID: MOTRouteID
    public let lineName: String // e.g. "31"
    public let routeDesc: MOTRouteDesc?
    public let destinationName: String?
    public let agencyID: MOTAgencyID?
    public let agencyName: String?

    public init(
        routeID: MOTRouteID,
        lineName: String,
        routeDesc: MOTRouteDesc? = nil,
        destinationName: String? = nil,
        agencyID: MOTAgencyID? = nil,
        agencyName: String? = nil
    ) {
        self.routeID = routeID
        self.lineName = lineName
        self.routeDesc = routeDesc
        self.destinationName = destinationName
        self.agencyID = agencyID
        self.agencyName = agencyName
    }
}

/// Normalized domain representation of a transit route.
public struct TransitRoute: Identifiable, Hashable, Codable, Sendable {
    public var id: MOTRouteID { routeID }
    public let routeID: MOTRouteID
    public let lineName: String
    public let longName: String?
    public let routeDesc: MOTRouteDesc?
    public let agencyID: MOTAgencyID
    public let agencyName: String
    public let cityName: String?
    public let polyline: String?
    public let stops: [TransitStop]

    public init(
        routeID: MOTRouteID,
        lineName: String,
        longName: String?,
        routeDesc: MOTRouteDesc?,
        agencyID: MOTAgencyID,
        agencyName: String,
        cityName: String?,
        polyline: String?,
        stops: [TransitStop] = []
    ) {
        self.routeID = routeID
        self.lineName = lineName
        self.longName = longName
        self.routeDesc = routeDesc
        self.agencyID = agencyID
        self.agencyName = agencyName
        self.cityName = cityName
        self.polyline = polyline
        self.stops = stops
    }
}

/// Real-time or scheduled arrival record at a stop.
public struct TransitArrival: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        return "\(routeID.rawValue)_\(scheduledTime.timeIntervalSince1970)"
    }
    public let routeID: MOTRouteID
    public let lineName: String
    public let destination: String
    public let scheduledTime: Date
    public let estimatedTime: Date?
    public let minutesToArrival: Int?
    public let isRealTime: Bool
    public let vehicleLocation: CLLocationCoordinate2D?

    public init(
        routeID: MOTRouteID,
        lineName: String,
        destination: String,
        scheduledTime: Date,
        estimatedTime: Date? = nil,
        minutesToArrival: Int? = nil,
        isRealTime: Bool = false,
        vehicleLocation: CLLocationCoordinate2D? = nil
    ) {
        self.routeID = routeID
        self.lineName = lineName
        self.destination = destination
        self.scheduledTime = scheduledTime
        self.estimatedTime = estimatedTime
        self.minutesToArrival = minutesToArrival
        self.isRealTime = isRealTime
        self.vehicleLocation = vehicleLocation
    }
}

// Extension to allow CLLocationCoordinate2D to conform to Codable/Hashable safely
extension CLLocationCoordinate2D: Hashable, Codable, @unchecked Sendable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.000001 && abs(lhs.longitude - rhs.longitude) < 0.000001
    }

    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: lat, longitude: lon)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}
