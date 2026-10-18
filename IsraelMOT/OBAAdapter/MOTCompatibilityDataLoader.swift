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
nonisolated public final class MOTCompatibilityDataLoader: NSObject, URLDataLoader, @unchecked Sendable {
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

        // 4. Route search: /api/where/routes-for-location.json
        if path.contains("routes-for-location") {
            return try await handleRoutesForLocation(url: url)
        }

        // 5. Route Detail: /api/where/route/{id}.json
        if path.contains("/where/route/") {
            return try await handleRouteDetail(url: url)
        }

        // 6. Stops for Route: /api/where/stops-for-route/{id}.json
        if path.contains("stops-for-route") {
            return try await handleStopsForRoute(url: url)
        }

        // 7. Schedule for Route: /api/where/schedule-for-route/{id}.json
        if path.contains("schedule-for-route") {
            return try await handleScheduleForRoute(url: url)
        }

        // The official MOT server does NOT implement the OneBusAway REST API.
        // Agency-coverage geometry is unavailable: return an explicit empty
        // OBA-compatible list rather than sending a nonexistent endpoint to MOT.
        if (url.host?.lowercased() == "api.bus.gov.il" || url.host?.lowercased().contains("bus.gov.il") == true),
           path.contains("/api/where/agencies-with-coverage.json") {
            let payload: [String: Any] = [
                "code": 200,
                "text": "MOT does not provide OBA agency-coverage polygons",
                "version": 2,
                "currentTime": Int(Date().timeIntervalSince1970 * 1000),
                "data": [
                    "list": [] as [[String: Any]],
                    "references": [
                        "agencies": [] as [[String: Any]],
                        "routes": [] as [[String: Any]],
                        "stops": [] as [[String: Any]],
                        "trips": [] as [[String: Any]],
                        "situations": [] as [[String: Any]]
                    ] as [String: Any]
                ] as [String: Any]
            ]
            let data = try JSONSerialization.data(withJSONObject: payload)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        }

        // Never leak an unsupported OBA path to api.bus.gov.il. Otherwise an
        // invalid /prod/api/where or /prod/api/ondemand URL returns HTTP 403
        // and misleadingly looks like a failure of a supported ministry API.
        if url.host?.lowercased() == "api.bus.gov.il",
           path.hasPrefix("/prod/api/") {
            throw MOTCompatibilityError.unsupportedOneBusAwayEndpoint(url.path)
        }

        // Non-MOT URLs preserve the caller's normal URLSession behaviour.
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
            // If query is a numeric stop code, try live enrichment first, then local catalog
            if let stopCodeInt = Int(q) {
                let code = MOTStopCode(rawValue: stopCodeInt)
                let targetURL = endpoints.stopFullDataURL(stopCode: code)
                if let res: StopFullDataResponseDTOServiceResponse = try? await client.get(targetURL),
                   let dto = res.data {
                    let domainStop = MOTStopMapper.map(from: dto)
                    let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: [domainStop])
                    let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                    return (data, response)
                } else if let localStop = IsraelStopCatalogRepository.shared.stop(forCode: code) {
                    let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: [localStop])
                    let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                    return (data, response)
                }
            }

            // Text search: try local catalog first
            let localMatching = IsraelStopCatalogRepository.shared.searchStops(query: q, limit: 20)
            if !localMatching.isEmpty {
                let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: localMatching)
                let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                return (data, response)
            }

            // Fallback to remote location autocomplete
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

        let latSpan = latSpanStr.flatMap(Double.init)
        let lonSpan = lonSpanStr.flatMap(Double.init)

        // Viewport query via nationwide local SQLite stop catalog
        let catalog = IsraelStopCatalogRepository.shared
        if catalog.isAvailable {
            let lSpan = latSpan ?? 0.02
            let rSpan = lonSpan ?? 0.02

            // Zoom gate: when zoomed out beyond a metropolitan area, return empty to prevent pin flood
            if lSpan > 0.8 {
                let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: [])
                let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                return (data, response)
            }

            // Viewport query with 15% margin on each side
            let marginLat = lSpan * 0.15
            let marginLon = rSpan * 0.15
            let minLat = lat - (lSpan / 2.0) - marginLat
            let maxLat = lat + (lSpan / 2.0) + marginLat
            let minLon = lon - (rSpan / 2.0) - marginLon
            let maxLon = lon + (rSpan / 2.0) + marginLon

            let localStops = catalog.stops(
                minLat: minLat,
                maxLat: maxLat,
                minLon: minLon,
                maxLon: maxLon,
                limit: 350
            )

            let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: localStops)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        }

        // Fallback to remote nearby stops if catalog is unavailable
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let explicitRadius = radiusStr.flatMap(Double.init)

        let targetURL: URL
        if let explicitRadius = explicitRadius {
            let radiusMeters = max(250.0, min(15000.0, explicitRadius))
            targetURL = endpoints.stopsCloseToLocationByRadiusURL(coordinate: coord, radiusMeters: radiusMeters)
        } else if let latSpan = latSpan, let lonSpan = lonSpan {
            let halfSpanMeters = max(latSpan * 111000.0, lonSpan * 94000.0) / 2.0
            let radiusMeters = max(250.0, min(10000.0, halfSpanMeters))
            targetURL = endpoints.stopsCloseToLocationByRadiusURL(coordinate: coord, radiusMeters: radiusMeters)
        } else {
            targetURL = endpoints.stopsCloseToLocationURL(coordinate: coord)
        }

        do {
            let res: NearbyStopsResponseDTOServiceResponse = try await client.get(targetURL)
            guard res.success else {
                throw MOTHTTPError.serviceError(message: res.message ?? "MOT nearby stops request was unsuccessful")
            }
            let stopsDTO = res.data ?? []
            let domainStops = stopsDTO.map { MOTStopMapper.map(from: $0) }
            let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: domainStops)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        } catch {
            throw error
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
        } catch let error as MOTHTTPError {
            // Only a genuine 404 means the resource is absent.
            if case .httpError(statusCode: 404, responseBody: _) = error {
                return try await notFoundResponse(for: url)
            }
            throw error
        } catch {
            throw error
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

            // Query live arrivals/departures for lines serving this stop (bounded concurrency)
            var stopTimesByRouteDesc: [String: [NextStopTimeDTO]] = [:]
            let nextStopURL = endpoints.nextStopTimesAndLocationURL()

            let uniqueRouteDescs = Array(Set(routesInStop.compactMap { $0.routeDesc }.filter { !$0.isEmpty })).prefix(8)

            let client = self.client
            await withTaskGroup(of: (String, [NextStopTimeDTO]).self) { group in
                for routeDesc in uniqueRouteDescs {
                    group.addTask {
                        let reqBody = GetNextStopDataRequestDTO(routeDesc: routeDesc, stopCodes: [stopCode.rawValue])
                        let responseDTO: GetNextStopDataResponseDTOServiceResponse? = try? await client.post(nextStopURL, body: reqBody, decodeAs: GetNextStopDataResponseDTOServiceResponse.self)
                        let stopKey = String(stopCode.rawValue)
                        let times: [NextStopTimeDTO] = responseDTO?.data?[stopKey]??.stopTimes ?? []
                        return (routeDesc, times)
                    }
                }

                for await (routeDesc, times) in group {
                    stopTimesByRouteDesc[routeDesc] = times
                }
            }

            let arrivals = MOTArrivalsMapper.map(routesInStop: routesInStop, stopTimesByRouteDesc: stopTimesByRouteDesc)
            let envelope = OBACompatibilityBridge.stopArrivalsResponse(stop: domainStop, arrivals: arrivals)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        } catch let error as MOTHTTPError {
            // Only a genuine 404 means the resource is absent.
            if case .httpError(statusCode: 404, responseBody: _) = error {
                return try await notFoundResponse(for: url)
            }
            throw error
        } catch {
            throw error
        }
    }

    private func handleRoutesForLocation(url: URL) async throws -> (Data, URLResponse) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let rawQuery = components?.queryItems?.first {
            $0.name.lowercased() == "query"
        }?.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // OBA's route search sends a route number (e.g. "31") or composite string (e.g. "31 ירושלים").
        let query = rawQuery.replacingOccurrences(
            of: "^קו\\s*",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        let routeSummaries: [TransitRouteSummary]
        if query.isEmpty {
            routeSummaries = []
        } else {
            let tokens = query.split(separator: " ").map(String.init)
            let lineToken = tokens.first(where: { Int($0) != nil })
            let textTokens = tokens.filter { Int($0) == nil }

            let apiSearchQuery = lineToken ?? query
            let response: MOTSearchLinesServiceResponse = try await client.get(
                endpoints.searchLinesURL(query: apiSearchQuery)
            )
            guard response.success else {
                throw MOTHTTPError.serviceError(message: response.message ?? "SearchLines failed")
            }

            // Filter lines: exact or partial route number match, plus optional city/agency text filter
            let matching = (response.data ?? []).filter { line in
                if let lt = lineToken {
                    guard line.routeName.localizedCaseInsensitiveContains(lt) else { return false }
                }
                for text in textTokens {
                    let matchesCity = line.cityName?.localizedCaseInsensitiveContains(text) == true
                    let matchesAgency = line.agencyName?.localizedCaseInsensitiveContains(text) == true
                    let matchesLongName = line.routeLongName?.localizedCaseInsensitiveContains(text) == true
                    if !matchesCity && !matchesAgency && !matchesLongName {
                        return false
                    }
                }
                return true
            }

            let targetNum = lineToken ?? query
            let sorted = matching.sorted { first, second in
                let firstExact = first.routeName.compare(targetNum, options: .caseInsensitive) == .orderedSame
                let secondExact = second.routeName.compare(targetNum, options: .caseInsensitive) == .orderedSame
                if firstExact != secondExact { return firstExact }
                return (first.cityName ?? "") < (second.cityName ?? "")
            }

            var seen = Set<Int>()
            routeSummaries = sorted.compactMap { line in
                guard seen.insert(line.routeId).inserted else { return nil }
                return line.toTransitRouteSummary()
            }
        }

        let envelope = OBACompatibilityBridge.routesForLocationResponse(routes: routeSummaries)
        let data = try JSONSerialization.data(withJSONObject: envelope)
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json; charset=utf-8"]
        )!
        return (data, response)
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
        } catch let error as MOTHTTPError {
            // Only a genuine 404 means the resource is absent.
            if case .httpError(statusCode: 404, responseBody: _) = error {
                return try await notFoundResponse(for: url)
            }
            throw error
        } catch {
            throw error
        }
    }

    private func handleStopsForRoute(url: URL) async throws -> (Data, URLResponse) {
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
            let envelope = OBACompatibilityBridge.stopsForRouteResponse(route: domainRoute)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        } catch let error as MOTHTTPError {
            if case .httpError(statusCode: 404, responseBody: _) = error {
                return try await notFoundResponse(for: url)
            }
            throw error
        } catch {
            throw error
        }
    }

    private func handleScheduleForRoute(url: URL) async throws -> (Data, URLResponse) {
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
            let envelope = OBACompatibilityBridge.scheduleForRouteResponse(route: domainRoute)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
            return (data, response)
        } catch let error as MOTHTTPError {
            if case .httpError(statusCode: 404, responseBody: _) = error {
                return try await notFoundResponse(for: url)
            }
            throw error
        } catch {
            throw error
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

/// Deliberate capability rejection: an unsupported OneBusAway endpoint is NOT
/// an HTTP 403 from the official Ministry of Transport API.
nonisolated public enum MOTCompatibilityError: LocalizedError, Sendable {
    case unsupportedOneBusAwayEndpoint(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOneBusAwayEndpoint(let path):
            return "OneBusAway endpoint is not implemented for Israel MOT: \(path)"
        }
    }
}
