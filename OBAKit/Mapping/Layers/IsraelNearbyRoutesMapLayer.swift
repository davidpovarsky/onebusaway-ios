//
//  IsraelNearbyRoutesMapLayer.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Combine
import CoreLocation
import MapKit
import OBAKitCore
import SwiftUI
import UIKit

/// Ambient polyline and chevrons for SwiftUI and tests.
public struct AmbientRoutePolyline: Identifiable, Sendable {
    public let id: String
    public let coordinates: [CLLocationCoordinate2D]
    public let color: Color
    public let arrows: [PolylineArrowPlacement]

    public init(id: String, coordinates: [CLLocationCoordinate2D], color: Color, arrows: [PolylineArrowPlacement]) {
        self.id = id
        self.coordinates = coordinates
        self.color = color
        self.arrows = arrows
    }
}

/// Ambient real-time vehicle for SwiftUI and tests, carrying human-readable transit details.
public struct AmbientLiveVehicle: Identifiable, Sendable {
    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let routeColor: Color
    public let orientation: CLLocationDirection?
    public let routeType: Route.RouteType
    public let routeShortName: String
    public let headsign: String
    public let agencyName: String
    public let nextStopName: String?
    public let etaDate: Date?
    public let lastUpdateTime: Date?
    public let tripID: String
    public let routeID: RouteID
    public let serviceDate: Date
    public let vehicleID: String?
    public let tripConvertible: TripConvertible?
    public let arrivalDeparture: ArrivalDeparture?

    public var accessibilityDescription: String {
        let line = routeShortName.isEmpty ? "" : "קו \(routeShortName)"
        let dest = headsign.isEmpty ? "" : "אל \(headsign)"
        let op = agencyName.isEmpty ? "" : agencyName
        let parts = [line, dest, op].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    public init(
        id: String,
        coordinate: CLLocationCoordinate2D,
        routeColor: Color,
        orientation: CLLocationDirection?,
        routeType: Route.RouteType,
        routeShortName: String = "",
        headsign: String = "",
        agencyName: String = "",
        nextStopName: String? = nil,
        etaDate: Date? = nil,
        lastUpdateTime: Date? = nil,
        tripID: String = "",
        routeID: RouteID = "",
        serviceDate: Date = Date(),
        vehicleID: String? = nil,
        tripConvertible: TripConvertible? = nil,
        arrivalDeparture: ArrivalDeparture? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.routeColor = routeColor
        self.orientation = orientation
        self.routeType = routeType
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.agencyName = agencyName
        self.nextStopName = nextStopName
        self.etaDate = etaDate
        self.lastUpdateTime = lastUpdateTime
        self.tripID = tripID
        self.routeID = routeID
        self.serviceDate = serviceDate
        self.vehicleID = vehicleID
        self.tripConvertible = tripConvertible
        self.arrivalDeparture = arrivalDeparture
    }
}

/// Overlay representing a route polyline in the ambient nearby routes map layer.
final class IsraelNearbyRouteOverlay: MKPolyline {
    nonisolated override init() {
        super.init()
    }

    var routeID: RouteID = ""
    var isCasing: Bool = false
    var color: UIColor = .systemBlue

    static func make(coordinates: [CLLocationCoordinate2D], routeID: RouteID, isCasing: Bool, color: UIColor) -> IsraelNearbyRouteOverlay {
        var coords = coordinates
        let overlay = IsraelNearbyRouteOverlay(coordinates: &coords, count: coords.count)
        overlay.routeID = routeID
        overlay.isCasing = isCasing
        overlay.color = color
        return overlay
    }
}

/// Live vehicle annotation on the ambient nearby routes map layer.
/// Guaranteed to represent a genuine, verified real-time vehicle with valid coordinates and human details.
final class IsraelNearbyVehicleAnnotation: VehicleAnnotation {
    let id: String
    let routeID: RouteID
    var routeColor: UIColor
    let routeShortName: String
    let headsign: String
    let agencyName: String
    let nextStopName: String?
    let etaDate: Date?
    let lastUpdateTime: Date?
    let tripID: String
    let arrivalDeparture: ArrivalDeparture?
    let tripConvertible: TripConvertible?

