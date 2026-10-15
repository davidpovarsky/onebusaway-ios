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
}
