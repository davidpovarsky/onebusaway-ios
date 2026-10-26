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
import IsraelMOT

/// Ambient polyline and chevrons for SwiftUI and tests.
struct AmbientRoutePolyline: Identifiable, Sendable {
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
            vehicleID: vehicleAnnotation.tripStatus?.vehicleID,
            tripConvertible: vehicleAnnotation.tripConvertible,
            arrivalDeparture: vehicleAnnotation.arrivalDeparture
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

    private var presentingViewController: UIViewController? {
        var responder: UIResponder? = mapView
        while let next = responder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            responder = next
        }
        return mapView.window?.rootViewController
    }

    private func openTripDetails(for vehicleAnnotation: IsraelNearbyVehicleAnnotation) {
        guard let host = presentingViewController else { return }
        if let convertible = vehicleAnnotation.tripConvertible {
            let tripPage = TripPageViewController(application: application, tripConvertible: convertible)
            application.viewRouter.navigate(to: tripPage, from: host)
        } else if let arrDep = vehicleAnnotation.arrivalDeparture {
            let tripPage = TripPageViewController(application: application, arrivalDeparture: arrDep)
            application.viewRouter.navigate(to: tripPage, from: host)
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

        fetchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let manager = self.mapRegionManager else { return }
            let stops = manager.stops
            guard !stops.isEmpty else { return }

            IsraelViewportRouteRepository.shared.updateViewport(
                visibleRect: mapRect,
                stops: stops,
                apiService: self.apiService,
                shapeCache: self.shapeCache
            )

            guard !Task.isCancelled, currentGen == self.generation else { return }
            self.applyRepositorySnapshot()
        }
    }

    private func applyRepositorySnapshot() {
        let repo = IsraelViewportRouteRepository.shared
        let vehicles = repo.activeVehicles
        self.ambientVehicles = vehicles
        self.viewportRoutes = repo.currentSnapshot?.routes ?? []

        // In-place diff annotations
        let incomingIDs = Set(vehicles.map(\.id))
        let toRemove = vehicleAnnotations.filter { !incomingIDs.contains($0.id) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
            vehicleAnnotations.removeAll { toRemove.contains($0) }
        }

        let existingIDs = Set(vehicleAnnotations.map(\.id))
        var toAdd: [IsraelNearbyVehicleAnnotation] = []
        for v in vehicles where !existingIDs.contains(v.id) {
            let convertible = v.tripConvertible ?? (v.arrivalDeparture.map { TripConvertible(arrivalDeparture: $0) })
            let ann = IsraelNearbyVehicleAnnotation(
                id: v.id,
                routeID: v.routeID,
                routeColor: UIColor(v.routeColor),
                tripStatus: v.arrivalDeparture?.tripStatus ?? TripStatus(),
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
            toAdd.append(ann)
            vehicleAnnotations.append(ann)
        }
        if !toAdd.isEmpty {
            mapView.addAnnotations(toAdd)
        }

        // In-place diff polylines
        let polylines = repo.activePolylines
        let existingOverlayIDs = Set(overlays.map(\.routeID))
        var newOverlays: [IsraelNearbyRouteOverlay] = []
        var newArrows: [PolylineArrowAnnotation] = []
        var newAmbientPolylines: [AmbientRoutePolyline] = []

        for (routeID, coords) in polylines where !existingOverlayIDs.contains(routeID) {
            let casing = IsraelNearbyRouteOverlay.make(coordinates: coords, routeID: routeID, isCasing: true, color: .white)
            let core = IsraelNearbyRouteOverlay.make(coordinates: coords, routeID: routeID, isCasing: false, color: ThemeColors.shared.brand)
            newOverlays.append(contentsOf: [casing, core])
            overlays.append(contentsOf: [casing, core])

            let placements = Array(PolylineDirectionArrows.placements(along: coords).prefix(4))
            let arrows = placements.map {
                PolylineArrowAnnotation(placement: $0, tintColor: ThemeColors.shared.brand, routeID: routeID)
            }
            newArrows.append(contentsOf: arrows)
            arrowAnnotations.append(contentsOf: arrows)

            newAmbientPolylines.append(
                AmbientRoutePolyline(
                    id: routeID,
                    coordinates: coords,
                    color: Color(uiColor: ThemeColors.shared.brand),
                    arrows: placements
                )
            )
        }

        if !newOverlays.isEmpty {
            mapView.addOverlays(newOverlays, level: .aboveRoads)
            mapView.addAnnotations(newArrows)
            self.ambientPolylines.append(contentsOf: newAmbientPolylines)
        }

        self.onContentDidChange?()
    }

    private func removeAllContent() {
        generation += 1
        IsraelViewportRouteRepository.shared.reset()
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
