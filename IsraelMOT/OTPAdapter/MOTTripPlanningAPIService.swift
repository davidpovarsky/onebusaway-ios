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
        baseURL: URL = URL(string: "https://api.bus.gov.il/prod/route-planner-prod/api/")!,
        client: MOTHTTPClient = MOTHTTPClient()
    ) {
        self.baseURL = baseURL
        self.endpoints = MOTEndpoints(plannerBase: baseURL)
        self.client = client
    }
}

#if canImport(OTPKit)
nonisolated extension MOTTripPlanningAPIService: APIService {
    public func fetchPlan(_ request: TripPlanRequest) async throws -> OTPResponse {
        let originDTO = AddressResponseDTO(
            addressDetails: AddressLocationDTO(label: "Origin"),
            coordinates: CoordinateDTO(lat: request.origin.latitude, lng: request.origin.longitude)
        )
        let destinationDTO = AddressResponseDTO(
            addressDetails: AddressLocationDTO(label: "Destination"),
            coordinates: CoordinateDTO(lat: request.destination.latitude, lng: request.destination.longitude)
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        let isoDate = formatter.string(from: request.date)

        let isFuture = request.date > Date()

        let optionsDTO = GetRoutesOptionsDTO(
            isAccessible: request.wheelchairAccessible,
            changes: true,
            transportations: ["bus", "privateBus", "lightRail", "regionalTrain"],
            sortBy: 0,
            maxTravelTime: 600,
            maxWalkTime: 120,
            transportationsForInitialUse: ["bus", "carmelit", "lightRail", "publicTaxi", "rahbalit", "train"],
            arrivalTime: request.arriveBy ? isoDate : nil,
            departureTime: request.arriveBy ? nil : isoDate
        )

        let requestedRoute = RequestedRouteDTO(
            origin: originDTO,
            destination: destinationDTO,
            stop: nil,
            options: optionsDTO
        )

        let returnedOptions = ReturnedRouteOptionsDTO(
            language: "he",
            isFutureSearch: isFuture
        )

        let requestDTO = GetRoutesRequestDTO(
            route: requestedRoute,
            returnedRouteOptions: returnedOptions,
            userIp: nil
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
                throw MOTTripPlanningError.wafBlocked(supportID: supportID)
            default:
                throw MOTTripPlanningError.serverError(error.localizedDescription)
            }
        }
    }
}
#endif
