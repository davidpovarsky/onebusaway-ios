//
//  IsraelViewportRouteRepository.swift
//  IsraelMOT
//
//  Authoritative spatial repository managing route retention, viewport diffing,
//  and vehicle caching during pan and zoom operations.
//

import Foundation
import CoreLocation
import MapKit
import Combine
import SwiftUI
import OBAKitCore

@MainActor
public final class IsraelViewportRouteRepository: ObservableObject {
    public static let shared = IsraelViewportRouteRepository()

    // MARK: - Published State
    @Published public private(set) var currentSnapshot: IsraelViewportSnapshot?
    @Published public private(set) var activeVehicles: [AmbientLiveVehicle] = []
    @Published public private(set) var activePolylines: [RouteID: [CLLocationCoordinate2D]] = [:]
    @Published public private(set) var isLoading: Bool = false

    // MARK: - Configuration & Thresholds
    public let envelopePaddingRatio: Double = 0.25 // 25% geographical margin
    public let cacheTTL: TimeInterval = 60.0 // 60s freshness
    public let vehicleStaleThreshold: TimeInterval = 300.0 // 5m prune threshold
    public let maxCachedRoutes: Int = 24
    public let maxCachedVehicles: Int = 32

    // MARK: - Internal State
    private var currentEnvelope: MKMapRect?
    private var lastFetchTime: Date?
    private var generation: Int = 0
    private var fetchTask: Task<Void, Never>?

    private var routeCache: [RouteID: Route] = [:]
    private var polylineCache: [RouteID: [CLLocationCoordinate2D]] = [:]
    private var vehicleCache: [String: AmbientLiveVehicle] = [:]

    public init() {}

    deinit {
        fetchTask?.cancel()
    }

