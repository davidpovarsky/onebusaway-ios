//
//  IsraelRouteVehicleFeed.swift
//  IsraelMOT
//
//  Authoritative live vehicle feed for a specific Israeli transit route.
//

import Foundation
import CoreLocation
import SwiftUI
import OBAKitCore

public final class IsraelRouteVehicleFeed: Sendable {
    public static let shared = IsraelRouteVehicleFeed()

    public init() {}

    /// Fetches live real-time vehicles currently operating on the selected route.
    /// Gathers arrivals concurrently across key representative stops along the route's path.
    public func fetchVehicles(
        routeID: RouteID,
        routeShortName: String,
        stops: [Stop],
        apiService: RESTAPIService
    ) async -> [AmbientLiveVehicle] {
        guard !stops.isEmpty else { return [] }

        // Select up to 5 strategic stops distributed across the route (origin, quarter, midpoint, three-quarters, destination)
        let sampleStops: [Stop]
        if stops.count <= 5 {
            sampleStops = stops
        } else {
            let step = Double(stops.count - 1) / 4.0
            let indices = [0, Int(round(step)), Int(round(step * 2)), Int(round(step * 3)), stops.count - 1]
            let uniqueIndices = Array(Set(indices)).sorted()
            sampleStops = uniqueIndices.compactMap { $0 < stops.count ? stops[$0] : nil }
        }

        var liveVehicles: [AmbientLiveVehicle] = []
        var seenVehicleOrTripIDs = Set<String>()

        await withTaskGroup(of: [ArrivalDeparture]?.self) { group in
            for stop in sampleStops {
                group.addTask {
                    do {
                        let resp = try await apiService.getArrivalsAndDeparturesForStop(
                            id: stop.id,
                            minutesBefore: 0,
                            minutesAfter: 60
                        ).entry
                        return resp.arrivalsAndDepartures
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                guard let arrivals = result else { continue }
                for dep in arrivals {
                    // Match by route ID or route short name
                    let matchesRoute = dep.routeID == routeID ||
                        (dep.route?.shortName ?? dep.routeShortName) == routeShortName

                    guard matchesRoute,
                          let status = dep.tripStatus,
                          status.isRealTime,
                          let loc = (status.lastKnownLocation?.coordinate ?? status.position?.coordinate)
                    else { continue }

                    // Validate coordinates within Israel geographic boundaries
                    guard loc.latitude >= 29.0 && loc.latitude <= 33.5 &&
                          loc.longitude >= 34.0 && loc.longitude <= 36.0 else { continue }

                    let lastUpdate = status.lastUpdate ?? Date()
                    guard abs(Date().timeIntervalSince(lastUpdate)) <= 300 else { continue }

                    let dedupKey = status.vehicleID ?? dep.tripID
                    guard !dedupKey.isEmpty && seenVehicleOrTripIDs.insert(dedupKey).inserted else { continue }

                    let routeColor = dep.route?.color.map { Color(uiColor: $0) } ?? Color.green
                    let routeType = dep.route?.routeType ?? .bus
                    let headsign = dep.tripHeadsign ?? ""
                    let agency = dep.route?.agency.name ?? ""
                    let nextStop = status.nextStop?.name ?? status.closestStop?.name
                    let convertible = TripConvertible(arrivalDeparture: dep)

                    liveVehicles.append(
                        AmbientLiveVehicle(
                            id: dep.id,
                            coordinate: loc,
                            routeColor: routeColor,
                            orientation: status.orientation,
                            routeType: routeType,
                            routeShortName: routeShortName,
                            headsign: headsign,
                            agencyName: agency,
                            nextStopName: nextStop,
                            etaDate: dep.arrivalDepartureDate,
                            lastUpdateTime: lastUpdate,
                            tripID: dep.tripID,
                            routeID: routeID,
                            serviceDate: dep.serviceDate,
                            vehicleID: status.vehicleID,
                            tripConvertible: convertible,
                            arrivalDeparture: dep
                        )
                    )
                }
            }
        }

        return liveVehicles
    }
}
