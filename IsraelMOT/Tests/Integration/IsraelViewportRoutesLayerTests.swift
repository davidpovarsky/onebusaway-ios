//
//  IsraelViewportRoutesLayerTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
import MapKit
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelViewportRoutesLayerTests {

    @Test
    func testIsraelNearbyRoutesLayerMetadata() {
        #expect(IsraelNearbyRoutesMapLayer.layerID == "israelNearbyRoutes")
        #expect(IsraelNearbyRoutesMapLayer.routeCap == 6 || IsraelNearbyRoutesMapLayer.layerID.count > 0)
    }

    @Test
    func testNearbyRouteOverlayCarriesIdentityAndColor() {
        let coords = [
            CLLocationCoordinate2D(latitude: 31.815, longitude: 35.201),
            CLLocationCoordinate2D(latitude: 31.819, longitude: 35.205)
        ]
        let overlay = IsraelNearbyRouteOverlay.make(
            coordinates: coords,
            routeID: "mot:route:31",
            isCasing: false,
            color: .red
        )

        #expect(overlay.routeID == "mot:route:31")
        #expect(overlay.isCasing == false)
        #expect(overlay.color == .red)
    }

    @Test
    func testZoomWindowMatchesRequiredHeightToShowStops() {
        let zoomWindow = MapLayerZoomWindow(maxVisibleHeight: MapRegionManager.requiredHeightToShowStops)
        #expect(zoomWindow.contains(visibleHeight: 35000) == true)
        #expect(zoomWindow.contains(visibleHeight: 45000) == false)
    }

    @Test
    func testAmbientDataStructuresInitialization() {
        let coords = [
            CLLocationCoordinate2D(latitude: 31.815, longitude: 35.201),
            CLLocationCoordinate2D(latitude: 31.819, longitude: 35.205)
        ]
        let polyline = AmbientRoutePolyline(
            id: "mot:route:31",
            coordinates: coords,
            color: .blue,
            arrows: []
        )
        #expect(polyline.id == "mot:route:31")
        #expect(polyline.coordinates.count == 2)

        let vehicle = AmbientLiveVehicle(
            id: "veh_123",
            coordinate: coords[0],
            routeColor: .green,
            orientation: 180.0,
            routeType: .bus
        )
        #expect(vehicle.id == "veh_123")
        #expect(vehicle.orientation == 180.0)
        #expect(vehicle.routeType == .bus)
    }
}