    nonisolated override init() {
        fatalError("Use init(id:routeID:routeColor:tripStatus:...)")
    }

    init(
        id: String,
        routeID: RouteID,
        routeColor: UIColor,
        tripStatus: TripStatus,
        routeShortName: String = "",
        headsign: String = "",
        agencyName: String = "",
        nextStopName: String? = nil,
        etaDate: Date? = nil,
        lastUpdateTime: Date? = nil,
        tripID: String = "",
        arrivalDeparture: ArrivalDeparture? = nil,
        tripConvertible: TripConvertible? = nil
    ) {
        self.id = id
        self.routeID = routeID
        self.routeColor = routeColor
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.agencyName = agencyName
        self.nextStopName = nextStopName
        self.etaDate = etaDate
        self.lastUpdateTime = lastUpdateTime
        self.tripID = tripID
        self.arrivalDeparture = arrivalDeparture
        self.tripConvertible = tripConvertible
        super.init(tripStatus: tripStatus)
        updateTitles()
    }

    private func updateTitles() {
        if !headsign.isEmpty && !routeShortName.isEmpty {
            self.title = "קו \(routeShortName) אל \(headsign)"
        } else if !routeShortName.isEmpty {
            self.title = "קו \(routeShortName)"
        } else {
            self.title = "אוטובוס"
        }

        var parts: [String] = []
        if !agencyName.isEmpty {
            parts.append(agencyName)
        }
        if let nextStop = nextStopName, !nextStop.isEmpty {
            parts.append("לתחנה: \(nextStop)")
        }
        if let eta = etaDate {
            let df = DateFormatter()
            df.timeStyle = .short
            df.locale = Locale(identifier: "he_IL")
            parts.append("הגעה: \(df.string(from: eta))")
        }
        if let update = lastUpdateTime {
            let rel = RelativeDateTimeFormatter()
            rel.locale = Locale(identifier: "he_IL")
            parts.append("עודכן: \(rel.localizedString(for: update, relativeTo: Date()))")
        }
        self.subtitle = parts.joined(separator: " • ")
    }
}

/// Performance instrumentation for the ambient Israel routes and live buses layer.
public struct IsraelMapMetrics: Sendable {
    public let viewportChangeAt: Date
    public var firstStopAt: Date?
    public var firstVehicleAt: Date?
    public var firstRouteAt: Date?
    public var allCompleteAt: Date?
    public var requestCount: Int = 0
    public var cacheHits: Int = 0
    public var failureCount: Int = 0
}

/// A bounded, viewport-aware ambient route and live bus layer for Region 972 (Israel).
/// Shows relevant nearby routes and authentic live vehicle positions at pedestrian zoom
/// without requiring the rider to tap and open an individual stop sheet first.
@MainActor
final class IsraelNearbyRoutesMapLayer: NSObject, MapLayer {

    static let layerID = "israelNearbyRoutes"
    static let routeCap: Int = 6

    var id: String { Self.layerID }
    var title: String {
        OBALoc("map_layers.israel_nearby_routes", value: "Nearby Routes & Live Buses", comment: "Map sheet row for ambient Israel active routes and buses")
    }
    var iconName: String { "bus.fill" }
    var tintColor: UIColor { ThemeColors.shared.brand }
    var group: MapLayerGroup { .transit }
    var isEnabledByDefault: Bool { true }

    var availability: MapLayerAvailability {
        if application.currentRegion?.regionIdentifier == 972 {
            return .available
        }
        return .unsupported
    }

    var zoomWindow: MapLayerZoomWindow {
        MapLayerZoomWindow(maxVisibleHeight: MapRegionManager.requiredHeightToShowStops)
    }

    var densityBudget: Int { 16 }
    var isClusterable: Bool { false }
    var refreshPolicy: MapLayerRefreshPolicy { .onViewportChange }
    var staleAfter: Duration? { .seconds(60) }

