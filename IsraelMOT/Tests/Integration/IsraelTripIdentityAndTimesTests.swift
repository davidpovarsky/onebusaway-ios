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

        let response = OBACompatibilityBridge.tripDetailsResponse(
            tripID: "mot:trip:86_01",
            routeID: "mot:route:33287",
            serviceDate: "20261020",
            stops: stopTimes
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
        #expect(stopTime.arrival == nil)
        #expect(stopTime.departure == nil)
        #expect(stopTime.arrivalDate == nil)
        #expect(stopTime.departureDate == nil)
    }

    @Test
    func testTripStopListItemRendersDashWhenDateIsNil() {
        let item = TripStopListItem(
            stop: Stop.testing_stub(id: "5130", name: "צומת רמות"),
            stopSequence: 1,
            date: nil,
            historicalDate: nil,
            adherence: nil,
            isPast: false,
            isNextStop: true,
            isTransferredStop: false,
            formatters: Formatters()
        )

        #expect(item.formattedTime == "—")
        #expect(item.accessibilityFormattedTime == "אין זמן זמין")
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
