//
//  TransitRepository.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

/// Protocol defining the repository interface for transit stops, routes, and arrivals.
public protocol TransitRepository: Sendable {
    func searchLocations(query: String) async throws -> [TransitStop]
    func nearbyStops(coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [TransitStop]
    func stopDetails(stopCode: MOTStopCode) async throws -> TransitStop
    func routeDetails(routeID: MOTRouteID) async throws -> TransitRoute
    func stopArrivals(stopCode: MOTStopCode) async throws -> [TransitArrival]
}
