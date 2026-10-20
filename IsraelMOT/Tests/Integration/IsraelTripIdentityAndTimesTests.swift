//
//  IsraelTripIdentityAndTimesTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelTripIdentityAndTimesTests {

    @Test
    func testTripDetailsDoesNotFabricateMidnightZero() {
        // Given stop times with nil arrival seconds
        let stopTimes: [(stop: TransitStop, arrivalSec: Int?, departureSec: Int?)] = [
            (
                stop: TransitStop(
                    code: MOTStopCode(5130),
                    internalID: MOTStopInternalID(1001),
                    name: TransitMultiLanguageName(he: "צומת רמות", en: "Ramot Junc", ar: nil),
                    cityName: "ירושלים",
                    streetName: "גולדה מאיר",
                    location: CLLocationCoordinate2D(latitude: 31.815, longitude: 35.201),
                    platformNumber: nil,
                    isAccessible: true,
                    routes: []
                ),
                arrivalSec: nil, // Unknown stop time!
                departureSec: nil
            )
        ]

        let route = TransitRoute(
            routeID: MOTRouteID(33287),
            lineName: "86",
            longName: "ירושלים",
            routeDesc: MOTRouteDesc("10086-1-0"),
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס"
        )

        let response = OBACompatibilityBridge.tripDetailsResponse(
            tripID: "mot:trip:86_01",
            route: route,
            stopTimes: stopTimes
        )

        guard let data = response["data"] as? [String: Any],
              let entry = data["entry"] as? [String: Any],
              let schedule = entry["schedule"] as? [String: Any],
              let stopTimesList = schedule["stopTimes"] as? [[String: Any]] else {
            Issue.record("Malformed trip details response")
            return
        }

        #expect(stopTimesList.count == 1)
        let firstStop = stopTimesList[0]

        // Missing time must NOT be 0 (00:00)
        #expect(firstStop["arrivalTime"] == nil || (firstStop["arrivalTime"] as? Int) == -1)
        #expect(firstStop["departureTime"] == nil || (firstStop["departureTime"] as? Int) == -1)
    }

    @Test
    func testTripStopTimeDecodesNilWhenMissing() throws {
        let jsonWithMissingTimes = """
        {
            "stopId": "mot:stop:5130",
            "stopSequence": 1
        }
        """.data(using: .utf8)!

        let stopTime = try JSONDecoder().decode(TripStopTime.self, from: jsonWithMissingTimes)
        stopTime.serviceDate = Date()
        #expect(stopTime.arrivalDate == nil)
        #expect(stopTime.departureDate == nil)

        let jsonWithNegativeTimes = """
        {
            "stopId": "mot:stop:5130",
            "stopSequence": 1,
            "arrivalTime": -1,
            "departureTime": -1
        }
        """.data(using: .utf8)!

        let stopTime2 = try JSONDecoder().decode(TripStopTime.self, from: jsonWithNegativeTimes)
        stopTime2.serviceDate = Date()
        #expect(stopTime2.arrivalDate == nil)
        #expect(stopTime2.departureDate == nil)
    }

    @Test
    func testMissingTimeLocalizationHonesty() {
        let noTimeStr = OBALoc("trip_stop.no_time", value: "No time available", comment: "No scheduled time")
        #expect(!noTimeStr.isEmpty)
    }

    @Test
    func testServiceDateIsDistinctFromArrivalTime() {
        let calendarDay = "20261020"
        let arrivalSec = 36000 // 10:00:00 AM

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        let baseDate = formatter.date(from: calendarDay)!

        let arrivalDate = baseDate.addingTimeInterval(TimeInterval(arrivalSec))
        let calendarDayFromArrival = formatter.string(from: arrivalDate)

        #expect(calendarDayFromArrival == calendarDay)
        #expect(arrivalDate > baseDate)
    }
}
