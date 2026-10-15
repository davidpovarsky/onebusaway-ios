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
    public let data: [NextStopRealTimeDTO]?
    public let success: Bool
    public let message: String?
}

nonisolated public struct NextStopRealTimeDTO: Codable, Sendable {
    public let stopCode: Int
    public let routeDesc: String?
    public let minutesToArrival: Int?
    public let arrivalTime: String?
    public let isRealTime: Bool?
    public let vehicleLocation: CoordinateDTO?
}
