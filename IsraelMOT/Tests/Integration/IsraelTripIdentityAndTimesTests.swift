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

    @Test
    func testTripDetailsPreservesLastKnownLocationAndMonotonicTimes() {
        let stop1 = TransitStop(
            code: MOTStopCode(5130),
            internalID: MOTStopInternalID(1001),
            name: TransitMultiLanguageName(he: "תחנה 1", en: "Stop 1", ar: nil),
            cityName: "ירושלים",
            streetName: "גולדה מאיר",
            location: CLLocationCoordinate2D(latitude: 31.815, longitude: 35.201),
            platformNumber: nil,
            isAccessible: true,
            routes: []
        )
        let stop2 = TransitStop(
            code: MOTStopCode(5131),
            internalID: MOTStopInternalID(1002),
            name: TransitMultiLanguageName(he: "תחנה 2", en: "Stop 2", ar: nil),
            cityName: "ירושלים",
            streetName: "גולדה מאיר",
            location: CLLocationCoordinate2D(latitude: 31.818, longitude: 35.205),
            platformNumber: nil,
            isAccessible: true,
            routes: []
        )
        let route = TransitRoute(
            routeID: MOTRouteID(33287),
            lineName: "86",
            longName: "ירושלים",
            routeDesc: MOTRouteDesc("10086-1-0"),
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס"
        )
        let stopTimes: [(stop: TransitStop, arrivalSec: Int?, departureSec: Int?)] = [
            (stop: stop1, arrivalSec: 28800, departureSec: 28800),
            (stop: stop2, arrivalSec: 28980, departureSec: 28980)
        ]
        let vehicleLocation = CLLocationCoordinate2D(latitude: 31.816, longitude: 35.202)

        let response = OBACompatibilityBridge.tripDetailsResponse(
            tripID: "mot:trip:86_01",
            route: route,
            stopTimes: stopTimes,
            vehicleLocation: vehicleLocation
        )

        guard let data = response["data"] as? [String: Any],
              let entry = data["entry"] as? [String: Any],
              let status = entry["status"] as? [String: Any],
              let schedule = entry["schedule"] as? [String: Any],
              let stopTimesList = schedule["stopTimes"] as? [[String: Any]] else {
            Issue.record("Malformed trip details response")
            return
        }

        #expect(stopTimesList.count == 2)
        #expect(stopTimesList[0]["departureTime"] as? Int == 28800)
        #expect(stopTimesList[1]["departureTime"] as? Int == 28980)

        guard let lastKnown = status["lastKnownLocation"] as? [String: Any] else {
            Issue.record("Missing lastKnownLocation in trip status")
            return
        }
        #expect(lastKnown["lat"] as? Double == 31.816)
        #expect(lastKnown["lon"] as? Double == 35.202)

        let totalDist = status["totalDistanceAlongTrip"] as? Double ?? 0
        let distAlong = status["distanceAlongTrip"] as? Double ?? 0
        #expect(totalDist > 0, "totalDistanceAlongTrip must be positive geometric length")
        #expect(distAlong >= 0 && distAlong <= totalDist, "distanceAlongTrip must be bounded by totalDistanceAlongTrip")
        #expect(status["closestStop"] as? String == "mot:stop:5130_1001", "closestStop must be stop 5130")
        #expect((status["vehicleId"] as? String)?.isEmpty == false, "vehicleId must not be empty")
    }

    @Test
    func testRoutePickerQueryNormalization() {
        let arabicIndicQuery = "٣١"
        let normalized = RoutePickerViewModel.normalizeQuery(arabicIndicQuery)
        #expect(normalized == "31")

        let hebrewPrefixQuery = "קו 31"
        let normalizedHebrew = RoutePickerViewModel.normalizeQuery(hebrewPrefixQuery)
        #expect(normalizedHebrew == "31")

        let arabicPrefixQuery = "خط 31"
        let normalizedArabic = RoutePickerViewModel.normalizeQuery(arabicPrefixQuery)
        #expect(normalizedArabic == "31")
    }
}
