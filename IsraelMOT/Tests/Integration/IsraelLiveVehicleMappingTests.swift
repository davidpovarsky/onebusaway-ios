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
            lineName: "31",
            destination: "רמות",
            scheduledTime: Date().addingTimeInterval(300),
            estimatedTime: isRealTime ? Date().addingTimeInterval(300) : nil,
            minutesToArrival: 5,
            isRealTime: isRealTime,
            vehicleLocation: location,
            staticTripId: "86_01",
            tripIdToDate: nil,
            routeDesc: MOTRouteDesc("10031-1-0"),
            stopSequence: 1,
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס"
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

        guard let lastKnown = s["lastKnownLocation"] as? [String: Any] else {
            Issue.record("Missing lastKnownLocation in tripStatus")
            return
        }
        #expect(lastKnown["lat"] as? Double == 31.789)
        #expect(lastKnown["lon"] as? Double == 35.204)
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

    @Test
    func testRouteStopTimelineGeneration() {
        let stop1 = Stop(id: "mot:stop:2190", name: "בר אילן/שמואל הנביא", coordinate: CLLocationCoordinate2D(latitude: 31.795, longitude: 35.218))
        let stop2 = Stop(id: "mot:stop:5130", name: "גולדה מאיר/שדרות גולדה", coordinate: CLLocationCoordinate2D(latitude: 31.802, longitude: 35.210))
        let stop3 = Stop(id: "mot:stop:3040", name: "שדרות רמות/קניון רמות", coordinate: CLLocationCoordinate2D(latitude: 31.815, longitude: 35.195))

        let route = Route(id: "mot:route:33285", shortName: "71", agency: Agency(id: "mot:agency:16", name: "סופרבוס"))
        let stopsForRoute = StopsForRoute(route: route, stops: [stop1, stop2, stop3], polylines: [])

        let items = IsraelRouteStopTimelineFactory.makeTimeline(from: stopsForRoute)
        #expect(items.count == 3)
        #expect(items[0].isFirstStop == true)
        #expect(items[0].isLastStop == false)
        #expect(items[0].sequence == 1)
        #expect(items[0].stopCode == "2190")

        #expect(items[1].isFirstStop == false)
        #expect(items[1].isLastStop == false)
        #expect(items[1].sequence == 2)
        #expect(items[1].stopCode == "5130")

        #expect(items[2].isFirstStop == false)
        #expect(items[2].isLastStop == true)
        #expect(items[2].sequence == 3)
        #expect(items[2].stopCode == "3040")
    }
}
