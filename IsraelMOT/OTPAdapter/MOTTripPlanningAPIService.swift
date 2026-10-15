//
//  MOTTripPlanningAPIService.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

#if canImport(OTPKit)
import OTPKit
#endif

/// Adapter conforming to OTPKit's APIService protocol, dispatching requests
/// to the MOT route planner backend at api.bus.gov.il.
nonisolated public final class MOTTripPlanningAPIService: Sendable {
    private let client: MOTHTTPClient
    private let endpoints: MOTEndpoints
    public let baseURL: URL

    public init(
        baseURL: URL = URL(string: "https://api.bus.gov.il/prod/route-planner-prod/api/he/")!,
        client: MOTHTTPClient = MOTHTTPClient()
    ) {
        self.baseURL = baseURL
        self.endpoints = MOTEndpoints()
        self.client = client
    }
}

#if canImport(OTPKit)
nonisolated extension MOTTripPlanningAPIService: APIService {
    public func fetchPlan(_ request: TripPlanRequest) async throws -> OTPResponse {
        let originDTO = AddressResponseDTO(
            coordinates: CoordinateDTO(lat: request.origin.latitude, lng: request.origin.longitude)
        )
        let destinationDTO = AddressResponseDTO(
            coordinates: CoordinateDTO(lat: request.destination.latitude, lng: request.destination.longitude)
        )

        let isoDate = ISO8601DateFormatter().string(from: request.date)
        let optionsDTO = GetRoutesOptionsDTO(
            changes: true,
            departureTime: request.arriveBy ? nil : isoDate,
            arrivalTime: request.arriveBy ? isoDate : nil,
            transportations: nil,
            isAccessible: request.wheelchairAccessible
        )

        let requestedRoute = RequestedRouteDTO(
            origin: originDTO,
            destination: destinationDTO,
            options: optionsDTO
        )

        let returnedOptions = ReturnedRouteOptionsDTO(
            language: "he",
            isInterModal: true,
            isVehicleFirst: false,
            isFutureSearch: false,
            isDispatch: false
        )

        let requestDTO = GetRoutesRequestDTO(
            route: requestedRoute,
            returnedRouteOptions: returnedOptions,
            userIp: nil // Never spoof or guess user IP
        )

        let url = endpoints.getRoutesURL()

        do {
            let response: RouteResponseDTOListServiceResponse = try await client.post(url, body: requestDTO)
            guard response.success, let routes = response.data, !routes.isEmpty else {
                throw MOTTripPlanningError.noRoutesFound
            }
            return MOTItineraryMapper.map(
                from: response,
                requestOrigin: request.origin,
                requestDest: request.destination
            )
        } catch let error as MOTHTTPError {
            switch error {
            case .wafBlocked(let supportID):
                // Explicit non-negotiable blocker surface
                throw MOTTripPlanningError.wafBlocked(supportID: supportID)
            default:
                throw MOTTripPlanningError.serverError(error.localizedDescription)
            }
        }
    }
}
#endif
