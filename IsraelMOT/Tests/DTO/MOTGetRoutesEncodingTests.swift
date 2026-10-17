//
//  MOTGetRoutesEncodingTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import Testing
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct MOTGetRoutesEncodingTests {

    @Test
    func testGetRoutesFullPayloadStructureMatchesProvenContract() throws {
        let origin = AddressResponseDTO(
            addressDetails: AddressLocationDTO(label: "Origin"),
            coordinates: CoordinateDTO(lat: 31.816248, lng: 35.203367)
        )
        let destination = AddressResponseDTO(
            addressDetails: AddressLocationDTO(label: "Destination"),
            coordinates: CoordinateDTO(lat: 31.755010, lng: 35.219980)
        )

        let departureUTC = "2026-10-18T06:30:00.000Z"
        let options = GetRoutesOptionsDTO(
            isAccessible: false,
            changes: true,
            transportations: ["bus", "privateBus", "lightRail", "regionalTrain"],
            sortBy: 0,
            maxTravelTime: 600,
            maxWalkTime: 120,
            transportationsForInitialUse: ["bus", "carmelit", "lightRail", "publicTaxi", "rahbalit", "train"],
            arrivalTime: nil,
            departureTime: departureUTC
        )

        let requestedRoute = RequestedRouteDTO(
            origin: origin,
            destination: destination,
            stop: nil,
            options: options
        )

        let returnedOptions = ReturnedRouteOptionsDTO(
            language: "he",
            isFutureSearch: true
        )

        let requestDTO = GetRoutesRequestDTO(
            route: requestedRoute,
            returnedRouteOptions: returnedOptions,
            userIp: nil
        )

        let data = try JSONEncoder().encode(requestDTO)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        let routeDict = json?["route"] as? [String: Any]
        #expect(routeDict != nil)

        // 1. stop must be explicitly null, not missing
        #expect(routeDict?.keys.contains("stop") == true)
        #expect(routeDict?["stop"] is NSNull)

        // 2. options structure
        let optionsDict = routeDict?["options"] as? [String: Any]
        #expect(optionsDict != nil)
        #expect(optionsDict?["isAccessible"] as? Bool == false)
        #expect(optionsDict?["changes"] as? Bool == true)
        #expect(optionsDict?["sortBy"] as? Int == 0)
        #expect(optionsDict?["maxTravelTime"] as? Int == 600)
        #expect(optionsDict?["maxWalkTime"] as? Int == 120)

        // arrivalTime must be explicitly null when departureTime is present
        #expect(optionsDict?.keys.contains("arrivalTime") == true)
        #expect(optionsDict?["arrivalTime"] is NSNull)
        #expect(optionsDict?["departureTime"] as? String == departureUTC)

        let transportations = optionsDict?["transportations"] as? [String]
        #expect(transportations == ["bus", "privateBus", "lightRail", "regionalTrain"])

        let initialTransports = optionsDict?["transportationsForInitialUse"] as? [String]
        #expect(initialTransports == ["bus", "carmelit", "lightRail", "publicTaxi", "rahbalit", "train"])

        // 3. returnedRouteOptions
        let returnedDict = json?["returnedRouteOptions"] as? [String: Any]
        #expect(returnedDict != nil)
        #expect(returnedDict?["language"] as? String == "he")
        #expect(returnedDict?["isFutureSearch"] as? Bool == true)
    }

    @Test
    func testArriveByEncodesArrivalTimeAndNullDeparture() throws {
        let origin = AddressResponseDTO(coordinates: CoordinateDTO(lat: 31.8, lng: 35.2))
        let destination = AddressResponseDTO(coordinates: CoordinateDTO(lat: 31.7, lng: 35.2))

        let arrivalUTC = "2026-10-18T09:30:00.000Z"
        let options = GetRoutesOptionsDTO(
            arrivalTime: arrivalUTC,
            departureTime: nil
        )

        let requestedRoute = RequestedRouteDTO(
            origin: origin,
            destination: destination,
            stop: nil,
            options: options
        )

        let requestDTO = GetRoutesRequestDTO(
            route: requestedRoute,
            returnedRouteOptions: ReturnedRouteOptionsDTO(language: "he", isFutureSearch: true)
        )

        let data = try JSONEncoder().encode(requestDTO)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let routeDict = json?["route"] as? [String: Any]
        let optionsDict = routeDict?["options"] as? [String: Any]

        #expect(optionsDict?["arrivalTime"] as? String == arrivalUTC)
        #expect(optionsDict?.keys.contains("departureTime") == true)
        #expect(optionsDict?["departureTime"] is NSNull)
    }
}
