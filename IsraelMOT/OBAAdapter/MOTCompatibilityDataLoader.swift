//
//  MOTCompatibilityDataLoader.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

#if canImport(OBAKitCore)
import OBAKitCore
#else
public protocol URLDataLoader: NSObjectProtocol, Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
extension URLSession: URLDataLoader {}
#endif

/// URLDataLoader implementation that intercepts OneBusAway REST API requests and serves
/// them by querying the official Israel MOT APIs and wrapping the result in OBA REST envelopes.
public final class MOTCompatibilityDataLoader: NSObject, URLDataLoader, @unchecked Sendable {
    private let client: MOTHTTPClient
    private let endpoints: MOTEndpoints
    private let fallbackLoader: URLDataLoader

    public init(
        client: MOTHTTPClient = MOTHTTPClient(),
        fallbackLoader: URLDataLoader = URLSession.shared
    ) {
        self.client = client
        self.endpoints = MOTEndpoints()
        self.fallbackLoader = fallbackLoader
        super.init()
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            return try await fallbackLoader.data(for: request)
        }

        let path = url.path.lowercased()

        // 1. Nearby Stops: /api/where/stops-for-location.json
        if path.contains("stops-for-location") {
            return try await handleStopsForLocation(url: url)
        }

        // 2. Stop Detail: /api/where/stop/{id}.json
        if path.contains("/where/stop/") {
            return try await handleStopDetail(url: url)
        }

        // 3. Arrivals: /api/where/arrivals-and-departures-for-stop/{id}.json
        if path.contains("arrivals-and-departures-for-stop") {
            return try await handleArrivalsAndDepartures(url: url)
        }

        // 4. Route Detail: /api/where/route/{id}.json
        if path.contains("/where/route/") {
            return try await handleRouteDetail(url: url)
        }

