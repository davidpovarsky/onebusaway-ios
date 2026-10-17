//
//  MOTFlexiblePolylineTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

#if canImport(OTPKit)
import OTPKit
#endif

@Suite(.serialized)
struct MOTFlexiblePolylineTests {

    @Test
    func testDecodeSampleHEREPolyline() throws {
        // First pedestrian segment from live fixture
        let sample = "BG4h918Bg30kjCgF4DUvCkIvHoGvH7GjN7LjNkDzFoBrEwH_EgFwCwHkIgFwCkIUsT3I_JnazZv-B7BrEwC3DUnG7BvHrE_EnG7BrE_O5DjI"
        let coordinates = try HEREFlexiblePolylineDecoder.decode(sample)

        #expect(coordinates.count == 25)
        #expect(abs(coordinates[0].latitude - 31.81622) < 0.0001)
        #expect(abs(coordinates[0].longitude - 35.20344) < 0.0001)
        #expect(abs(coordinates[24].latitude - 31.816269) < 0.0001)
        #expect(abs(coordinates[24].longitude - 35.20039) < 0.0001)
    }

    @Test
    func testDecodeAll24PolylinesFromLiveFixture() throws {
        let fixtureData = try MOTTestFixtures.loadFixture(named: "ministry_getroutes_live.json")
        let jsonObject = try JSONSerialization.jsonObject(with: fixtureData)
        guard let json = jsonObject as? [String: Any],
              let routes = json["data"] as? [[String: Any]] else {
            Issue.record("Failed to parse fixture JSON")
            return
        }

        var polylineStrings: [String] = []
        for route in routes {
            let sections = route["sections"] as? [[String: Any]] ?? []
            for section in sections {
                if let poly = section["polyline"] as? String, !poly.isEmpty {
                    polylineStrings.append(poly)
                }
            }
        }

        #expect(polylineStrings.count == 24)

        var totalVertices = 0
        for poly in polylineStrings {
            let coords = try HEREFlexiblePolylineDecoder.decode(poly)
            totalVertices += coords.count

            // All coordinates must be within geographical bounds of Israel
            for coord in coords {
                #expect(coord.latitude >= 29.0 && coord.latitude <= 34.0)
                #expect(coord.longitude >= 34.0 && coord.longitude <= 36.5)
            }

            // Must convert cleanly to Google polyline
            let googlePoly = GooglePolylineEncoder.encode(coords)
            #expect(!googlePoly.isEmpty)

            let roundtripped = GooglePolylineEncoder.decode(googlePoly)
            #expect(roundtripped.count == coords.count)
        }

        // Verify the exact expected 1,724 vertices from the contract
        #expect(totalVertices == 1724)
    }

    @Test
    func testEmptyPolylineHandling() throws {
        let empty = try HEREFlexiblePolylineDecoder.decode("")
        #expect(empty.isEmpty)
    }

    @Test
    func testInvalidPolylineHandling() {
        #expect(throws: Error.self) {
            try HEREFlexiblePolylineDecoder.decode("INVALID_HEADER_XYZ")
        }
    }

    #if canImport(OTPKit)
    @Test
    func testLegGeometryMapperConvertsHEREToGoogle() {
        let herePoly = "BG4h918Bg30kjCgF4DUvCkIvHoGvH7GjN7LjNkDzFoBrEwH_EgFwCwHkIgFwCkIUsT3I_JnazZv-B7BrEwC3DUnG7BvHrE_EnG7BrE_O5DjI"
        let fallbackStart = CLLocationCoordinate2D(latitude: 31.8, longitude: 35.2)
        let fallbackEnd = CLLocationCoordinate2D(latitude: 31.7, longitude: 35.2)

        let legGeometry = MOTLegGeometryMapper.map(
            fromPolyline: herePoly,
            fallbackOrigin: fallbackStart,
            fallbackDest: fallbackEnd
        )

        #expect(legGeometry.length == 25)
        #expect(!legGeometry.points.isEmpty)
        // Ensure points is Google polyline (doesn't start with B)
        #expect(!legGeometry.points.hasPrefix("BG4"))
    }
    #endif
}
