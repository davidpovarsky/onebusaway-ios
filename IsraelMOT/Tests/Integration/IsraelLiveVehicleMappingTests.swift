//
//  IsraelLiveVehicleMappingTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelLiveVehicleMappingTests {

    @Test
    func testValidRealTimeLocationBuildsTripStatus() {
        let validCoord = CLLocationCoordinate2D(latitude: 31.789, longitude: 35.204)
        let status = OBACompatibilityBridge.serializeTripStatus(
            tripID: "mot:trip:86_01",
            serviceDate: "20261020",
            location: validCoord,
            isRealTime: true
        )

        #expect(status != nil)
        guard let s = status else { return }

        #expect(s["activeTripId"] as? String == "mot:trip:86_01")
        #expect(s["predicted"] as? Bool == true)

        guard let loc = s["lastKnownLocation"] as? [String: Any] else {
            Issue.record("Missing lastKnownLocation in tripStatus")
            return
        }
        #expect(loc["lat"] as? Double == 31.789)
        #expect(loc["lon"] as? Double == 35.204)
    }

    @Test
    func testNullIslandLocationIsRejected() {
        let nullIsland = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let status = OBACompatibilityBridge.serializeTripStatus(
            tripID: "mot:trip:86_01",
            serviceDate: "20261020",
            location: nullIsland,
            isRealTime: true
        )

        #expect(status == nil, "Null Island (0,0) must not build a live vehicle status")
    }

    @Test
    func testLocationOutsideIsraelIsRejected() {
        // New York coordinates
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let status = OBACompatibilityBridge.serializeTripStatus(
            tripID: "mot:trip:86_01",
            serviceDate: "20261020",
            location: newYork,
            isRealTime: true
        )

        #expect(status == nil, "Coordinates outside Israel bounds must not build live vehicle status")
    }

    @Test
    func testNonRealTimeProducesNoLiveVehicleStatus() {
        let validCoord = CLLocationCoordinate2D(latitude: 31.789, longitude: 35.204)
        let status = OBACompatibilityBridge.serializeTripStatus(
            tripID: "mot:trip:86_01",
            serviceDate: "20261020",
            location: validCoord,
            isRealTime: false // Not real time!
        )

        #expect(status == nil, "Non-real-time arrival must not produce live vehicle status")
    }
}