    // MARK: - Dependencies
    private let mapView: MKMapView
    private let shapeCache: ShapeCache
    private let apiService: RESTAPIService
    private let application: Application
    private weak var mapRegionManager: MapRegionManager?

    // MARK: - State
    private var overlays: [IsraelNearbyRouteOverlay] = []
    private var vehicleAnnotations: [IsraelNearbyVehicleAnnotation] = []
    private var arrowAnnotations: [PolylineArrowAnnotation] = []

    private(set) var ambientPolylines: [AmbientRoutePolyline] = []
    private(set) var ambientVehicles: [AmbientLiveVehicle] = []
    private(set) var viewportRoutes: [Route] = []
    public private(set) var lastMetrics: IsraelMapMetrics?
    var onContentDidChange: (() -> Void)?

    private var debounceTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var generation: Int = 0

    init(
        mapView: MKMapView,
        shapeCache: ShapeCache,
        apiService: RESTAPIService,
        application: Application,
        mapRegionManager: MapRegionManager
    ) {
        self.mapView = mapView
        self.shapeCache = shapeCache
        self.apiService = apiService
        self.application = application
        self.mapRegionManager = mapRegionManager
        super.init()

        mapView.register(
            PolylineArrowAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: PolylineArrowAnnotationView.reuseIdentifier
        )
        mapView.register(
            PulsingVehicleAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapView.reuseIdentifier(for: PulsingVehicleAnnotationView.self)
        )
    }

    // MARK: - MapLayer Protocol

    func activate() {
        if let rect = mapRegionManager?.lastVisibleMapRect {
            viewportDidChange(rect)
        }
    }

    func deactivate() {
        debounceTask?.cancel()
        debounceTask = nil
        fetchTask?.cancel()
        fetchTask = nil
        removeAllContent()
    }

    func viewportDidChange(_ mapRect: MKMapRect?) {
        debounceTask?.cancel()
        guard let mapRect = mapRect, application.currentRegion?.regionIdentifier == 972 else {
            fetchTask?.cancel()
            removeAllContent()
            return
        }

        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms settle debounce
            guard !Task.isCancelled, let self = self else { return }
            self.refreshNearbyRoutes(for: mapRect)
        }
    }

    func mapAnnotationsWereCleared() {
        mapView.addAnnotations(vehicleAnnotations)
        mapView.addAnnotations(arrowAnnotations)
    }

    func mapOverlaysWereCleared() {
        mapView.addOverlays(overlays, level: .aboveRoads)
    }

    func recedesBehindStopSheet(_ annotation: MKAnnotation) -> Bool {
        return true
    }

    func detailViewController(for annotation: MKAnnotation) -> UIViewController? {
        guard let vehicleAnnotation = annotation as? IsraelNearbyVehicleAnnotation else { return nil }
        let ambient = AmbientLiveVehicle(
            id: vehicleAnnotation.id,
            coordinate: vehicleAnnotation.coordinate,
            routeColor: Color(uiColor: vehicleAnnotation.routeColor),
            orientation: vehicleAnnotation.tripStatus?.orientation,
            routeType: .bus,
            routeShortName: vehicleAnnotation.routeShortName,
            headsign: vehicleAnnotation.headsign,
            agencyName: vehicleAnnotation.agencyName,
            nextStopName: vehicleAnnotation.nextStopName,
            etaDate: vehicleAnnotation.etaDate,
            lastUpdateTime: vehicleAnnotation.lastUpdateTime,
            tripID: vehicleAnnotation.tripID,
            routeID: vehicleAnnotation.routeID,
            vehicleID: vehicleAnnotation.tripStatus?.vehicleID
        )

        let hosting = UIHostingController(
            rootView: AmbientVehicleDetailCard(
                vehicle: ambient,
                onOpenTrip: { [weak self] in
                    guard let self = self else { return }
                    self.openTripDetails(for: vehicleAnnotation)
                },
                onClose: { [weak self] in
                    self?.mapView.deselectAnnotation(annotation, animated: true)
                }
            )
        )
        return hosting
    }