        // Fallback for everything else
        return try await fallbackLoader.data(for: request)
    }

    // MARK: - Handlers

    private func handleStopsForLocation(url: URL) async throws -> (Data, URLResponse) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems?.first(where: { $0.name.lowercased() == "query" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        let latStr = components?.queryItems?.first(where: { $0.name.lowercased() == "lat" })?.value
        let lonStr = components?.queryItems?.first(where: { $0.name.lowercased() == "lon" })?.value
        let latSpanStr = components?.queryItems?.first(where: { $0.name.lowercased() == "latspan" })?.value
        let lonSpanStr = components?.queryItems?.first(where: { $0.name.lowercased() == "lonspan" })?.value
        let radiusStr = components?.queryItems?.first(where: { $0.name.lowercased() == "radius" })?.value

        // 1. If search query is provided
        if let q = query, !q.isEmpty {
            // If query is a numeric stop code, resolve via GetStopFullData
            if let stopCodeInt = Int(q) {
                let code = MOTStopCode(stopCodeInt)
                let targetURL = endpoints.stopFullDataURL(stopCode: code)
                if let res: StopFullDataResponseDTOServiceResponse = try? await client.get(targetURL),
                   let dto = res.data {
                    let domainStop = MOTStopMapper.map(from: dto)
                    let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: [domainStop])
                    let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                    return (data, response)
                }
            }

            // General location/station query
            let searchURL = endpoints.searchLocationsURL(query: q)
            if let res: LocationAutoCompleteDTOServiceResponse = try? await client.get(searchURL),
               let items = res.data {
                let domainStops = items.compactMap { MOTStopMapper.map(from: $0) }
                let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: domainStops)
                let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                return (data, response)
            }
        }

        // 2. Geographic coordinate search
        guard let lat = latStr.flatMap(Double.init), let lon = lonStr.flatMap(Double.init) else {
            return try await emptyStopsResponse(for: url)
        }

        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let latSpan = latSpanStr.flatMap(Double.init)
        let lonSpan = lonSpanStr.flatMap(Double.init)
        let explicitRadius = radiusStr.flatMap(Double.init)

        let targetURL: URL
        if let explicitRadius = explicitRadius {
            let radiusMeters = max(250.0, min(15000.0, explicitRadius))
            targetURL = endpoints.stopsCloseToLocationByRadiusURL(coordinate: coord, radiusMeters: radiusMeters)
        } else if let latSpan = latSpan, let lonSpan = lonSpan {
            // Approximate degree to meters: 1 deg lat ~ 111km, 1 deg lon at ~32deg ~ 94km
            let halfSpanMeters = max(latSpan * 111000.0, lonSpan * 94000.0) / 2.0
            let radiusMeters = max(250.0, min(10000.0, halfSpanMeters))
            targetURL = endpoints.stopsCloseToLocationByRadiusURL(coordinate: coord, radiusMeters: radiusMeters)
        } else {
            targetURL = endpoints.stopsCloseToLocationURL(coordinate: coord)
        }

        do {
            let res: NearbyStopsResponseDTOServiceResponse = try await client.get(targetURL)
            let stopsDTO = res.data ?? []
            let domainStops = stopsDTO.map { MOTStopMapper.map(from: $0) }
            let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: domainStops)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        } catch {
            return try await emptyStopsResponse(for: url)
        }
    }

    private func handleStopDetail(url: URL) async throws -> (Data, URLResponse) {
        guard let stopCode = extractStopCode(from: url) else {
            return try await notFoundResponse(for: url)
        }

        let targetURL = endpoints.stopFullDataURL(stopCode: stopCode)
        do {
            let res: StopFullDataResponseDTOServiceResponse = try await client.get(targetURL)
            guard let dto = res.data else {
                return try await notFoundResponse(for: url)
            }
            let domainStop = MOTStopMapper.map(from: dto)
            let envelope = OBACompatibilityBridge.stopDetailResponse(stop: domainStop)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        } catch {
            return try await notFoundResponse(for: url)
        }
    }

    private func handleArrivalsAndDepartures(url: URL) async throws -> (Data, URLResponse) {
        guard let stopCode = extractStopCode(from: url) else {
            return try await notFoundResponse(for: url)
        }

        let targetURL = endpoints.stopFullDataURL(stopCode: stopCode)
        do {
            let res: StopFullDataResponseDTOServiceResponse = try await client.get(targetURL)
            guard let dto = res.data else {
                return try await notFoundResponse(for: url)
            }
            let domainStop = MOTStopMapper.map(from: dto)
            let routesInStop = dto.routesInStop ?? []

            // Live updates or fallback
            let arrivals = MOTArrivalsMapper.map(routesInStop: routesInStop, realTimeUpdates: [])
            let envelope = OBACompatibilityBridge.stopArrivalsResponse(stop: domainStop, arrivals: arrivals)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        } catch {
            return try await notFoundResponse(for: url)
        }
    }

    private func handleRouteDetail(url: URL) async throws -> (Data, URLResponse) {
        guard let routeID = extractRouteID(from: url) else {
            return try await notFoundResponse(for: url)
        }

        let targetURL = endpoints.routeFullDataURL(routeID: routeID)
        let stopsURL = endpoints.routeStopsURL(routeID: routeID)

        do {
            let res: RouteFullDataResponseDTOServiceResponse = try await client.get(targetURL)
            guard let routeDTO = res.data else {
                return try await notFoundResponse(for: url)
            }
            let stopsRes: RouteStopsResponseDTOServiceResponse? = try? await client.get(stopsURL)
            let domainRoute = MOTRouteMapper.map(routeDTO: routeDTO, stopsDTO: stopsRes?.data?.route)
            let envelope = OBACompatibilityBridge.routeDetailResponse(route: domainRoute)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        } catch {
            return try await notFoundResponse(for: url)
        }
    }

    // MARK: - Helpers

    private func extractStopCode(from url: URL) -> MOTStopCode? {
        let lastComponent = url.deletingPathExtension().lastPathComponent
        return MOTIdentityFormatter.parseStopCode(fromScopedID: lastComponent)
    }

    private func extractRouteID(from url: URL) -> MOTRouteID? {
        let lastComponent = url.deletingPathExtension().lastPathComponent
        return MOTIdentityFormatter.parseRouteID(fromScopedID: lastComponent)
    }

    private func emptyStopsResponse(for url: URL) async throws -> (Data, URLResponse) {
        let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: [])
        let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
        return (data, response)
    }

    private func notFoundResponse(for url: URL) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/plain"])!
        return (Data(), response)
    }
}
