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

    private func makeArrival(location: CLLocationCoordinate2D?, isRealTime: Bool) -> TransitArrival {
        return TransitArrival(
            routeID: MOTRouteID(31),
            routeDesc: MOTRouteDesc("10031-1-0"),
            lineName: "31",
            destinationName: "רמות",
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס",
            aimedArrivalTime: Date().addingTimeInterval(300),
            expectedArrivalTime: isRealTime ? Date().addingTimeInterval(300) : nil,
            isRealTime: isRealTime,
            vehicleLocation: location
        )
    }

    @Test
    func testValidRealTimeLocationBuildsTripStatus() {
        let validCoord = CLLocationCoordinate2D(latitude: 31.789, longitude: 35.204)
        let arrival = makeArrival(location: validCoord, isRealTime: true)
        let status = OBACompatibilityBridge.serializeTripStatus(
            arrival: arrival,
            tripId: "mot:trip:86_01",
            stopId: "mot:stop:5130",
            serviceDateMs: 1774051200000
        )

        #expect(status != nil)
        guard let s = status else { return }

        #expect(s["activeTripId"] as? String == "mot:trip:86_01")
        #expect(s["predicted"] as? Bool == true)

        guard let pos = s["position"] as? [String: Any] else {
            Issue.record("Missing position in tripStatus")
            return
        }
        #expect(pos["lat"] as? Double == 31.789)
        #expect(pos["lon"] as? Double == 35.204)
    }

    @Test
    func testNullIslandLocationIsRejected() {
        let nullIsland = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let arrival = makeArrival(location: nullIsland, isRealTime: true)
        let status = OBACompatibilityBridge.serializeTripStatus(
            arrival: arrival,
            tripId: "mot:trip:86_01",
            stopId: "mot:stop:5130",
            serviceDateMs: 1774051200000
        )

        #expect(status == nil, "Null Island (0,0) must not build a live vehicle status")
    }

    @Test
    func testLocationOutsideIsraelIsRejected() {
        // New York coordinates
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let arrival = makeArrival(location: newYork, isRealTime: true)
        let status = OBACompatibilityBridge.serializeTripStatus(
            arrival: arrival,
            tripId: "mot:trip:86_01",
            stopId: "mot:stop:5130",
            serviceDateMs: 1774051200000
        )

        #expect(status == nil, "Coordinates outside Israel bounds must not build live vehicle status")
    }

    @Test
    func testNonRealTimeProducesNoLiveVehicleStatus() {
        let validCoord = CLLocationCoordinate2D(latitude: 31.789, longitude: 35.204)
        let arrival = makeArrival(location: validCoord, isRealTime: false) // Not real time!
        let status = OBACompatibilityBridge.serializeTripStatus(
            arrival: arrival,
            tripId: "mot:trip:86_01",
            stopId: "mot:stop:5130",
            serviceDateMs: 1774051200000
        )

        #expect(status == nil, "Non-real-time arrival must not produce live vehicle status")
    }
}