    private func openTripDetails(for vehicleAnnotation: IsraelNearbyVehicleAnnotation) {
        if let convertible = vehicleAnnotation.tripConvertible {
            let tripPage = TripPageViewController(application: application, tripConvertible: convertible)
            application.viewRouter.navigate(to: tripPage, from: application.viewRouter.currentViewController)
        } else if let arrDep = vehicleAnnotation.arrivalDeparture {
            let tripPage = TripPageViewController(application: application, arrivalDeparture: arrDep)
            application.viewRouter.navigate(to: tripPage, from: application.viewRouter.currentViewController)
        }
    }

    func annotationView(for annotation: MKAnnotation, in mapView: MKMapView) -> MKAnnotationView? {
        if annotation is PolylineArrowAnnotation {
            return mapView.dequeueReusableAnnotationView(
                withIdentifier: PolylineArrowAnnotationView.reuseIdentifier,
                for: annotation
            )
        }

        guard let vehicleAnnotation = annotation as? IsraelNearbyVehicleAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: MKMapView.reuseIdentifier(for: PulsingVehicleAnnotationView.self),
            for: vehicleAnnotation
        ) as? PulsingVehicleAnnotationView
        view?.realTimeAnnotationColor = vehicleAnnotation.routeColor
        view?.isSelectable = true
        view?.canShowCallout = true

        let disclosureBtn = UIButton(type: .detailDisclosure)
        disclosureBtn.accessibilityLabel = "פתח פרטי נסיעה"
        view?.rightCalloutAccessoryView = disclosureBtn

