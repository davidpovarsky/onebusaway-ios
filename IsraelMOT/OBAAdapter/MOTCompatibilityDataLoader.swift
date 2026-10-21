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
    private let cache: MOTCache

    public init(
        client: MOTHTTPClient = MOTHTTPClient(),
        fallbackLoader: URLDataLoader = URLSession.shared,
        cache: MOTCache = MOTCache()
    ) {
        self.client = client
        self.endpoints = MOTEndpoints()
        self.fallbackLoader = fallbackLoader
        self.cache = cache
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

        // 3. Single Arrival & Departure for Stop: /api/where/arrival-and-departure-for-stop/{id}.json
        // Must match BEFORE plural arrivals-and-departures-for-stop!
        if path.contains("arrival-and-departure-for-stop") {
            return try await handleSingleArrivalAndDeparture(url: url)
        }

        // 4. Arrivals for Stop: /api/where/arrivals-and-departures-for-stop/{id}.json
        if path.contains("arrivals-and-departures-for-stop") {
            return try await handleArrivalsAndDepartures(url: url)
        }

        // 5. Route search: /api/where/routes-for-location.json
        if path.contains("routes-for-location") {
            return try await handleRoutesForLocation(url: url)
        }

        // 6. Route Detail: /api/where/route/{id}.json
        if path.contains("/where/route/") {
            return try await handleRouteDetail(url: url)
        }

        // 7. Stops for Route: /api/where/stops-for-route/{id}.json
        if path.contains("stops-for-route") {
            return try await handleStopsForRoute(url: url)
        }

        // 8. Schedule for Route: /api/where/schedule-for-route/{id}.json
        if path.contains("schedule-for-route") {
            return try await handleScheduleForRoute(url: url)
        }

        // 9. Shape by ID: /api/where/shape/{id}.json
        if path.contains("/where/shape/") {
            return try await handleShape(url: url)
        }

        // 10. Trip Details: /api/where/trip-details/{id}.json
        if path.contains("/where/trip-details/") {
            return try await handleTripDetails(url: url)
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

        // Never leak an unsupported OBA path to api.bus.gov.il.
        if url.host?.lowercased() == "api.bus.gov.il",
           path.hasPrefix("/prod/api/") {
            throw MOTCompatibilityError.unsupportedOneBusAwayEndpoint(url.path)
        }

        // Non-MOT URLs preserve the caller's normal URLSession behaviour.
        return try await fallbackLoader.data(for: request)
    }

    // MARK: - Handlers
    public static func parseSecondsFromTimeString(_ str: String) -> Int? {
        var timeStr = str
        if timeStr.contains("T") {
            timeStr = timeStr.split(separator: "T").last.map(String.init) ?? timeStr
        }
        if timeStr.contains("+") {
            timeStr = timeStr.split(separator: "+").first.map(String.init) ?? timeStr
        }
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 3600 + parts[1] * 60 + (parts.count >= 3 ? parts[2] : 0)
    }


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
            if let stopCodeInt = Int(q) {
                let code = MOTStopCode(rawValue: stopCodeInt)
                let localStops = IsraelStopCatalogRepository.shared.stops(forCode: code)
                if !localStops.isEmpty {
                    let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: localStops)
                    let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                    return (data, response)
                }
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

            let localStops = catalog.viewportStops(
                centerLat: lat,
                centerLon: lon,
                latSpan: lSpan,
                lonSpan: rSpan
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
        let requestedStopID = url.deletingPathExtension().lastPathComponent
        guard let stopCode = extractStopCode(from: url) else {
            return try await notFoundResponse(for: url)
        }
        let stopInternalID = extractStopInternalID(from: url)

        let catalog = IsraelStopCatalogRepository.shared
        let localStop: TransitStop?
        if let internalID = stopInternalID {
            localStop = catalog.stop(forInternalID: internalID)
        } else {
            localStop = catalog.stop(forCode: stopCode)
        }

        let targetURL = endpoints.stopFullDataURL(stopCode: stopCode)
        do {
            let res: StopFullDataResponseDTOServiceResponse = try await client.get(targetURL)
            if let dto = res.data {
                let remoteStop = MOTStopMapper.map(from: dto)
                let domainStop: TransitStop
                if let local = localStop {
                    domainStop = TransitStop(
                        code: local.code,
                        internalID: local.internalID,
                        name: local.name,
                        cityName: local.cityName ?? remoteStop.cityName,
                        streetName: local.streetName ?? remoteStop.streetName,
                        location: local.location,
                        platformNumber: local.platformNumber ?? remoteStop.platformNumber,
                        isAccessible: local.isAccessible ?? remoteStop.isAccessible,
                        routes: remoteStop.routes
                    )
                } else {
                    domainStop = remoteStop
                }
                let envelope = OBACompatibilityBridge.stopDetailResponse(
                    stop: domainStop,
                    requestedStopID: requestedStopID
                )
                let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                return (data, response)
            } else if let local = localStop {
                let envelope = OBACompatibilityBridge.stopDetailResponse(
                    stop: local,
                    requestedStopID: requestedStopID
                )
                let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                return (data, response)
            } else {
                return try await notFoundResponse(for: url)
            }
        } catch let error as MOTHTTPError {
            if case .httpError(statusCode: 404, responseBody: _) = error {
                if let local = localStop {
                    let envelope = OBACompatibilityBridge.stopDetailResponse(
                        stop: local,
                        requestedStopID: requestedStopID
                    )
                    let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                    return (data, response)
                }
                return try await notFoundResponse(for: url)
            }
            throw error
        } catch {
            if let local = localStop {
                let envelope = OBACompatibilityBridge.stopDetailResponse(
                    stop: local,
                    requestedStopID: requestedStopID
                )
                let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json; charset=utf-8"])!
                return (data, response)
            }
            throw error
        }
    }

    private func fetchStopAndArrivals(
        stopCode: MOTStopCode,
        stopInternalID: MOTStopInternalID?
    ) async throws -> (domainStop: TransitStop, arrivals: [TransitArrival], siblingPlatforms: [TransitStop]) {
        let catalog = IsraelStopCatalogRepository.shared
        let localStop: TransitStop?
        if let internalID = stopInternalID {
            localStop = catalog.stop(forInternalID: internalID)
        } else {
            localStop = catalog.stop(forCode: stopCode)
        }

        let siblingPlatforms = catalog.stops(forCode: stopCode).filter {
            $0.internalID != (localStop?.internalID ?? stopInternalID)
        }

        if let cachedArrivals = await cache.getArrivals(stopCode: stopCode),
           let cachedStop = await cache.getStop(code: stopCode) {
            return (cachedStop, cachedArrivals, siblingPlatforms)
        }

        let targetURL = endpoints.stopFullDataURL(stopCode: stopCode)
        let res: StopFullDataResponseDTOServiceResponse = try await client.get(targetURL)
        guard let dto = res.data else {
            throw MOTHTTPError.httpError(statusCode: 404, responseBody: "Stop not found")
        }

        let remoteStop = MOTStopMapper.map(from: dto)
        let domainStop: TransitStop
        if let local = localStop {
            domainStop = TransitStop(
                code: local.code,
                internalID: local.internalID,
                name: local.name,
                cityName: local.cityName ?? remoteStop.cityName,
                streetName: local.streetName ?? remoteStop.streetName,
                location: local.location,
                platformNumber: local.platformNumber ?? remoteStop.platformNumber,
                isAccessible: local.isAccessible ?? remoteStop.isAccessible,
                routes: remoteStop.routes
            )
        } else {
            domainStop = remoteStop
        }
        await cache.setStop(domainStop, code: stopCode, ttl: 180)

        let routesInStop = dto.routesInStop ?? []
        var stopTimesByRouteDesc: [String: [NextStopTimeDTO]] = [:]
        let nextStopURL = endpoints.nextStopTimesAndLocationURL()

        // Deterministic deduplication of route descriptors
        var seenDescs = Set<String>()
        let uniqueRouteDescs = routesInStop.compactMap { $0.routeDesc }.filter {
            !$0.isEmpty && seenDescs.insert($0).inserted
        }.sorted()

        // Bounded concurrency: process in batches of 4 to honor maxConcurrentRequests policy
        let client = self.client
        let batchSize = 4
        let chunkedDescs = stride(from: 0, to: uniqueRouteDescs.count, by: batchSize).map {
            Array(uniqueRouteDescs[$0 ..< min($0 + batchSize, uniqueRouteDescs.count)])
        }

        for chunk in chunkedDescs {
            await withTaskGroup(of: (String, [NextStopTimeDTO]).self) { group in
                for routeDesc in chunk {
                    group.addTask {
                        let reqBody = GetNextStopDataRequestDTO(routeDesc: routeDesc, stopCodes: [stopCode.rawValue])
                        let responseDTO: GetNextStopDataResponseDTOServiceResponse? = try? await client.post(
                            nextStopURL, body: reqBody, decodeAs: GetNextStopDataResponseDTOServiceResponse.self
                        )
                        let stopKey = String(stopCode.rawValue)
                        let times: [NextStopTimeDTO] = responseDTO?.data?[stopKey]??.stopTimes ?? []
                        return (routeDesc, times)
                    }
                }
                for await (routeDesc, times) in group {
                    stopTimesByRouteDesc[routeDesc] = times
                }
            }
        }

        let arrivals = MOTArrivalsMapper.map(routesInStop: routesInStop, stopTimesByRouteDesc: stopTimesByRouteDesc)
        await cache.setArrivals(arrivals, stopCode: stopCode, ttl: 20)
        return (domainStop, arrivals, siblingPlatforms)
    }

    private func handleArrivalsAndDepartures(url: URL) async throws -> (Data, URLResponse) {
        let requestedStopID = url.deletingPathExtension().lastPathComponent
        guard let stopCode = extractStopCode(from: url) else {
            return try await notFoundResponse(for: url)
        }
        let stopInternalID = extractStopInternalID(from: url)

        do {
            let result = try await fetchStopAndArrivals(stopCode: stopCode, stopInternalID: stopInternalID)
            let envelope = OBACompatibilityBridge.stopArrivalsResponse(
                stop: result.domainStop,
                arrivals: result.arrivals,
                requestedStopID: requestedStopID,
                nearbyStops: result.siblingPlatforms
            )
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

    private func handleSingleArrivalAndDeparture(url: URL) async throws -> (Data, URLResponse) {
        let requestedStopID = url.deletingPathExtension().lastPathComponent
        guard let stopCode = extractStopCode(from: url) else {
            return try await notFoundResponse(for: url)
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let tripIdParam = components?.queryItems?.first(where: { $0.name == "tripId" })?.value,
              let routeID = MOTIdentityFormatter.parseRouteIDFromTripID(tripIdParam) else {
            return try await notFoundResponse(for: url)
        }
        let stopSeqParam = components?.queryItems?.first(where: { $0.name == "stopSequence" })?.value.flatMap(Int.init)
        let stopInternalID = extractStopInternalID(from: url)

        do {
            let result = try await fetchStopAndArrivals(stopCode: stopCode, stopInternalID: stopInternalID)
            let matchingArrival = result.arrivals.first(where: {
                $0.id == tripIdParam ||
                $0.staticTripId == tripIdParam ||
                ($0.routeID == routeID && ($0.stopSequence == stopSeqParam || stopSeqParam == nil))
            })

            guard let arrival = matchingArrival else {
                // Truth-first: do NOT invent a midnight arrival from service date when the trip cannot be matched
                return try await notFoundResponse(for: url)
            }

            let envelope = OBACompatibilityBridge.arrivalAndDepartureForStopResponse(
                stop: result.domainStop,
                arrival: arrival,
                requestedStopID: requestedStopID
            )
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

    private func handleRoutesForLocation(url: URL) async throws -> (Data, URLResponse) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let rawQuery = components?.queryItems?.first {
            $0.name.lowercased() == "query"
        }?.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let latParam = components?.queryItems?.first { $0.name.lowercased() == "lat" }?.value.flatMap(Double.init)
        let lonParam = components?.queryItems?.first { $0.name.lowercased() == "lon" }?.value.flatMap(Double.init)

        // Preferred city detection based on search coordinates; defaults to Jerusalem for Region 972
        let preferredCity: String
        if let lat = latParam, let lon = lonParam {
            let jerusalemDist = hypot(lat - 31.78, lon - 35.21)
            let telAvivDist = hypot(lat - 32.08, lon - 34.78)
            let haifaDist = hypot(lat - 32.80, lon - 34.98)
            if telAvivDist < jerusalemDist && telAvivDist < haifaDist {
                preferredCity = "תל אביב"
            } else if haifaDist < jerusalemDist {
                preferredCity = "חיפה"
            } else {
                preferredCity = "ירושלים"
            }
        } else {
            preferredCity = "ירושלים"
        }

        let arabicIndicNumerals: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"
        ]
        let asciiQuery = String(rawQuery.map { arabicIndicNumerals[$0] ?? $0 })
        let query = asciiQuery.replacingOccurrences(
            of: "^(קו|خط|line|route|bus)\\s*",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let routeSummaries: [TransitRouteSummary]
        if query.isEmpty {
            routeSummaries = []
        } else {
            let tokens = query.split(separator: " ").map(String.init)
            let lineToken = tokens.first(where: { $0.contains(where: \.isNumber) })
            let textTokens = tokens.filter { !$0.contains(where: \.isNumber) }

            let apiSearchQuery = lineToken ?? query
            let searchURL = endpoints.searchLinesURL(query: apiSearchQuery)
            let startTime = Date()
            let response: MOTSearchLinesServiceResponse = try await client.get(searchURL)
            let elapsed = Date().timeIntervalSince(startTime)

            guard response.success else {
                #if canImport(OBAKitCore)
                let errMsg = response.message ?? "unknown error"
                Logger.error("[RouteSearch] SearchLines failed: \(errMsg)")
                #endif
                throw MOTHTTPError.serviceError(message: response.message ?? "SearchLines failed")
            }

            let rawList = response.data ?? []
            #if canImport(OBAKitCore)
            let elapsedStr = String(format: "%.2f", elapsed)
            Logger.info("[RouteSearch] SearchLines query='\(apiSearchQuery)' returned \(rawList.count) rows in \(elapsedStr)s")
            #endif

            let matching = rawList.filter { line in
                if let lt = lineToken {
                    guard line.routeName.localizedCaseInsensitiveContains(lt) else { return false }
                }
                for text in textTokens {
                    let matchesCity = line.cityName?.localizedCaseInsensitiveContains(text) == true
                    let matchesAgency = line.agencyName?.localizedCaseInsensitiveContains(text) == true
                    let matchesLongName = line.routeLongName?.localizedCaseInsensitiveContains(text) == true
                    let matchesRouteName = line.routeName.localizedCaseInsensitiveContains(text) == true
                    if !matchesCity && !matchesAgency && !matchesLongName && !matchesRouteName {
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

                let firstPrefCity = first.cityName?.localizedCaseInsensitiveContains(preferredCity) == true
                let secondPrefCity = second.cityName?.localizedCaseInsensitiveContains(preferredCity) == true
                if firstPrefCity != secondPrefCity { return firstPrefCity }

                let firstCity = first.cityName ?? ""
                let secondCity = second.cityName ?? ""
                if firstCity != secondCity { return firstCity < secondCity }

                return first.routeId < second.routeId
            }

            var seen = Set<Int>()
            routeSummaries = sorted.compactMap { line in
                guard seen.insert(line.routeId).inserted else { return nil }
                return line.toTransitRouteSummary()
            }
        }

        #if canImport(OBAKitCore)
        Logger.info("[RouteSearch] Returning \(routeSummaries.count) filtered routes for query='\(query)'")
        #endif

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

            let dateComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryDate = dateComponents?.queryItems?.first(where: { $0.name == "date" })?.value
            let targetDateString: String = {
                if let qd = queryDate, !qd.isEmpty { return qd }
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.timeZone = TimeZone(identifier: "Asia/Jerusalem") ?? TimeZone.current
                return f.string(from: Date())
            }()

            var dailyDepartures: [DailyCalendarDepartureDTO]? = nil
            var stopOffsets: [String: Int] = [:]
            if let firstStop = domainRoute.stops.first?.internalID?.rawValue,
               let lastStop = domainRoute.stops.last?.internalID?.rawValue {
                let calURL = endpoints.routeDailyCalendarURL(
                    startStopID: firstStop,
                    endStopID: lastStop,
                    routeID: routeID,
                    day: targetDateString
                )
                if let calRes: RouteDailyCalendarResponseDTOServiceResponse = try? await client.get(calURL),
                   let startDeps = calRes.data?.start, !startDeps.isEmpty {
                    dailyDepartures = startDeps
                }

                // Query TripCalendar for authentic GTFS stop times along the entire route
                let tripCalURL = endpoints.tripCalendarURL(
                    routeID: routeID,
                    stopID: firstStop,
                    date: targetDateString
                )
                if let tripCalRes: TripCalendarResponseDTOServiceResponse = try? await client.get(tripCalURL),
                   let stopDict = tripCalRes.data, !stopDict.isEmpty {
                    let startStopKey = String(firstStop)
                    let originDepStr = stopDict[startStopKey]?.first?.departureTimeString ?? stopDict[startStopKey]?.first?.departureTime
                    if let originDep = originDepStr, let originSec = Self.parseSecondsFromTimeString(originDep) {
                        for (stopKey, deps) in stopDict {
                            if let depStr = deps.first?.departureTimeString ?? deps.first?.departureTime,
                               let stopSec = Self.parseSecondsFromTimeString(depStr) {
                                let offset = max(0, stopSec - originSec)
                                stopOffsets[stopKey] = offset
                            }
                        }
                    }
                }
            }

            // Fallback: if tripCalendar didn't provide offsets, derive from routeDTO.stops nextStopsTimes
            if stopOffsets.isEmpty, let dtoStops = routeDTO.stops, !dtoStops.isEmpty {
                if let firstDTOStop = dtoStops.first,
                   let firstTimes = firstDTOStop.nextStopsTimes, !firstTimes.isEmpty,
                   let originDepStr = firstTimes[0].arrivalTimeString ?? firstTimes[0].arrivalTime,
                   let originSec = Self.parseSecondsFromTimeString(originDepStr) {
                    for s in dtoStops {
                        if let times = s.nextStopsTimes, !times.isEmpty {
                            let validTimes = times.compactMap { t -> (String, Int)? in
                                guard let str = t.arrivalTimeString ?? t.arrivalTime,
                                      let sec = Self.parseSecondsFromTimeString(str) else { return nil }
                                return (str, sec)
                            }.filter { $0.1 >= originSec && $0.1 <= originSec + 7200 }
                            if let best = validTimes.first {
                                let offset = best.1 - originSec
                                stopOffsets[String(s.stopid)] = offset
                                stopOffsets[String(s.stopcode)] = offset
                            }
                        }
                    }
                }
            }

            let envelope = OBACompatibilityBridge.scheduleForRouteResponse(
                route: domainRoute,
                departures: dailyDepartures,
                stopOffsets: stopOffsets.isEmpty ? nil : stopOffsets
            )
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

    private func handleShape(url: URL) async throws -> (Data, URLResponse) {
        let lastComponent = url.deletingPathExtension().lastPathComponent
        let shapeID = lastComponent.removingPercentEncoding ?? lastComponent
        guard let routeID = MOTIdentityFormatter.parseRouteIDFromShapeID(shapeID) else {
            return try await notFoundResponse(for: url)
        }

        let targetURL = endpoints.routeFullDataURL(routeID: routeID)
        do {
            let res: RouteFullDataResponseDTOServiceResponse = try await client.get(targetURL)
            guard let routeDTO = res.data,
                  let envelope = OBACompatibilityBridge.shapeResponse(routeID: routeID, polyline: routeDTO.polyline) else {
                return try await notFoundResponse(for: url)
            }
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

    private func handleTripDetails(url: URL) async throws -> (Data, URLResponse) {
        let lastComponent = url.deletingPathExtension().lastPathComponent
        let tripID = lastComponent.removingPercentEncoding ?? lastComponent
        guard let routeID = MOTIdentityFormatter.parseRouteIDFromTripID(tripID) else {
            return try await notFoundResponse(for: url)
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let serviceDateMs = components?.queryItems?.first(where: { $0.name == "serviceDate" })?.value.flatMap(Double.init)
        let targetServiceDate = serviceDateMs.map { Date(timeIntervalSince1970: $0 / 1000.0) } ?? Date()

        let targetURL = endpoints.routeFullDataURL(routeID: routeID)
        let stopsURL = endpoints.routeStopsURL(routeID: routeID)

        do {
            let res: RouteFullDataResponseDTOServiceResponse = try await client.get(targetURL)
            guard let routeDTO = res.data else {
                return try await notFoundResponse(for: url)
            }
            let stopsRes: RouteStopsResponseDTOServiceResponse? = try? await client.get(stopsURL)
            let domainRoute = MOTRouteMapper.map(routeDTO: routeDTO, stopsDTO: stopsRes?.data?.route)

            var calendar = Calendar(identifier: .gregorian)
            if let tz = TimeZone(identifier: "Asia/Jerusalem") {
                calendar.timeZone = tz
            }
            let serviceDateStart = calendar.startOfDay(for: targetServiceDate)

            var stopTimesData: [(stop: TransitStop, arrivalSec: Int?, departureSec: Int?)] = []
            var liveVehicleLoc: CLLocationCoordinate2D? = nil

            let rawTripParts = tripID.split(separator: "_")
            let matchTripToken: String? = rawTripParts.count >= 2 ? String(rawTripParts[1]) : nil

            // Discover starting departure time and target matching criteria
            var targetDepartureSec: Int? = nil
            if let token = matchTripToken {
                if let parsedSec = Self.parseSecondsFromTimeString(token) {
                    targetDepartureSec = parsedSec
                } else if let num = Double(token), num > 1_000_000_000 {
                    let d = Date(timeIntervalSince1970: num)
                    targetDepartureSec = Int(d.timeIntervalSince(serviceDateStart))
                }
            }

            // Pre-pass: check if any stop has an exact staticTripId or tripIdToDate match
            var hasExactIdMatch = false
            if let token = matchTripToken {
                for s in (routeDTO.stops ?? []) {
                    if let times = s.nextStopsTimes, times.contains(where: {
                        $0.staticTripId == token || ($0.tripIdToDate != nil && String($0.tripIdToDate!) == token)
                    }) {
                        hasExactIdMatch = true
                        break
                    }
                }
            }

            // Also build static stop offsets if available to provide complete timetable where real-time predictions haven't reached
            var tripStopOffsets: [String: Int] = [:]
            if let dtoStops = routeDTO.stops, let firstStopTimes = dtoStops.first?.nextStopsTimes, !firstStopTimes.isEmpty {
                let originTimeStr = firstStopTimes[0].arrivalTimeString ?? firstStopTimes[0].arrivalTime
                if let originTime = originTimeStr, let originSec = Self.parseSecondsFromTimeString(originTime) {
                    for s in dtoStops {
                        if let times = s.nextStopsTimes, !times.isEmpty {
                            let match = times.compactMap { t -> Int? in
                                guard let str = t.arrivalTimeString ?? t.arrivalTime,
                                      let sec = Self.parseSecondsFromTimeString(str) else { return nil }
                                return sec
                            }.filter { $0 >= originSec && $0 <= originSec + 7200 }.first
                            if let m = match {
                                tripStopOffsets[String(s.stopid)] = m - originSec
                                tripStopOffsets[String(s.stopcode)] = m - originSec
                            }
                        }
                    }
                }
            }

            var lastArrivalSec: Int? = targetDepartureSec
            for (idx, stop) in domainRoute.stops.enumerated() {
                var arrivalSec: Int? = nil
                var departureSec: Int? = nil

                if let dtoStop = routeDTO.stops?.first(where: { $0.stopid == stop.internalID?.rawValue || $0.stopcode == stop.code.rawValue }),
                   let nextTimes = dtoStop.nextStopsTimes, !nextTimes.isEmpty {
                    var matchedTime: NextStopTimeDTO? = nil
                    if hasExactIdMatch, let token = matchTripToken {
                        matchedTime = nextTimes.first(where: {
                            $0.staticTripId == token ||
                            ($0.tripIdToDate != nil && String($0.tripIdToDate!) == token)
                        })
                    } else {
                        // Chronological monotonic matching
                        if let lastSec = lastArrivalSec {
                            let candidates = nextTimes.compactMap { t -> (NextStopTimeDTO, Int)? in
                                guard let str = t.arrivalTimeString ?? t.arrivalTime,
                                      let sec = Self.parseSecondsFromTimeString(str) else { return nil }
                                return (t, sec)
                            }.filter { $0.1 >= lastSec && $0.1 <= lastSec + 900 }
                            if let best = candidates.first {
                                matchedTime = best.0
                            }
                        } else if idx == 0 {
                            matchedTime = nextTimes.first
                        }
                    }

                    if let timeObj = matchedTime {
                        if liveVehicleLoc == nil, let loc = timeObj.routeLocation {
                            liveVehicleLoc = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)
                        }
                        if let arrivalStr = timeObj.arrivalTimeString ?? timeObj.arrivalTime {
                            if let parsed = MOTDateParser.parse(arrivalStr) {
                                arrivalSec = Int(parsed.timeIntervalSince(serviceDateStart))
                            } else if let sec = Self.parseSecondsFromTimeString(arrivalStr) {
                                arrivalSec = sec
                            }
                        }
                        departureSec = arrivalSec
                        if let validArrival = arrivalSec {
                            lastArrivalSec = validArrival
                        }
                    }
                }

                // If real-time prediction hasn't reached this stop, use static scheduled offset if known and target departure is set
                if arrivalSec == nil, let targetStart = targetDepartureSec {
                    let internalKey = stop.internalID.map { String($0.rawValue) } ?? ""
                    let codeKey = String(stop.code.rawValue)
                    if let offset = tripStopOffsets[internalKey] ?? tripStopOffsets[codeKey] {
                        let schedSec = targetStart + offset
                        departureSec = schedSec
                        arrivalSec = schedSec
                        lastArrivalSec = schedSec
                    }
                }

                stopTimesData.append((stop: stop, arrivalSec: arrivalSec, departureSec: departureSec))
            }

            let envelope = OBACompatibilityBridge.tripDetailsResponse(
                tripID: tripID,
                route: domainRoute,
                stopTimes: stopTimesData,
                vehicleLocation: liveVehicleLoc,
                serviceDate: targetServiceDate
            )
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

    private func extractStopCode(from url: URL) -> MOTStopCode? {
        let lastComponent = url.deletingPathExtension().lastPathComponent
        return MOTIdentityFormatter.parseStopCode(fromScopedID: lastComponent)
    }

    private func extractStopInternalID(from url: URL) -> MOTStopInternalID? {
        let lastComponent = url.deletingPathExtension().lastPathComponent
        return MOTIdentityFormatter.parseStopInternalID(fromScopedID: lastComponent)
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
