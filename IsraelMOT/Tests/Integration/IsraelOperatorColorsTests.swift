//
//  IsraelOperatorColorsTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
import UIKit
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelOperatorColorsTests {

    @Test
    func testOperatorColorsResolvedForMajorAgencies() {
        let eggedColor = MOTAgencyColorResolver.color(forAgencyID: 3)
        let superbusColor = MOTAgencyColorResolver.color(forAgencyID: 16)
        let danColor = MOTAgencyColorResolver.color(forAgencyID: 5)
        let metropolineColor = MOTAgencyColorResolver.color(forAgencyID: 15)

        #expect(MOTAgencyColorResolver.hexColor(forAgencyID: 3) == "007A3D") // Egged Green
        #expect(MOTAgencyColorResolver.hexColor(forAgencyID: 16) == "004F9E") // Superbus Blue
        #expect(MOTAgencyColorResolver.hexColor(forAgencyID: 5) == "002D72") // Dan Navy
        #expect(MOTAgencyColorResolver.hexColor(forAgencyID: 15) == "EA5A00") // Metropoline Orange

        #expect(eggedColor != superbusColor)
        #expect(danColor != metropolineColor)
    }

    @Test
    func testTextColorContrast() {
        // Dark blue agency -> white text
        let superbusTextHex = MOTAgencyColorResolver.textColorHex(forAgencyID: 16)
        #expect(superbusTextHex == "FFFFFF")

        // Light/yellow color -> black text
        let blackHex = MOTAgencyColorResolver.contrastTextColor(forHex: "FFFF00")
        #expect(blackHex == "000000")

        // Dark color -> white text
        let whiteHex = MOTAgencyColorResolver.contrastTextColor(forHex: "000000")
        #expect(whiteHex == "FFFFFF")
    }

    @Test
    @MainActor
    func testStopMapFocusIsFocusableWithoutLiveVehicle() {
        let route = StopRouteFocusModel.DrawnRoute(
            routeID: "mot:route:31",
            shortName: "31",
            color: .blue,
            shapeID: "shape:31",
            hasLiveVehicle: false // NO live bus!
        )

        let focus = StopMapFocus()
        focus.apply(routes: [route])

        // Tapping route 31 must be focusable even without live bus
        #expect(focus.isFocusable(routeID: "mot:route:31") == true)
        focus.toggleFocus(routeID: "mot:route:31")
        #expect(focus.focusedRouteID == "mot:route:31")
    }

    @Test
    func testPolylineArrowDensityIsBounded() {
        // Construct coordinates spanning 12,000 meters
        var coords: [CLLocationCoordinate2D] = []
        for i in 0...10 {
            coords.append(CLLocationCoordinate2D(latitude: 31.78 + Double(i) * 0.01, longitude: 35.20))
        }

        let placements = PolylineDirectionArrows.placements(along: coords)
        #expect(placements.count <= 6, "Placements must not exceed maximumPlacementCount of 6")
    }
}
