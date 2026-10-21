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
struct AmbientRoutePolyline: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
    let arrows: [PolylineArrowPlacement]

    init(id: String, coordinates: [CLLocationCoordinate2D], color: Color, arrows: [PolylineArrowPlacement]) {
        self.id = id
        self.coordinates = coordinates
        self.color = color
        self.arrows = arrows
    }
}

/// Ambient real-time vehicle for SwiftUI and tests.
struct AmbientLiveVehicle: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let routeColor: Color
    let orientation: CLLocationDirection?
    let routeType: Route.RouteType

    init(id: String, coordinate: CLLocationCoordinate2D, routeColor: Color, orientation: CLLocationDirection?, routeType: Route.RouteType) {
        self.id = id
        self.coordinate = coordinate
        self.routeColor = routeColor
        self.orientation = orientation
        self.routeType = routeType
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
/// Guaranteed to represent a genuine, verified real-time vehicle with valid coordinates.
final class IsraelNearbyVehicleAnnotation: VehicleAnnotation {
    let id: String
    let routeID: RouteID
    var routeColor: UIColor

    nonisolated override init() {
        fatalError("Use init(id:routeID:routeColor:tripStatus:)")
    }

    init(id: String, routeID: RouteID, routeColor: UIColor, tripStatus: TripStatus) {
        self.id = id
        self.routeID = routeID
        self.routeColor = routeColor
        super.init(tripStatus: tripStatus)
    }
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
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms settle debounce
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
        return nil
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

        fetchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            guard let manager = self.mapRegionManager else { return }
            let stops = manager.stops
            guard !stops.isEmpty else {
                self.removeAllContent()
                return
            }

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

            var liveVehicles: [(id: String, routeID: RouteID, color: UIColor, status: TripStatus, routeType: Route.RouteType)] = []

            // Query arrivals for the nearest stops to discover live vehicles (and additional routes if needed)
            // DECOUPLED: Query up to 3 nearest stops regardless of candidateRoutes.count
            for stop in targetStops.prefix(3) {
                guard !Task.isCancelled, currentGen == self.generation else { return }
                do {
                    let arrivalsResponse = try await self.apiService.getArrivalsAndDeparturesForStop(
                        id: stop.id,
                        minutesBefore: 0,
                        minutesAfter: 60
                    ).entry
                    for dep in arrivalsResponse.arrivalsAndDepartures {
                        if let route = dep.route, seenRouteIDs.insert(route.id).inserted {
                            candidateRoutes.append(route)
                        }
                        if let status = dep.tripStatus,
                           status.isRealTime,
                           let loc = (status.lastKnownLocation?.coordinate ?? status.position?.coordinate),
                           loc.latitude >= 29.0 && loc.latitude <= 33.5 &&
                           loc.longitude >= 34.0 && loc.longitude <= 36.0 {
                            let lastUpdate = status.lastUpdate ?? Date()
                            // Freshness check: update within last 5 minutes (300 seconds)
                            if abs(Date().timeIntervalSince(lastUpdate)) <= 300 {
                                let color = dep.route?.color ?? ThemeColors.shared.brand
                                let routeType = dep.route?.routeType ?? .bus
                                liveVehicles.append((id: dep.id, routeID: dep.routeID, color: color, status: status, routeType: routeType))
                            }
                        }
                    }
                } catch {
                    // Ambient layer failure is non-fatal
                }
            }

            guard !Task.isCancelled, currentGen == self.generation else { return }

            self.viewportRoutes = candidateRoutes
            let selectedRoutes = Array(candidateRoutes.prefix(Self.routeCap))

            // 3. Fetch polylines for selected routes
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
                let coords = try? await self.shapeCache.coordinates(forShapeID: shapeID)

                if let validCoords = coords, !validCoords.isEmpty {
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
                }
            }

            // 4. Create vehicle annotations ONLY with genuine live status
            var newVehicles: [IsraelNearbyVehicleAnnotation] = []
            var newAmbientVehicles: [AmbientLiveVehicle] = []
            var seenVehicleIDs = Set<String>()
            for v in liveVehicles.prefix(8) {
                if seenVehicleIDs.insert(v.id).inserted {
                    newVehicles.append(
                        IsraelNearbyVehicleAnnotation(id: v.id, routeID: v.routeID, routeColor: v.color, tripStatus: v.status)
                    )
                    if let coord = (v.status.lastKnownLocation?.coordinate ?? v.status.position?.coordinate) {
                        newAmbientVehicles.append(
                            AmbientLiveVehicle(
                                id: v.id,
                                coordinate: coord,
                                routeColor: Color(uiColor: v.color),
                                orientation: v.status.orientation,
                                routeType: v.routeType
                            )
                        )
                    }
                }
            }

            guard !Task.isCancelled, currentGen == self.generation else { return }

            // 5. Update MapView cleanly
            self.mapView.removeOverlays(self.overlays)
            self.mapView.removeAnnotations(self.arrowAnnotations)
            self.mapView.removeAnnotations(self.vehicleAnnotations)

            self.overlays = newOverlays
            self.arrowAnnotations = newArrows
            self.vehicleAnnotations = newVehicles

            self.mapView.addOverlays(self.overlays, level: .aboveRoads)
            self.mapView.addAnnotations(self.arrowAnnotations)
            self.mapView.addAnnotations(self.vehicleAnnotations)

            self.ambientPolylines = newAmbientPolylines
            self.ambientVehicles = newAmbientVehicles
            self.onContentDidChange?()
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
