//
//  RouteFullDataResponseDTO.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

nonisolated public struct RouteFullDataResponseDTOServiceResponse: Codable, Sendable {
    public let data: RouteFullDataResponseDTO?
    public let success: Bool
    public let message: String?
}

nonisolated public struct RouteFullDataResponseDTO: Codable, Sendable {
    public let routeId: Int
    public let oppositeDirectionId: Int?
    public let routeName: String
    public let routeLongName: String?
    public let routeDesc: String?
    public let agencyId: Int
    public let agencyName: String
    public let cityName: String?
    public let polyline: String?
    public let stops: [StopOnRouteDTO]?
}

nonisolated public struct RouteStopsResponseDTOServiceResponse: Codable, Sendable {
    public let data: RouteStopsContainerDTO?
    public let success: Bool
    public let message: String?
}

nonisolated public struct RouteStopsContainerDTO: Codable, Sendable {
    public let route: RouteWithStopsDTO?
}

nonisolated public struct RouteWithStopsDTO: Codable, Sendable {
    public let agencyId: Int?
    public let routeId: Int
    public let routeName: String
    public let routeLongName: String?
    public let cityName: String?
    public let stops: [StopOnRouteDTO]?
}

nonisolated public struct StopOnRouteDTO: Codable, Sendable {
    public let stopid: Int
    public let stopcode: Int
    public let name: MultiLanguageDTO?
    public let desc: String?
    public let lat: Double?
    public let lng: Double?
    public let stopSequence: Int?
    public let isPickup: Bool?
    public let isDropoff: Bool?
    public let platformNumber: String?
    public let nextStopsTimes: [NextStopTimeDTO]?
}