        return view
    }

    func renderer(for overlay: MKOverlay, in mapView: MKMapView) -> MKOverlayRenderer? {
        guard let routeOverlay = overlay as? IsraelNearbyRouteOverlay else { return nil }
        let renderer = MKPolylineRenderer(polyline: routeOverlay)
        let coreWidth: CGFloat = 4.5
        let casingExtra: CGFloat = 3.5
        renderer.lineWidth = routeOverlay.isCasing ? coreWidth + casingExtra : coreWidth
        renderer.strokeColor = routeOverlay.isCasing ? .white : routeOverlay.color
        renderer.lineCap = .round
        renderer.lineJoin = .round
        renderer.alpha = 0.95
        return renderer
    }

    // MARK: - Private Loading

    private func refreshNearbyRoutes(for mapRect: MKMapRect) {
        fetchTask?.cancel()
        generation += 1
        let currentGen = generation

        var metrics = IsraelMapMetrics(viewportChangeAt: Date())

        fetchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            guard let manager = self.mapRegionManager else { return }
            let stops = manager.stops
            guard !stops.isEmpty else {
                self.removeAllContent()
                return
            }
            metrics.firstStopAt = Date()

            let centerCoord = MKMapPoint(x: mapRect.midX, y: mapRect.midY).coordinate
            let centerLoc = CLLocation(latitude: centerCoord.latitude, longitude: centerCoord.longitude)

            // 1. Pick 1 to 3 stops closest to the center of the viewport
            let sortedStops = stops.sorted {
                $0.location.distance(from: centerLoc) < $1.location.distance(from: centerLoc)
            }
            let targetStops = Array(sortedStops.prefix(3))

            // 2. Discover routes serving these stops (budget: up to 4-6 routes)
            var candidateRoutes: [Route] = []
            var seenRouteIDs = Set<RouteID>()

            for stop in targetStops {
                for route in (stop.routes ?? []) {
                    if seenRouteIDs.insert(route.id).inserted {
                        candidateRoutes.append(route)
                    }
                }
            }

            // PHASE 1: Fetch live arrivals across the target stops concurrently
            metrics.requestCount += targetStops.count
            var liveVehicles: [(
                id: String,
                routeID: RouteID,
                color: UIColor,
                status: TripStatus,
                routeType: Route.RouteType,
                routeShortName: String,
                headsign: String,
                agencyName: String,
                nextStopName: String?,
                etaDate: Date?,
                lastUpdateTime: Date?,
                tripID: String,
                serviceDate: Date,
                arrivalDeparture: ArrivalDeparture
            )] = []

            await withTaskGroup(of: [ArrivalDeparture]?.self) { group in
                for stop in targetStops {
                    group.addTask { [apiService = self.apiService] in
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
                    guard let arrivals = result else {
                        metrics.failureCount += 1
                        continue
                    }
                    for dep in arrivals {
                        if let route = dep.route, seenRouteIDs.insert(route.id).inserted {
                            candidateRoutes.append(route)
                        }
                        if let status = dep.tripStatus,
                           status.isRealTime,
                           let loc = (status.lastKnownLocation?.coordinate ?? status.position?.coordinate),
                           loc.latitude >= 29.0 && loc.latitude <= 33.5 &&
                           loc.longitude >= 34.0 && loc.longitude <= 36.0 {
                            let lastUpdate = status.lastUpdate ?? Date()
                            if abs(Date().timeIntervalSince(lastUpdate)) <= 300 {
                                let color = dep.route?.color ?? ThemeColors.shared.brand
                                let routeType = dep.route?.routeType ?? .bus
                                let shortName = dep.route?.shortName ?? dep.routeShortName
                                let headsign = dep.tripHeadsign ?? ""
                                let agency = dep.route?.agency.name ?? ""
                                let nextStop = status.nextStop?.name ?? status.closestStop?.name
                                let eta = dep.predictedArrivalTime ?? dep.scheduledArrivalTime
                                let tripID = dep.tripID
                                let sDate = dep.serviceDate
                                liveVehicles.append((
                                    id: dep.id,
                                    routeID: dep.routeID,
                                    color: color,
                                    status: status,
                                    routeType: routeType,
                                    routeShortName: shortName,
                                    headsign: headsign,
                                    agencyName: agency,
                                    nextStopName: nextStop,
                                    etaDate: eta,
                                    lastUpdateTime: lastUpdate,
                                    tripID: tripID,
                                    serviceDate: sDate,
                                    arrivalDeparture: dep
                                ))
                            }
                        }
                    }
                }
            }

            guard !Task.isCancelled, currentGen == self.generation else { return }

            // PROGRESSIVE STEP 1: Publish live vehicles IMMEDIATELY!
            var newVehicles: [IsraelNearbyVehicleAnnotation] = []
            var newAmbientVehicles: [AmbientLiveVehicle] = []
            var seenVehicleIDs = Set<String>()
            for v in liveVehicles.prefix(8) {
                if seenVehicleIDs.insert(v.id).inserted {
                    let convertible = TripConvertible(arrivalDeparture: v.arrivalDeparture)
                    newVehicles.append(
                        IsraelNearbyVehicleAnnotation(
                            id: v.id,
                            routeID: v.routeID,
                            routeColor: v.color,
                            tripStatus: v.status,
                            routeShortName: v.routeShortName,
                            headsign: v.headsign,
                            agencyName: v.agencyName,
                            nextStopName: v.nextStopName,
                            etaDate: v.etaDate,
                            lastUpdateTime: v.lastUpdateTime,
                            tripID: v.tripID,
                            arrivalDeparture: v.arrivalDeparture,
                            tripConvertible: convertible
                        )
                    )
                    if let coord = (v.status.lastKnownLocation?.coordinate ?? v.status.position?.coordinate) {
                        newAmbientVehicles.append(
                            AmbientLiveVehicle(
                                id: v.id,
                                coordinate: coord,
                                routeColor: Color(uiColor: v.color),
                                orientation: v.status.orientation,
                                routeType: v.routeType,
                                routeShortName: v.routeShortName,
                                headsign: v.headsign,
                                agencyName: v.agencyName,
                                nextStopName: v.nextStopName,
                                etaDate: v.etaDate,
                                lastUpdateTime: v.lastUpdateTime,
                                tripID: v.tripID,
                                routeID: v.routeID,
                                serviceDate: v.serviceDate,
                                vehicleID: v.status.vehicleID,
                                tripConvertible: convertible,
                                arrivalDeparture: v.arrivalDeparture
                            )
                        )
                    }
                }
            }

            self.mapView.removeAnnotations(self.vehicleAnnotations)
            self.vehicleAnnotations = newVehicles
            self.mapView.addAnnotations(self.vehicleAnnotations)
            self.ambientVehicles = newAmbientVehicles
            metrics.firstVehicleAt = Date()
            self.onContentDidChange?()

            // PHASE 2: Fetch and render route polylines progressively
            self.viewportRoutes = candidateRoutes
            let selectedRoutes = Array(candidateRoutes.prefix(Self.routeCap))

            var newOverlays: [IsraelNearbyRouteOverlay] = []
            var newArrows: [PolylineArrowAnnotation] = []
            var newAmbientPolylines: [AmbientRoutePolyline] = []

            for route in selectedRoutes {
                guard !Task.isCancelled, currentGen == self.generation else { return }
                let routeColor = route.color ?? ThemeColors.shared.brand
                let rawID = route.id
                    .replacingOccurrences(of: "mot:route:", with: "")
                    .replacingOccurrences(of: "mot:shape:", with: "")
                let shapeID = "mot:shape:\(rawID)"
                metrics.requestCount += 1
                let coords = try? await self.shapeCache.coordinates(forShapeID: shapeID)

                if let validCoords = coords, !validCoords.isEmpty {
                    metrics.cacheHits += 1
                    let casing = IsraelNearbyRouteOverlay.make(coordinates: validCoords, routeID: route.id, isCasing: true, color: .white)
                    let core = IsraelNearbyRouteOverlay.make(coordinates: validCoords, routeID: route.id, isCasing: false, color: routeColor)
                    newOverlays.append(contentsOf: [casing, core])

                    let placements = Array(PolylineDirectionArrows.placements(along: validCoords).prefix(4))
                    let arrows = placements.map {
                        PolylineArrowAnnotation(placement: $0, tintColor: routeColor, routeID: route.id)
                    }
                    newArrows.append(contentsOf: arrows)

                    newAmbientPolylines.append(
                        AmbientRoutePolyline(
                            id: route.id,
                            coordinates: validCoords,
                            color: Color(uiColor: routeColor),
                            arrows: placements
                        )
                    )
                    if metrics.firstRouteAt == nil {
                        metrics.firstRouteAt = Date()
                    }
                }
            }

            guard !Task.isCancelled, currentGen == self.generation else { return }

            self.mapView.removeOverlays(self.overlays)
            self.mapView.removeAnnotations(self.arrowAnnotations)

            self.overlays = newOverlays
            self.arrowAnnotations = newArrows

            self.mapView.addOverlays(self.overlays, level: .aboveRoads)
            self.mapView.addAnnotations(self.arrowAnnotations)

            self.ambientPolylines = newAmbientPolylines
            metrics.allCompleteAt = Date()
            self.lastMetrics = metrics
            self.onContentDidChange?()

            let totalElapsed = String(format: "%.3f", Date().timeIntervalSince(metrics.viewportChangeAt))
            let firstVehElapsed = metrics.firstVehicleAt.map { String(format: "%.3f", $0.timeIntervalSince(metrics.viewportChangeAt)) } ?? "none"
            let firstRouteElapsed = metrics.firstRouteAt.map { String(format: "%.3f", $0.timeIntervalSince(metrics.viewportChangeAt)) } ?? "none"
            Logger.info("[IsraelMapMetrics] viewport-settle to vehicles=\(firstVehElapsed)s, routes=\(firstRouteElapsed)s, all=\(totalElapsed)s (reqs=\(metrics.requestCount), hits=\(metrics.cacheHits), fails=\(metrics.failureCount))")
        }
    }

    private func removeAllContent() {
        generation += 1
        mapView.removeOverlays(overlays)
        mapView.removeAnnotations(arrowAnnotations)
        mapView.removeAnnotations(vehicleAnnotations)
        overlays.removeAll()
        arrowAnnotations.removeAll()
        vehicleAnnotations.removeAll()
        ambientPolylines.removeAll()
        ambientVehicles.removeAll()
        viewportRoutes.removeAll()
        onContentDidChange?()
    }
}
