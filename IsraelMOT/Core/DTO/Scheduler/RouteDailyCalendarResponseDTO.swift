//
//  RouteDailyCalendarResponseDTO.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Scheduler Integration)
//

import Foundation

nonisolated public struct RouteDailyCalendarResponseDTOServiceResponse: Codable, Sendable {
    public let data: RouteDailyCalendarContainerDTO?
    public let success: Bool
    public let message: String?

    public init(data: RouteDailyCalendarContainerDTO?, success: Bool, message: String? = nil) {
        self.data = data
        self.success = success
        self.message = message
    }
}

nonisolated public struct RouteDailyCalendarContainerDTO: Codable, Sendable {
    public let start: [DailyCalendarDepartureDTO]?
    public let end: [DailyCalendarDepartureDTO]?

    public init(start: [DailyCalendarDepartureDTO]?, end: [DailyCalendarDepartureDTO]? = nil) {
        self.start = start
        self.end = end
    }
}

nonisolated public struct DailyCalendarDepartureDTO: Codable, Sendable {
    public let tripId: String?
    public let stopid: Int?
    public let stopcode: Int?
    public let departureTime: String?
    public let departureTimeString: String?
    public let arrivalTime: String?
    public let arrivalTimeString: String?
    public let stopSequence: Int?
    public let routeDesc: String?
    public let routeId: Int?
    public let isRealTime: Bool?
    public let isLate: Bool?
    public let isCanceled: Bool?

    public init(
        tripId: String?,
        stopid: Int? = nil,
        stopcode: Int? = nil,
        departureTime: String? = nil,
        departureTimeString: String? = nil,
        arrivalTime: String? = nil,
        arrivalTimeString: String? = nil,
        stopSequence: Int? = nil,
        routeDesc: String? = nil,
        routeId: Int? = nil,
        isRealTime: Bool? = nil,
        isLate: Bool? = nil,
        isCanceled: Bool? = nil
    ) {
        self.tripId = tripId
        self.stopid = stopid
        self.stopcode = stopcode
        self.departureTime = departureTime
        self.departureTimeString = departureTimeString
        self.arrivalTime = arrivalTime
        self.arrivalTimeString = arrivalTimeString
        self.stopSequence = stopSequence
        self.routeDesc = routeDesc
        self.routeId = routeId
        self.isRealTime = isRealTime
        self.isLate = isLate
        self.isCanceled = isCanceled
    }
}
