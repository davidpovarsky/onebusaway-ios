//
//  RouteResponseDTO.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

public struct RouteResponseDTOListServiceResponse: Codable, Sendable {
    public let data: [RouteResponseDTO]?
    public let success: Bool
    public let message: String?
    public let duration: Double?
}

public struct RouteResponseDTO: Codable, Sendable {
    public let routeId: String
    public let sections: [SectionDTO]
    public let isFutureSearch: Bool?
    public let isRouteCanceled: Bool?
}

public struct SectionDTO: Codable, Sendable {
    public let type: String?
    public let departure: StationDataDTO?
    public let arrival: StationDataDTO?
    public let polyline: String?
    public let transport: TransportDTO?
    public let agency: AgencyDTO?
    public let travelSummary: TravelSummaryDTO?
    public let intermediateStops: [IntermediateStopDTO]?
}

public struct StationDataDTO: Codable, Sendable {
    public let time: String?
    public let hourTimeString: String?
    public let place: PlaceDTO?
    public let nextStopsTimes: [RouteStopAtStop]?
}

public struct PlaceDTO: Codable, Sendable {
    public let name: String?
    public let type: String?
    public let location: CoordinateDTO?
    public let code: String?
    public let platformNumber: String?
}

public struct TransportDTO: Codable, Sendable {
    public let mode: String?
    public let name: String?
    public let shortName: String?
    public let longName: String?
    public let headsign: String?
    public let color: String?
    public let routeId: Int?
}

public struct AgencyDTO: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let website: String?
}

public struct TravelSummaryDTO: Codable, Sendable {
    public let duration: Int?
    public let length: Int?
    public let price: [PriceDTO]?
}

public struct PriceDTO: Codable, Sendable {
    public let profileId: Int?
    public let profileName: MultiLanguageDTO?
    public let singleRidePrice: Double?
}

public struct IntermediateStopDTO: Codable, Sendable {
    public let departure: StationDataDTO?
}

public struct MultiLanguageDTO: Codable, Sendable {
    public let he: String?
    public let en: String?
    public let ar: String?
}

public struct RouteStopAtStop: Codable, Sendable {
    public let tripIdToDate: Int?
    public let staticTripId: String?
    public let arrivalTime: String?
    public let minutesToArrival: Double?
    public let isRealTime: Bool?
    public let routeLocation: CoordinateDTO?
}
