//
//  NextStopDataDTO.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

nonisolated public struct GetNextStopDataRequestDTO: Codable, Sendable {
    public let routeDesc: String
    public let stopCodes: [Int]

    public init(routeDesc: String, stopCodes: [Int]) {
        self.routeDesc = routeDesc
        self.stopCodes = stopCodes
    }
}

nonisolated public struct GetNextStopDataResponseDTOServiceResponse: Codable, Sendable {
    public let data: [String: StopDataAtStopDTO?]?
    public let success: Bool
    public let message: String?
}

nonisolated public struct StopDataAtStopDTO: Codable, Sendable {
    public let routeId: Int?
    public let stopCode: Int?
    public let routeLocationAtStop: CoordinateDTO?
    public let stopTimes: [NextStopTimeDTO]?
    public let startTime: String?
    public let endTime: String?
    public let isFutureSearch: Bool?
}

nonisolated public struct NextStopTimeDTO: Codable, Sendable {
    public let tripIdToDate: Int?
    public let staticTripId: String?
    public let staticArrivalTime: String?
    public let arrivalTime: String?
    public let arrivalTimeString: String?
    public let minutesToArrival: Double?
    public let isRealTime: Bool?
    public let routeLocation: CoordinateDTO?
    public let isLate: Bool?
    public let stopOrder: Int?

    public init(
        tripIdToDate: Int? = nil,
        staticTripId: String? = nil,
        staticArrivalTime: String? = nil,
        arrivalTime: String? = nil,
        arrivalTimeString: String? = nil,
        minutesToArrival: Double? = nil,
        isRealTime: Bool? = nil,
        routeLocation: CoordinateDTO? = nil,
        isLate: Bool? = nil,
        stopOrder: Int? = nil
    ) {
        self.tripIdToDate = tripIdToDate
        self.staticTripId = staticTripId
        self.staticArrivalTime = staticArrivalTime
        self.arrivalTime = arrivalTime
        self.arrivalTimeString = arrivalTimeString
        self.minutesToArrival = minutesToArrival
        self.isRealTime = isRealTime
        self.routeLocation = routeLocation
        self.isLate = isLate
        self.stopOrder = stopOrder
    }
}