    /// Evaluates viewport changes and triggers background updates only when moving outside the buffered envelope.
    public func updateViewport(
        visibleRect: MKMapRect,
        stops: [Stop],
        apiService: RESTAPIService?,
        shapeCache: ShapeCache?
    ) {
        guard let apiService = apiService, !stops.isEmpty else { return }

        // Check hysteresis: if visibleRect is fully inside currentEnvelope and data is not stale, retain snapshot
        if let currentEnv = currentEnvelope,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTTL,
           currentEnv.contains(visibleRect) {
            // Viewport is well within our buffered envelope: retain all content without re-querying
            return
        }

        // Expand query envelope with padding
        let paddedEnvelope = expand(rect: visibleRect, ratio: envelopePaddingRatio)
        self.currentEnvelope = paddedEnvelope

        // Launch cancellable fetch generation
        fetchTask?.cancel()
        generation += 1
        let currentGen = generation
        isLoading = true

        fetchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.executeFetch(
                envelope: paddedEnvelope,
                stops: stops,
                apiService: apiService,
                shapeCache: shapeCache,
                generation: currentGen
            )
        }
    }

    private func executeFetch(
        envelope: MKMapRect,
        stops: [Stop],
        apiService: RESTAPIService,
        shapeCache: ShapeCache?,
        generation targetGen: Int
    ) async {
        let centerPoint = MKMapPoint(x: envelope.midX, y: envelope.midY)
        let centerLoc = CLLocation(latitude: centerPoint.coordinate.latitude, longitude: centerPoint.coordinate.longitude)

        // Select candidate stops within or nearest to the padded envelope
        let stopsInOrNearEnvelope = stops
            .filter { stop in
                let pt = MKMapPoint(stop.coordinate)
                return envelope.contains(pt)
            }
            .sorted { $0.location.distance(from: centerLoc) < $1.location.distance(from: centerLoc) }

        let targetStops = Array(stopsInOrNearEnvelope.prefix(6))
        guard !targetStops.isEmpty else {
            isLoading = false
            return
        }

        // Collect routes serving these stops
        var candidateRoutes: [Route] = []
        var seenRouteIDs = Set<RouteID>()

        for stop in targetStops {
            for route in (stop.routes ?? []) {
                if seenRouteIDs.insert(route.id).inserted {
                    candidateRoutes.append(route)
                    routeCache[route.id] = route
                }
            }
        }

        // Fetch arrivals concurrently across target stops
        var freshVehicles: [AmbientLiveVehicle] = []
        await withTaskGroup(of: [ArrivalDeparture]?.self) { group in
            for stop in targetStops {
                group.addTask {
                    do {
                        let resp = try await apiService.getArrivalsAndDeparturesForStop(
                            id: stop.id,
                            minutesBefore: 0,
                            minutesAfter: 60
                        ).entry
                        return resp.arrivalsAndDepartures
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                guard let arrivals = result else { continue }
                for dep in arrivals {
                    if let route = dep.route, seenRouteIDs.insert(route.id).inserted {
                        candidateRoutes.append(route)
                        self.routeCache[route.id] = route
                    }

                    guard let status = dep.tripStatus,
                          status.isRealTime,
                          let loc = (status.lastKnownLocation?.coordinate ?? status.position?.coordinate)
                    else { continue }

                    guard loc.latitude >= 29.0 && loc.latitude <= 33.5 &&
                          loc.longitude >= 34.0 && loc.longitude <= 36.0 else { continue }

                    let lastUpdate = status.lastUpdate ?? Date()
                    guard abs(Date().timeIntervalSince(lastUpdate)) <= self.vehicleStaleThreshold else { continue }

                    let routeColor = dep.route?.color.map { Color(uiColor: $0) } ?? Color.green
                    let routeType = dep.route?.routeType ?? .bus
                    let shortName = dep.route?.shortName ?? dep.routeShortName
                    let headsign = dep.tripHeadsign ?? ""
                    let agency = dep.route?.agency.name ?? ""
                    let nextStop = status.nextStop?.name ?? status.closestStop?.name
                    let convertible = TripConvertible(arrivalDeparture: dep)

                    freshVehicles.append(
                        AmbientLiveVehicle(
                            id: dep.id,
                            coordinate: loc,
                            routeColor: routeColor,
                            orientation: status.orientation,
                            routeType: routeType,
                            routeShortName: shortName,
                            headsign: headsign,
                            agencyName: agency,
                            nextStopName: nextStop,
                            etaDate: dep.arrivalDepartureDate,
                            lastUpdateTime: lastUpdate,
                            tripID: dep.tripID,
                            routeID: dep.routeID,
                            serviceDate: dep.serviceDate,
                            vehicleID: status.vehicleID,
                            tripConvertible: convertible,
                            arrivalDeparture: dep
                        )
                    )
                }
            }
        }

        guard !Task.isCancelled, targetGen == self.generation else { return }

        // In-place diff & merge: update existing vehicles, prune only stale ones
        for v in freshVehicles {
            vehicleCache[v.id] = v
        }

        // Prune vehicles older than stale threshold
        let now = Date()
        vehicleCache = vehicleCache.filter { _, v in
            if let update = v.lastUpdateTime {
                return now.timeIntervalSince(update) <= self.vehicleStaleThreshold
            }
            return false
        }

        self.activeVehicles = Array(vehicleCache.values.prefix(maxCachedVehicles))

        // Progressively fetch polylines for candidate routes
        if let shapeCache = shapeCache {
            for route in candidateRoutes.prefix(maxCachedRoutes) {
                guard !Task.isCancelled, targetGen == self.generation else { return }
                if polylineCache[route.id] == nil {
                    let rawID = route.id
                        .replacingOccurrences(of: "mot:route:", with: "")
                        .replacingOccurrences(of: "mot:shape:", with: "")
                    let shapeID = "mot:shape:\(rawID)"
                    if let coords = try? await shapeCache.coordinates(forShapeID: shapeID), !coords.isEmpty {
                        polylineCache[route.id] = coords
                    }
                }
            }
        }

        guard !Task.isCancelled, targetGen == self.generation else { return }

        self.activePolylines = polylineCache
        self.lastFetchTime = Date()
        self.isLoading = false

        self.currentSnapshot = IsraelViewportSnapshot(
            timestamp: Date(),
            queryEnvelope: envelope,
            routes: Array(routeCache.values),
            vehicles: self.activeVehicles
        )
    }

    /// Clears all cached viewport data on explicit region switch.
    public func reset() {
        fetchTask?.cancel()
        fetchTask = nil
        generation += 1
        currentEnvelope = nil
        lastFetchTime = nil
        routeCache.removeAll()
        polylineCache.removeAll()
        vehicleCache.removeAll()
        activeVehicles.removeAll()
        activePolylines.removeAll()
        currentSnapshot = nil
        isLoading = false
    }

    private func expand(rect: MKMapRect, ratio: Double) -> MKMapRect {
        let dx = rect.size.width * ratio
        let dy = rect.size.height * ratio
        return MKMapRect(
            x: rect.origin.x - dx,
            y: rect.origin.y - dy,
            width: rect.size.width + (2 * dx),
            height: rect.size.height + (2 * dy)
        )
    }
}
