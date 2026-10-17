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

    private enum CodingKeys: String, CodingKey {
        case route
        case returnedRouteOptions
        case userIp
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(route, forKey: .route)
        try container.encode(returnedRouteOptions, forKey: .returnedRouteOptions)
        try container.encodeIfPresent(userIp, forKey: .userIp)
    }
}

nonisolated public struct RequestedRouteDTO: Codable, Sendable {
    public let origin: AddressResponseDTO
    public let destination: AddressResponseDTO
    public let stop: String?
    public let options: GetRoutesOptionsDTO

    public init(
        origin: AddressResponseDTO,
        destination: AddressResponseDTO,
        stop: String? = nil,
        options: GetRoutesOptionsDTO
    ) {
        self.origin = origin
        self.destination = destination
        self.stop = stop
        self.options = options
    }

    private enum CodingKeys: String, CodingKey {
        case origin
        case destination
        case stop
        case options
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin, forKey: .origin)
        try container.encode(destination, forKey: .destination)
        if let stop = stop {
            try container.encode(stop, forKey: .stop)
        } else {
            try container.encodeNil(forKey: .stop)
        }
        try container.encode(options, forKey: .options)
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
    public let language: String
    public let isFutureSearch: Bool

    public init(
        language: String = "he",
        isFutureSearch: Bool = true
    ) {
        self.language = language
        self.isFutureSearch = isFutureSearch
    }
}

nonisolated public struct GetRoutesOptionsDTO: Codable, Sendable {
    public let isAccessible: Bool
    public let changes: Bool
    public let transportations: [String]
    public let sortBy: Int
    public let maxTravelTime: Int
    public let maxWalkTime: Int
    public let transportationsForInitialUse: [String]
    public let arrivalTime: String?
    public let departureTime: String?

    public init(
        isAccessible: Bool = false,
        changes: Bool = true,
        transportations: [String] = ["bus", "privateBus", "lightRail", "regionalTrain"],
        sortBy: Int = 0,
        maxTravelTime: Int = 600,
        maxWalkTime: Int = 120,
        transportationsForInitialUse: [String] = ["bus", "carmelit", "lightRail", "publicTaxi", "rahbalit", "train"],
        arrivalTime: String? = nil,
        departureTime: String? = nil
    ) {
        self.isAccessible = isAccessible
        self.changes = changes
        self.transportations = transportations
        self.sortBy = sortBy
        self.maxTravelTime = maxTravelTime
        self.maxWalkTime = maxWalkTime
        self.transportationsForInitialUse = transportationsForInitialUse
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
    }

    private enum CodingKeys: String, CodingKey {
        case isAccessible
        case changes
        case transportations
        case sortBy
        case maxTravelTime
        case maxWalkTime
        case transportationsForInitialUse
        case arrivalTime
        case departureTime
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAccessible, forKey: .isAccessible)
        try container.encode(changes, forKey: .changes)
        try container.encode(transportations, forKey: .transportations)
        try container.encode(sortBy, forKey: .sortBy)
        try container.encode(maxTravelTime, forKey: .maxTravelTime)
        try container.encode(maxWalkTime, forKey: .maxWalkTime)
        try container.encode(transportationsForInitialUse, forKey: .transportationsForInitialUse)

        if let arrivalTime = arrivalTime {
            try container.encode(arrivalTime, forKey: .arrivalTime)
        } else {
            try container.encodeNil(forKey: .arrivalTime)
        }

        if let departureTime = departureTime {
            try container.encode(departureTime, forKey: .departureTime)
        } else {
            try container.encodeNil(forKey: .departureTime)
        }
    }
}
