//
//  MOTEndpoints.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

/// URL endpoints and builder for the Ministry of Transport route and scheduler APIs.
public struct MOTEndpoints: Sendable {
    public static let defaultLocaleSegment = "he"

    public let plannerBaseURL: URL
    public let schedulerBaseURL: URL
    public let localeSegment: String

    public init(
        plannerBase: URL = URL(string: "https://api.bus.gov.il/prod/route-planner-prod/api/")!,
        schedulerBase: URL = URL(string: "https://api.bus.gov.il/prod/mot-scheduler-prod/api/")!,
        locale: String = defaultLocaleSegment
    ) {
        self.plannerBaseURL = plannerBase.appendingPathComponent(locale)
        self.schedulerBaseURL = schedulerBase.appendingPathComponent(locale)
        self.localeSegment = locale
    }

    // MARK: - AutoComplete / Search Endpoints

    public func searchLocationsURL(query: String) -> URL {
        var components = URLComponents(url: plannerBaseURL.appendingPathComponent("AutoComplete/SearchLocations"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "searchTerm", value: query)]
        return components.url!
    }

    public func searchStationsURL(query: String) -> URL {
        var components = URLComponents(url: plannerBaseURL.appendingPathComponent("AutoComplete/SearchStations"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "searchTerm", value: query)]
        return components.url!
    }

    public func searchLinesURL(query: String) -> URL {
        var components = URLComponents(url: plannerBaseURL.appendingPathComponent("AutoComplete/SearchLines"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "searchTerm", value: query)]
        return components.url!
    }

    public func addressByCoordinatesURL(coordinate: CLLocationCoordinate2D) -> URL {
        var components = URLComponents(url: plannerBaseURL.appendingPathComponent("AutoComplete/GetAddressDataByCoordinates"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(format: "%.6f", coordinate.longitude))
        ]
        return components.url!
    }

    // MARK: - Scheduler / Stops Endpoints

    public func stopsCloseToLocationURL(coordinate: CLLocationCoordinate2D) -> URL {
        var components = URLComponents(url: schedulerBaseURL.appendingPathComponent("Stops/GetStopsCloseToLocation"), resolvingAgainstBaseURL: true)!
        // Note: MOT Scheduler API requires exact capital Lat and Lng
        components.queryItems = [
            URLQueryItem(name: "Lat", value: String(format: "%.6f", coordinate.latitude)),
            URLQueryItem(name: "Lng", value: String(format: "%.6f", coordinate.longitude))
        ]
        return components.url!
    }

    public func stopsCloseToLocationByRadiusURL(coordinate: CLLocationCoordinate2D, radiusMeters: Double) -> URL {
        var components = URLComponents(url: schedulerBaseURL.appendingPathComponent("Stops/GetStopsCloseToLocationByRadius"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "Lat", value: String(format: "%.6f", coordinate.latitude)),
            URLQueryItem(name: "Lng", value: String(format: "%.6f", coordinate.longitude)),
            URLQueryItem(name: "radius", value: String(Int(radiusMeters)))
        ]
        return components.url!
    }

    public func stopFullDataURL(stopCode: MOTStopCode) -> URL {
        var components = URLComponents(url: schedulerBaseURL.appendingPathComponent("Stops/GetStopFullData"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "stopCode", value: String(stopCode.rawValue))]
        return components.url!
    }

    public func refreshStopTimesURL(stopCode: MOTStopCode) -> URL {
        var components = URLComponents(url: schedulerBaseURL.appendingPathComponent("Stops/RefreshStopTimesAtStop"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "stopCode", value: String(stopCode.rawValue))]
        return components.url!
    }

    // MARK: - Scheduler / Routes Endpoints

    public func routeFullDataURL(routeID: MOTRouteID) -> URL {
        var components = URLComponents(url: schedulerBaseURL.appendingPathComponent("Routes/GetRouteFullData"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "routeId", value: String(routeID.rawValue))]
        return components.url!
    }

    public func routeStopsURL(routeID: MOTRouteID) -> URL {
        var components = URLComponents(url: schedulerBaseURL.appendingPathComponent("Routes/GetRouteStops"), resolvingAgainstBaseURL: true)!
        // Note: case-sensitive RouteId
        components.queryItems = [URLQueryItem(name: "RouteId", value: String(routeID.rawValue))]
        return components.url!
    }

    public func routeLocationsURL(routeID: MOTRouteID) -> URL {
        var components = URLComponents(url: schedulerBaseURL.appendingPathComponent("Routes/GetRouteLocations"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "routeId", value: String(routeID.rawValue))]
        return components.url!
    }

    public func nextStopTimesAndLocationURL() -> URL {
        return schedulerBaseURL.appendingPathComponent("Routes/GetNextStopTimesAndLocation")
    }

    // MARK: - Route Planning Endpoints

    public func getRoutesURL() -> URL {
        return plannerBaseURL.appendingPathComponent("RoutePlanning/GetRoutes")
    }
}
