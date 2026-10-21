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
        // Given 3 stops without observed per-stop timetable
        let stops = (1...3).map { i in
            TransitStop(
                code: MOTStopCode(100 + i),
                internalID: MOTStopInternalID(1000 + i),
                name: TransitMultiLanguageName(he: "תחנה \(i)", en: "Stop \(i)", ar: nil),
                location: .init(latitude: 31.8, longitude: 35.2)
            )
        }
        let route = TransitRoute(
            routeID: MOTRouteID(33287),
            lineName: "31",
            longName: "מוצא <-> יעד",
            routeDesc: MOTRouteDesc("10031-1-0"),
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס",
            stops: stops
        )
        let departure = DailyCalendarDepartureDTO(
            tripId: "mot:trip:33287_1",
            departureTime: "08:00:00",
            departureTimeString: "08:00"
        )

        let response = OBACompatibilityBridge.scheduleForRouteResponse(
            route: route,
            departures: [departure]
        )

        guard let data = response["data"] as? [String: Any],
              let entry = data["entry"] as? [String: Any],
              let groupings = entry["stopTripGroupings"] as? [[String: Any]],
              let firstGrouping = groupings.first,
              let trips = firstGrouping["tripsWithStopTimes"] as? [[String: Any]],
              let firstTrip = trips.first,
              let stopTimes = firstTrip["stopTimes"] as? [[String: Any]] else {
            Issue.record("Malformed scheduleForRoute response")
            return
        }

        #expect(stopTimes.count == 3)

        // First stop should have the genuine departure time (08:00:00 = 28800)
        #expect(stopTimes[0]["departureTime"] as? Int == 28800)

        // Intermediate stops without timetable must NOT have 28800 + idx * 90; they must be -1
        for i in 1..<stopTimes.count {
            let depTime = stopTimes[i]["departureTime"] as? Int
            #expect(depTime == -1)
            #expect(depTime != 28800 + (i * 90))
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
            arrivals: [arrival]
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
        let stop = TransitStop(
            code: MOTStopCode(101),
            internalID: MOTStopInternalID(1001),
            name: TransitMultiLanguageName(he: "תחנה", en: "Stop", ar: nil),
            location: .init(latitude: 31.8, longitude: 35.2)
        )
        let route = TransitRoute(
            routeID: MOTRouteID(9999),
            lineName: "לילה",
            longName: "מוצא <-> יעד",
            routeDesc: MOTRouteDesc("10999-1-0"),
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס",
            stops: [stop]
        )
        // 25:30:00 = 91800 seconds past midnight
        let departure = DailyCalendarDepartureDTO(
            tripId: "mot:trip:night_1",
            departureTime: "25:30:00",
            departureTimeString: "25:30"
        )

        let response = OBACompatibilityBridge.scheduleForRouteResponse(
            route: route,
            departures: [departure]
        )

        guard let data = response["data"] as? [String: Any],
              let entry = data["entry"] as? [String: Any],
              let groupings = entry["stopTripGroupings"] as? [[String: Any]],
              let firstGrouping = groupings.first,
              let trips = firstGrouping["tripsWithStopTimes"] as? [[String: Any]],
              let firstTrip = trips.first,
              let stopTimes = firstTrip["stopTimes"] as? [[String: Any]],
              let depTime = stopTimes.first?["departureTime"] as? Int else {
            Issue.record("Malformed overnight schedule")
            return
        }

        #expect(depTime == 91800)
        #expect(depTime > 86399) // Proves no clamp to 86399!
    }

    @Test
    func testScheduleForRouteStopTimeNegativeOneReturnsNilDate() throws {
        let json = """
        {
            "tripId": "mot:trip:1",
            "stopId": "mot:stop:101",
            "stopSequence": 1,
            "arrivalTime": -1,
            "departureTime": -1
        }
        """.data(using: .utf8)!

        let stopTime: ScheduleForRoute.RouteScheduleStopTime = try JSONDecoder().decode(ScheduleForRoute.RouteScheduleStopTime.self, from: json)
        #expect(!stopTime.hasValidDepartureTime)
        #expect(stopTime.departureDate(for: Date(), timeZone: TimeZone(identifier: "Asia/Jerusalem")!) == nil)
        #expect(stopTime.arrivalDate(for: Date(), timeZone: TimeZone(identifier: "Asia/Jerusalem")!) == nil)
    }

    @Test
    func testScheduleForRoutePositiveDepartureYieldsRealDate() throws {
        let json = """
        {
            "tripId": "mot:trip:1",
            "stopId": "mot:stop:101",
            "stopSequence": 1,
            "arrivalTime": 28800,
            "departureTime": 28800
        }
        """.data(using: .utf8)!

        let stopTime: ScheduleForRoute.RouteScheduleStopTime = try JSONDecoder().decode(ScheduleForRoute.RouteScheduleStopTime.self, from: json)
        #expect(stopTime.hasValidDepartureTime)
        let tz = TimeZone(identifier: "Asia/Jerusalem")!
        let date = try #require(stopTime.departureDate(for: Date(), timeZone: tz))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        #expect(cal.component(.hour, from: date) == 8)
        #expect(cal.component(.minute, from: date) == 0)
    }
}
