//
//  TripPlanningRepository.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

nonisolated public struct TripPlanQuery: Sendable {
    public let origin: CLLocationCoordinate2D
    public let originName: String?
    public let destination: CLLocationCoordinate2D
    public let destinationName: String?
    public let departureTime: Date
    public let arriveBy: Bool
    public let wheelchairAccessible: Bool

    public init(
        origin: CLLocationCoordinate2D,
        originName: String? = nil,
        destination: CLLocationCoordinate2D,
        destinationName: String? = nil,
        departureTime: Date = Date(),
        arriveBy: Bool = false,
        wheelchairAccessible: Bool = false
    ) {
        self.origin = origin
        self.originName = originName
        self.destination = destination
        self.destinationName = destinationName
        self.departureTime = departureTime
        self.arriveBy = arriveBy
        self.wheelchairAccessible = wheelchairAccessible
    }
}

public protocol TripPlanningRepository: Sendable {
    func planTrip(query: TripPlanQuery) async throws -> [TransitRoute]
}
