//
//  IsraelViewportSnapshot.swift
//  IsraelMOT
//
//  Immutable snapshot models for ambient Israel transit map layers and vehicle feeds.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI
import OBAKitCore

/// Ambient real-time vehicle representation for SwiftUI maps, lists, and vehicle feeds.
public struct AmbientLiveVehicle: Identifiable, Sendable {
    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let routeColor: Color
    public let orientation: CLLocationDirection?
    public let routeType: Route.RouteType
    public let routeShortName: String
    public let headsign: String
    public let agencyName: String
    public let nextStopName: String?
    public let etaDate: Date?
    public let lastUpdateTime: Date?
    public let tripID: String
    public let routeID: RouteID
    public let serviceDate: Date
    public let vehicleID: String?
    public let tripConvertible: TripConvertible?
    public let arrivalDeparture: ArrivalDeparture?

    public var accessibilityDescription: String {
        let line = routeShortName.isEmpty ? "" : "קו \(routeShortName)"
        let dest = headsign.isEmpty ? "" : "אל \(headsign)"
        let op = agencyName.isEmpty ? "" : agencyName
        let parts = [line, dest, op].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    public init(
        id: String,
        coordinate: CLLocationCoordinate2D,
        routeColor: Color,
        orientation: CLLocationDirection?,
        routeType: Route.RouteType,
        routeShortName: String = "",
        headsign: String = "",
        agencyName: String = "",
        nextStopName: String? = nil,
        etaDate: Date? = nil,
        lastUpdateTime: Date? = nil,
        tripID: String = "",
        routeID: RouteID = "",
        serviceDate: Date = Date(),
        vehicleID: String? = nil,
        tripConvertible: TripConvertible? = nil,
        arrivalDeparture: ArrivalDeparture? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.routeColor = routeColor
        self.orientation = orientation
        self.routeType = routeType
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.agencyName = agencyName
        self.nextStopName = nextStopName
        self.etaDate = etaDate
        self.lastUpdateTime = lastUpdateTime
        self.tripID = tripID
        self.routeID = routeID
        self.serviceDate = serviceDate
        self.vehicleID = vehicleID
        self.tripConvertible = tripConvertible
        self.arrivalDeparture = arrivalDeparture
    }
}

/// Authoritative snapshot representing the state of visible Israeli routes and vehicles.
public struct IsraelViewportSnapshot: Sendable {
    public let timestamp: Date
    public let queryEnvelope: MKMapRect
    public let routes: [Route]
    public let vehicles: [AmbientLiveVehicle]

    public init(
        timestamp: Date = Date(),
        queryEnvelope: MKMapRect,
        routes: [Route],
        vehicles: [AmbientLiveVehicle]
    ) {
        self.timestamp = timestamp
        self.queryEnvelope = queryEnvelope
        self.routes = routes
        self.vehicles = vehicles
    }
}
