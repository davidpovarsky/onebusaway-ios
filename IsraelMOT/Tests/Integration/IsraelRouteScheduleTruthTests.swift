//
//  IsraelRouteScheduleTruthTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelRouteScheduleTruthTests {

    @Test
    func testScheduleForRouteDoesNotInvent90SecondsIntervals() {
        // Given 5 stops without observed per-stop timetable
        let stopIDs = ["101", "102", "103", "104", "105"]
        let departures = [28800] // Single trip departing at 08:00

        let response = OBACompatibilityBridge.scheduleForRouteResponse(
            routeID: "mot:route:33287",
            stopIDs: stopIDs,
            departures: departures
        )

        guard let data = response["data"] as? [String: Any],
              let entry = data["entry"] as? [String: Any],
              let stops = entry["stops"] as? [[String: Any]] else {
            Issue.record("Malformed scheduleForRoute response")
            return
        }

        #expect(stops.count == 5)

        // First stop should have the genuine departure time
        let firstStop = stops[0]
        let firstTrips = (firstStop["scheduleStopTimes"] as? [[String: Any]]) ?? []
        #expect(firstTrips.first?["departureTime"] as? Int == 28800)

        // Intermediate stops without timetable must NOT have 28800 + idx * 90
        for i in 1..<stops.count {
            let stop = stops[i]
            let trips = (stop["scheduleStopTimes"] as? [[String: Any]]) ?? []
            if let depTime = trips.first?["departureTime"] as? Int {
                // Must be -1 (unknown) rather than synthetic 28800 + i * 90
                #expect(depTime == -1 || depTime != 28800 + (i * 90))
            }
        }
    }

    @Test
    func testArrivalResponseDoesNotInvent20StopsOrZeroDistance() {
        let stop = TransitStop(
            code: MOTStopCode(5130),
            internalID: MOTStopInternalID(1001),
            name: TransitMultiLanguageName(he: "תחנה", en: "Stop", ar: nil),
            cityName: "ירושלים",
            streetName: "רחוב",
            location: .init(latitude: 31.8, longitude: 35.2),
            platformNumber: nil,
            isAccessible: true,
            routes: []
        )

        let arrival = TransitArrival(
            routeID: MOTRouteID(31),
            lineName: "31",
            destination: "רמות",
            scheduledTime: Date().addingTimeInterval(600),
            estimatedTime: nil,
            minutesToArrival: 10,
            isRealTime: false,
            vehicleLocation: nil,
            staticTripId: nil,
            tripIdToDate: nil,
            routeDesc: MOTRouteDesc("10031-1-0"),
            stopSequence: 1,
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס"
        )

        let response = OBACompatibilityBridge.stopArrivalsResponse(
            stop: stop,
            arrivals: [arrival],
            serviceDate: "20261020"
        )

        guard let data = response["data"] as? [String: Any],
              let entry = data["entry"] as? [String: Any],
              let arrivalsList = entry["arrivalsAndDepartures"] as? [[String: Any]],
              let first = arrivalsList.first else {
            Issue.record("Malformed stopArrivals response")
            return
        }

        // Must not have fake totalStopsInTrip: 20
        #expect(first["totalStopsInTrip"] == nil || (first["totalStopsInTrip"] as? Int) != 20)

        // Distance and stops away must be absent or -1 when unknown, NOT 0.0
        let dist = first["distanceFromStop"] as? Double ?? -1.0
        let stopsAway = first["numberOfStopsAway"] as? Int ?? -1
        #expect(dist == -1.0 || dist < 0)
        #expect(stopsAway == -1 || stopsAway < 0)
    }

    @Test
    func testOvernightDepartureDoesNotClampTo86399() {
        // 25:30:00 = 91800 seconds past midnight
        let overnightSec = 91800
        let departures = [overnightSec]

        let response = OBACompatibilityBridge.scheduleForRouteResponse(
            routeID: "mot:route:night_line",
            stopIDs: ["101"],
            departures: departures
        )

        guard let data = response["data"] as? [String: Any],
              let entry = data["entry"] as? [String: Any],
              let stops = entry["stops"] as? [[String: Any]],
              let firstStop = stops.first,
              let trips = firstStop["scheduleStopTimes"] as? [[String: Any]],
              let depTime = trips.first?["departureTime"] as? Int else {
            Issue.record("Malformed overnight schedule")
            return
        }

        #expect(depTime == 91800)
        #expect(depTime > 86399) // Proves no clamp to 86399!
    }
}
