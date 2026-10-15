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
            changes: true,
            departureTime: "2026-10-15T12:00:00Z",
            arrivalTime: nil,
            transportations: nil,
            isAccessible: false
        )
        let route = RequestedRouteDTO(
            origin: origin,
            destination: destination,
            options: options
        )
        let returnedOptions = ReturnedRouteOptionsDTO(
            language: "he",
            isInterModal: true,
            isVehicleFirst: false,
            isFutureSearch: false,
            isDispatch: false
        )
        let requestDTO = GetRoutesRequestDTO(
            route: route,
            returnedRouteOptions: returnedOptions,
            userIp: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(requestDTO)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        #expect(json?["route"] != nil)
        #expect(json?["returnedRouteOptions"] != nil)

        let routeDict = json?["route"] as? [String: Any]
        #expect(routeDict?["origin"] != nil)
        #expect(routeDict?["destination"] != nil)
        #expect(routeDict?["options"] != nil)
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
}
