//
//  IsraelStopCatalogTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (Local Spatial Stop Catalog)
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelStopCatalogTests {

    @Test
    func testCatalogAvailabilityAndMetadata() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else {
            Issue.record("IsraelStopCatalogRepository is unavailable")
            return
        }

        let count = repo.totalStopCount()
        #expect(count > 30000, "Expected >30,000 stops nationwide, got \(count)")

        let meta = repo.metadata()
        #expect(meta["source"] == "GTFS-MOT")
        #expect(meta["schema_version"] != nil)
        #expect(meta["record_count"] != nil)
    }

    @Test
    func testKnownStop5997LookupWithMultilingualNames() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        let stop = repo.stop(forCode: MOTStopCode(5997))
        #expect(stop != nil)
        #expect(stop?.code.rawValue == 5997)
        #expect(stop?.internalID?.rawValue == 11622)
        #expect(stop?.name.he?.contains("סילבר") == true)
        #expect(stop?.name.en?.contains("Silver") == true)
        #expect(stop?.name.ar != nil && !stop!.name.ar!.isEmpty)
        #expect(abs((stop?.location.latitude ?? 0) - 31.815188) < 0.001)
        #expect(abs((stop?.location.longitude ?? 0) - 35.203022) < 0.001)
    }

    @Test
    func testKnownStop2899LookupWithMultilingualNames() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        let stop = repo.stop(forCode: MOTStopCode(2899))
        #expect(stop != nil)
        #expect(stop?.code.rawValue == 2899)
        #expect(stop?.internalID?.rawValue == 10168)
        #expect(stop?.name.he?.contains("בר לב") == true)
        #expect(stop?.name.en?.contains("Bar Lev") == true)
        #expect(stop?.name.ar != nil && !stop!.name.ar!.isEmpty)
    }

    @Test
    func testSpatialBoundingBoxQueryJerusalemCenter() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        // Bounding box for central Jerusalem
        let stops = repo.stops(
            minLat: 31.78,
            maxLat: 31.82,
            minLon: 35.20,
            maxLon: 35.23,
            limit: 200
        )

        #expect(!stops.isEmpty)
        #expect(stops.count <= 200)

        // Verify all returned stops are strictly within the bounding box
        for stop in stops {
            #expect(stop.location.latitude >= 31.78 && stop.location.latitude <= 31.82)
            #expect(stop.location.longitude >= 35.20 && stop.location.longitude <= 35.23)
        }
    }

    @Test
    func testStreetLevelViewportReturnsAllStopsWithoutArbitraryCutoff() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        // Query dense street viewport in Jerusalem
        let stops = repo.viewportStops(
            centerLat: 31.79,
            centerLon: 35.21,
            latSpan: 0.02,
            lonSpan: 0.02
        )

        #expect(!stops.isEmpty)
        // Ensure no arbitrary 350 cutoff: all matching stops in the street viewport are included
        let directCount = repo.stops(
            minLat: 31.79 - 0.013,
            maxLat: 31.79 + 0.013,
            minLon: 35.21 - 0.013,
            maxLon: 35.21 + 0.013,
            limit: nil
        ).count

        #expect(stops.count == directCount)
    }

    @Test
    func testScheduleForRouteTimetableDecodesWithStopTimes() throws {
        let stop1 = TransitStop(
            code: MOTStopCode(5997),
            internalID: MOTStopInternalID(11622),
            name: TransitMultiLanguageName(he: "סילבר", en: "Silver", ar: "سيلڤر"),
            location: CLLocationCoordinate2D(latitude: 31.815, longitude: 35.203)
        )
        let stop2 = TransitStop(
            code: MOTStopCode(2899),
            internalID: MOTStopInternalID(10168),
            name: TransitMultiLanguageName(he: "בר לב", en: "Bar Lev", ar: "بار ليڤ"),
            location: CLLocationCoordinate2D(latitude: 31.790, longitude: 35.228)
        )

        let route = TransitRoute(
            routeID: MOTRouteID(33287),
            lineName: "31",
            longName: "ירושלים",
            routeDesc: MOTRouteDesc("15031-1-0"),
            agencyID: MOTAgencyID(16),
            agencyName: "Superbus",
            cityName: "ירושלים",
            polyline: nil,
            stops: [stop1, stop2]
        )

        let envelope = OBACompatibilityBridge.scheduleForRouteResponse(route: route)
        let data = try JSONSerialization.data(withJSONObject: envelope, options: [])

        let decoder = JSONDecoder()
        let response = try decoder.decode(RESTAPIResponse<ScheduleForRoute>.self, from: data)

        let schedule = response.entry
        #expect(schedule.routeID == "mot:route:33287")
        #expect(!schedule.stopTripGroupings.isEmpty)

        let grouping = schedule.stopTripGroupings[0]
        #expect(grouping.directionID == "0")
        #expect(grouping.stopIDs.count == 2)

        // Verify tripsWithStopTimes is non-empty and contains valid stop times
        #expect(!grouping.tripsWithStopTimes.isEmpty)
        let firstTrip = grouping.tripsWithStopTimes[0]
        #expect(!firstTrip.tripID.isEmpty)
        #expect(firstTrip.stopTimes.count == 2)
        #expect(firstTrip.stopTimes[0].stopID == "mot:stop:5997")
        #expect(firstTrip.stopTimes[1].stopID == "mot:stop:2899")
        #expect(firstTrip.stopTimes[0].departureTime > 0)
        #expect(firstTrip.stopTimes[1].arrivalTime >= firstTrip.stopTimes[0].departureTime)
    }

    @Test
    func testOutOfBoundsReturnsEmpty() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        // Far outside Israel (somewhere in the Atlantic Ocean)
        let stops = repo.stops(
            minLat: 0.0,
            maxLat: 1.0,
            minLon: 0.0,
            maxLon: 1.0,
            limit: 100
        )
        #expect(stops.isEmpty)
    }

    @Test
    func testAutocompleteSearchStops() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        // Numeric search
        let numericResults = repo.searchStops(query: "5997", limit: 5)
        #expect(!numericResults.isEmpty)
        #expect(numericResults.first?.code.rawValue == 5997)

        // Name search
        let textResults = repo.searchStops(query: "סילבר", limit: 10)
        #expect(!textResults.isEmpty)
        for s in textResults {
            #expect(s.name.he?.contains("סילבר") == true)
        }
    }
}
