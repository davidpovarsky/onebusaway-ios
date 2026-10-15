//
//  MOTDTODecodingTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import Testing
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct MOTDTODecodingTests {

    @Test
    func testDecodeStopFullDataFixture() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "stop_5997_fulldata.json",
            as: StopFullDataResponseDTOServiceResponse.self
        )

        #expect(response.success == true)
        guard let stop = response.data else {
            Issue.record("Expected data to contain stop")
            return
        }

        #expect(stop.stopcode == 5997)
        #expect(stop.stopid == 11622)
        #expect(stop.cityName == "ירושלים")
        #expect(stop.name?.he == "שרי ישראל/חשמונאים")
        #expect(stop.lat == 31.78913)
        #expect(stop.lng == 35.204648)

        guard let routes = stop.routesInStop else {
            Issue.record("Expected routesInStop to be present")
            return
        }
        #expect(!routes.isEmpty)
        #expect(routes.contains { $0.routeName == "15" })
        #expect(routes.contains { $0.routeName == "68" })
    }

    @Test
    func testDecodeRouteFullDataFixture() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "route_33285_fulldata.json",
            as: RouteFullDataResponseDTOServiceResponse.self
        )

        #expect(response.success == true)
        guard let route = response.data else {
            Issue.record("Expected data to contain route")
            return
        }

        #expect(route.routeId == 33285)
        #expect(!route.routeName.isEmpty)
        #expect(route.agencyId == 16)
        #expect(route.agencyName == "סופרבוס")
    }

    @Test
    func testDecodeRouteStopsFixture() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "route_33285_stops.json",
            as: RouteStopsResponseDTOServiceResponse.self
        )

        #expect(response.success == true)
        guard let routeWithStops = response.data?.route else {
            Issue.record("Expected route with stops container")
            return
        }

        #expect(routeWithStops.routeId == 33285)
        guard let stops = routeWithStops.stops else {
            Issue.record("Expected stops list in route")
            return
        }
        #expect(!stops.isEmpty)
        #expect(stops.first?.stopcode != nil)
    }

    @Test
    func testDecodeLocationAutoCompleteFixture() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "search_locations_jerusalem.json",
            as: LocationAutoCompleteDTOServiceResponse.self
        )

        #expect(response.success == true)
        guard let results = response.data else {
            Issue.record("Expected location search results")
            return
        }
        #expect(!results.isEmpty)
        let first = results[0]
        #expect(!first.title.isEmpty)
        #expect(first.coordinates != nil)
    }

    @Test
    func testDecodeRoutePlanningFixture() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "route_planning_success_fixture.json",
            as: RouteResponseDTOListServiceResponse.self
        )

        #expect(response.success == true)
        guard let routes = response.data else {
            Issue.record("Expected route planning results")
            return
        }
        #expect(!routes.isEmpty)
        let firstRoute = routes[0]
        #expect(!firstRoute.sections.isEmpty)

        // Verify sections contain departure/arrival and transport info
        let transitSection = firstRoute.sections.first { $0.transport != nil }
        #expect(transitSection != nil)
        #expect(transitSection?.transport?.mode != nil)
    }

    @Test
    func testMalformedJSONHandling() {
        let invalidData = "{ bad json ".data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            try decoder.decode(StopFullDataResponseDTOServiceResponse.self, from: invalidData)
        }
    }
}
