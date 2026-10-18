//
//  MOTTripPlanningTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore
#if canImport(OTPKit)
@testable import OTPKit
#endif

@Suite(.serialized)
struct MOTTripPlanningTests {

    #if canImport(OTPKit)
    @Test
    func testMapItineraryFromFixture() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "route_planning_success_fixture.json",
            as: RouteResponseDTOListServiceResponse.self
        )

        let origin = CLLocationCoordinate2D(latitude: 31.78913, longitude: 35.20465)
        let destination = CLLocationCoordinate2D(latitude: 31.77800, longitude: 35.21000)

        let otpResponse = MOTItineraryMapper.map(
            from: response,
            requestOrigin: origin,
            requestDest: destination
        )

        #expect(otpResponse.plan != nil)
        guard let itineraries = otpResponse.plan?.itineraries else {
            Issue.record("Expected itineraries in plan")
            return
        }

        #expect(!itineraries.isEmpty)
        let firstItinerary = itineraries[0]
        #expect(!firstItinerary.legs.isEmpty)

        // Validate first leg
        let leg = firstItinerary.legs[0]
        #expect(leg.from != nil)
        #expect(leg.to != nil)
        #expect(leg.duration > 0)
    }

    @Test
    func testMapLiveScriptableGetRoutesFixture() throws {
        let response = try MOTTestFixtures.decode(
            fixture: "ministry_getroutes_live.json",
            as: RouteResponseDTOListServiceResponse.self
        )

        #expect(response.success == true)
        guard let routes = response.data else {
            Issue.record("Expected routes in data")
            return
        }

        #expect(routes.count == 6)

        let allSections = routes.flatMap { $0.sections }
        #expect(allSections.count == 24)

        let pedestrianSections = allSections.filter { MOTSectionModeMapper.isWalkSection($0) }
        #expect(pedestrianSections.count == 14)

        let transitSections = allSections.filter { !MOTSectionModeMapper.isWalkSection($0) }
        #expect(transitSections.count == 10)

        let totalActions = allSections.compactMap { $0.actions }.flatMap { $0 }.count
        #expect(totalActions == 87)

        var totalVertices = 0
        for section in allSections {
            if let poly = section.polyline {
                let coords = (try? HEREFlexiblePolylineDecoder.decode(poly)) ?? []
                totalVertices += coords.count
            }
        }
        #expect(totalVertices == 1724)

        let nextStopsRealTimeFlags = allSections.compactMap { $0.departure?.nextStopsTimes }.flatMap { $0 }.compactMap { $0.isRealTime }
        #expect(!nextStopsRealTimeFlags.isEmpty)
        for flag in nextStopsRealTimeFlags {
            #expect(flag == false)
        }

        let origin = CLLocationCoordinate2D(latitude: 31.815188, longitude: 35.203022)
        let destination = CLLocationCoordinate2D(latitude: 31.787547, longitude: 35.202639)

        let otpResponse = MOTItineraryMapper.map(
            from: response,
            requestOrigin: origin,
            requestDest: destination
        )

        #expect(otpResponse.plan != nil)
        guard let itineraries = otpResponse.plan?.itineraries else {
            Issue.record("Expected itineraries in plan")
            return
        }

        #expect(itineraries.count == 6)

        // Route 1 (index 0): direct line 71 -> 0 transfers
        let directItinerary = itineraries[0]
        #expect(directItinerary.transfers == 0)
        #expect(directItinerary.legs.count == 3) // walk -> transit -> walk
        #expect(directItinerary.legs[0].mode == "WALK")
        #expect(directItinerary.legs[0].transitLeg == false)
        #expect(directItinerary.legs[1].mode == "BUS")
        #expect(directItinerary.legs[1].transitLeg == true)
        #expect(directItinerary.legs[2].mode == "WALK")
        #expect(directItinerary.legs[0].steps?.count == 9)

        // Route 3 (index 2): multi-leg transit 31 -> 78 -> 34 -> 2 transfers
        let multiTransferItinerary = itineraries[2]
        #expect(multiTransferItinerary.transfers == 2)
        #expect(multiTransferItinerary.legs.count == 6)
    }
    #endif

    @Test
    func testWafBlockedErrorFormatting() {
        let supportID = "12345-67890-abcdef"
        let error = MOTTripPlanningError.wafBlocked(supportID: supportID)

        let desc = error.errorDescription ?? ""
        #expect(desc.contains(supportID))
        #expect(desc.contains("חומת אש F5"))
    }

    @Test
    func testNoRoutesFoundErrorFormatting() {
        let error = MOTTripPlanningError.noRoutesFound
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("לא נמצאו מסלולים"))
    }

    @Test
    func testServerErrorFormatting() {
        let error = MOTTripPlanningError.serverError("HTTP 503 Service Unavailable")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("503"))
    }

    @Test
    func testOpenAPIRequestPayloadSerialization() throws {
        let origin = AddressResponseDTO(
            coordinates: CoordinateDTO(lat: 31.78913, lng: 35.20465)
        )
        let destination = AddressResponseDTO(
            coordinates: CoordinateDTO(lat: 31.77800, lng: 35.21000)
        )
        let options = GetRoutesOptionsDTO(
            isAccessible: false,
            changes: true,
            departureTime: "2026-10-15T12:00:00Z"
        )
        let route = RequestedRouteDTO(
            origin: origin,
            destination: destination,
            options: options
        )
        let returnedOptions = ReturnedRouteOptionsDTO(
            language: "he",
            isFutureSearch: false
        )
        let requestDTO = GetRoutesRequestDTO(
            route: route,
            returnedRouteOptions: returnedOptions,
            userIp: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(requestDTO)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let json = jsonObject as? [String: Any],
              let routeDict = json["route"] as? [String: Any] else {
            Issue.record("Expected JSON dictionary")
            return
        }

        #expect(json["route"] != nil)
        #expect(json["returnedRouteOptions"] != nil)
        #expect(routeDict["origin"] != nil)
        #expect(routeDict["destination"] != nil)
        #expect(routeDict["options"] != nil)
    }

    @Test
    func testF5WafRejectionDetection() {
        let wafHtml = """
        <html><head><title>Request Rejected</title></head><body>
        The requested URL was rejected. Please consult with your administrator.<br><br>
        Your support ID is 18273645-9876-4321-abcd-ef0123456789<br><br>
        <a href='javascript:history.back();'>[Go Back]</a></body></html>
        """

        let supportID = "18273645-9876-4321-abcd-ef0123456789"
        #expect(wafHtml.contains("Your support ID is \(supportID)"))

        let error = MOTTripPlanningError.wafBlocked(supportID: supportID)
        #expect(error.errorDescription?.contains(supportID) == true)
        #expect(error.errorDescription?.contains("חומת אש F5") == true)
    }

    @Test
    func testTimezoneFormattingAsiaJerusalem() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Jerusalem")!

        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 18
        components.hour = 16
        components.minute = 10
        components.second = 0

        guard let targetDate = cal.date(from: components) else {
            Issue.record("Failed to create target test date")
            return
        }

        let formatted = MOTTripPlanningAPIService.formatRequestDate(targetDate)
        // Strictly wall-clock Asia/Jerusalem time without trailing 'Z'
        #expect(formatted == "2026-10-18T16:10:00")
        #expect(!formatted.hasSuffix("Z"))
    }
}
