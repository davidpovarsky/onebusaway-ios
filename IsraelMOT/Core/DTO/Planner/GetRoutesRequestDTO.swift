//
//  GetRoutesRequestDTO.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

nonisolated public struct GetRoutesRequestDTO: Codable, Sendable {
    public let route: RequestedRouteDTO
    public let returnedRouteOptions: ReturnedRouteOptionsDTO
    public let userIp: String?

    public init(
        route: RequestedRouteDTO,
        returnedRouteOptions: ReturnedRouteOptionsDTO,
        userIp: String? = nil
    ) {
        self.route = route
        self.returnedRouteOptions = returnedRouteOptions
        self.userIp = userIp
    }
}

nonisolated public struct RequestedRouteDTO: Codable, Sendable {
    public let origin: AddressResponseDTO
    public let destination: AddressResponseDTO
    public let options: GetRoutesOptionsDTO?

    public init(
        origin: AddressResponseDTO,
        destination: AddressResponseDTO,
        options: GetRoutesOptionsDTO? = nil
    ) {
        self.origin = origin
        self.destination = destination
        self.options = options
    }
}

nonisolated public struct AddressResponseDTO: Codable, Sendable {
    public let addressDetails: AddressLocationDTO?
    public let coordinates: CoordinateDTO?

    public init(addressDetails: AddressLocationDTO? = nil, coordinates: CoordinateDTO? = nil) {
        self.addressDetails = addressDetails
        self.coordinates = coordinates
    }
}

nonisolated public struct ReturnedRouteOptionsDTO: Codable, Sendable {
    public let language: String?
    public let isInterModal: Bool?
    public let isVehicleFirst: Bool?
    public let isFutureSearch: Bool?
    public let isDispatch: Bool?

    public init(
        language: String? = "he",
        isInterModal: Bool? = true,
        isVehicleFirst: Bool? = false,
        isFutureSearch: Bool? = false,
        isDispatch: Bool? = false
    ) {
        self.language = language
        self.isInterModal = isInterModal
        self.isVehicleFirst = isVehicleFirst
        self.isFutureSearch = isFutureSearch
        self.isDispatch = isDispatch
    }
}

nonisolated public struct GetRoutesOptionsDTO: Codable, Sendable {
    public let changes: Bool?
    public let departureTime: String?
    public let arrivalTime: String?
    public let transportations: [String]?
    public let isAccessible: Bool?

    public init(
        changes: Bool? = true,
        departureTime: String? = nil,
        arrivalTime: String? = nil,
        transportations: [String]? = nil,
        isAccessible: Bool? = nil
    ) {
        self.changes = changes
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.transportations = transportations
        self.isAccessible = isAccessible
    }
}
