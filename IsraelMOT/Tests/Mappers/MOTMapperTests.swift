//
//  MOTMapperTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct MOTMapperTests {

    @Test
    func testMOTStopMapperFromFullData() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "stop_5997_fulldata.json",
            as: StopFullDataResponseDTOServiceResponse.self
        )
        guard let dto = response.data else {
            Issue.record("Expected stop DTO")
            return
        }

        let stop = MOTStopMapper.map(from: dto)

        #expect(stop.code.rawValue == 5997)
        #expect(stop.internalID?.rawValue == 11622)
        #expect(stop.cityName == "ירושלים")
        #expect(stop.name.he == "סילבר/שכטמן")
        #expect(abs(stop.location.latitude - 31.815188) < 0.0001)
        #expect(abs(stop.location.longitude - 35.203022) < 0.0001)
        #expect(!stop.routes.isEmpty)

        let route31 = stop.routes.first { $0.lineName == "31" }
        #expect(route31 != nil)
    }

    @Test
    func testMOTStopMapperFromAutoComplete() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "search_locations_jerusalem.json",
            as: LocationAutoCompleteDTOServiceResponse.self
        )
        guard let firstDTO = response.data?.first else {
            Issue.record("Expected autocomplete DTO")
            return
        }

        let stop = MOTStopMapper.map(from: firstDTO)
        #expect(stop != nil)
        #expect(stop?.name.he == firstDTO.title)
    }

    @Test
    func testMOTRouteMapper() throws {
        let routeResponse = try MOTTestFixtures.decode(
            fixture: "route_33285_fulldata.json",
            as: RouteFullDataResponseDTOServiceResponse.self
        )
        let stopsResponse = try MOTTestFixtures.decode(
            fixture: "route_33285_stops.json",
            as: RouteStopsResponseDTOServiceResponse.self
        )

        guard let routeDTO = routeResponse.data else {
            Issue.record("Expected route DTO")
            return
        }

        let route = MOTRouteMapper.map(
            routeDTO: routeDTO,
            stopsDTO: stopsResponse.data?.route
        )

        #expect(route.routeID.rawValue == 33285)
        #expect(route.agencyID.rawValue == 16)
        #expect(route.agencyName == "סופרבוס")
        #expect(!route.stops.isEmpty)
    }

    @Test
    func testMOTArrivalsMapperWithRealTime() {
        let routeInStop = RouteInStopDTO(
            routeId: 101,
            oppositeDirectionId: nil,
            routeName: "31",
            routeLongName: "גילה - תלפיות",
            routeDesc: "15031-1-0",
            agencyId: 16,
            agencyName: "סופרבוס",
            destinationName: "גילה"
        )

        let liveUpdate = NextStopTimeDTO(
            staticArrivalTime: "2026-10-18T14:25:00",
            arrivalTime: "2026-10-18T14:30:00",
            minutesToArrival: 5.0,
            isRealTime: true,
            routeLocation: CoordinateDTO(lat: 31.78, lng: 35.20)
        )

        let arrivals = MOTArrivalsMapper.map(
            routesInStop: [routeInStop],
            realTimeUpdates: [liveUpdate]
        )

        #expect(arrivals.count == 1)
        let arr = arrivals[0]
        #expect(arr.lineName == "31")
        #expect(arr.destination == "גילה")
        #expect(arr.isRealTime == true)
        #expect(arr.minutesToArrival == 5)
        #expect(arr.vehicleLocation != nil)
        #expect(arr.estimatedTime != nil)
    }

    @Test
    func testMOTArrivalsMapperTruthfulNoPlaceholderWhenEmpty() {
        let routeInStop = RouteInStopDTO(
            routeId: 102,
            oppositeDirectionId: nil,
            routeName: "15",
            routeLongName: "תלפיות",
            routeDesc: "15015-1-0",
            agencyId: 3,
            agencyName: "אגד",
            destinationName: "תלפיות"
        )

        // No real-time updates or schedule records provided -> MUST NOT invent arrivals (no now+600)
        let arrivals = MOTArrivalsMapper.map(
            routesInStop: [routeInStop],
            realTimeUpdates: []
        )

        #expect(arrivals.isEmpty)
    }

    @Test
    func testMOTArrivalsMapperScheduledWithoutRealTime() {
        let routeInStop = RouteInStopDTO(
            routeId: 102,
            oppositeDirectionId: nil,
            routeName: "15",
            routeLongName: "תלפיות",
            routeDesc: "15015-1-0",
            agencyId: 3,
            agencyName: "אגד",
            destinationName: "תלפיות"
        )

        let scheduledUpdate = NextStopTimeDTO(
            staticArrivalTime: "2026-10-18T10:15:00",
            arrivalTime: "2026-10-18T10:15:00",
            minutesToArrival: nil,
            isRealTime: false,
            routeLocation: nil
        )

        let arrivals = MOTArrivalsMapper.map(
            routesInStop: [routeInStop],
            realTimeUpdates: [scheduledUpdate]
        )

        #expect(arrivals.count == 1)
        let arr = arrivals[0]
        #expect(arr.lineName == "15")
        #expect(arr.isRealTime == false)
        #expect(arr.minutesToArrival == nil)
        #expect(arr.vehicleLocation == nil)
        #expect(arr.estimatedTime == nil)
    }

    @Test
    func testPolylineEncodeDecodeRoundtrip() {
        let originalCoordinates = [
            CLLocationCoordinate2D(latitude: 31.78913, longitude: 35.20465),
            CLLocationCoordinate2D(latitude: 31.79000, longitude: 35.20500),
            CLLocationCoordinate2D(latitude: 31.79150, longitude: 35.20620)
        ]

        let encoded = MOTLegGeometryMapper.encodePolyline(originalCoordinates)
        #expect(!encoded.isEmpty)

        let decoded = MOTLegGeometryMapper.decodePolyline(encoded)
        #expect(decoded.count == originalCoordinates.count)

        for (orig, dec) in zip(originalCoordinates, decoded) {
            #expect(abs(orig.latitude - dec.latitude) < 0.0001)
            #expect(abs(orig.longitude - dec.longitude) < 0.0001)
        }
    }

    @Test
    func testEmptyPolylineHandling() {
        let decoded = MOTLegGeometryMapper.decodePolyline("")
        #expect(decoded.isEmpty)

        let encoded = MOTLegGeometryMapper.encodePolyline([])
        #expect(encoded.isEmpty)
    }
}
