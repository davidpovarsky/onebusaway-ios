//
//  StopFullDataResponseDTO.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

nonisolated public struct StopFullDataResponseDTOServiceResponse: Codable, Sendable {
    public let data: StopFullDataResponseDTO?
    public let success: Bool
    public let message: String?
}

nonisolated public struct StopFullDataResponseDTO: Codable, Sendable {
    public let name: MultiLanguageDTO?
    public let cityName: String?
    public let streetName: String?
    public let streetNumber: String?
    public let stopcode: Int
    public let stopid: Int
    public let lat: Double
    public let lng: Double
    public let routesInStop: [RouteInStopDTO]?
    public let isCanceled: Bool?
    public let platformNumber: String?
}

nonisolated public struct RouteInStopDTO: Codable, Sendable {
    public let routeId: Int
    public let oppositeDirectionId: Int?
    public let routeName: String // e.g. "31"
    public let routeLongName: String?
    public let routeDesc: String? // e.g. "15031-1-0"
    public let agencyId: Int?
    public let agencyName: String?
    public let destinationName: String?
}

nonisolated public struct NearbyStopsResponseDTOServiceResponse: Codable, Sendable {
    public let data: [StopFullDataResponseDTO]?
    public let success: Bool
    public let message: String?
}
