//
//  MOTArrivalsMapper.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

nonisolated public enum MOTArrivalsMapper {
    public static func map(
        routesInStop: [RouteInStopDTO],
        realTimeUpdates: [NextStopRealTimeDTO] = []
    ) -> [TransitArrival] {
        let updatesByRouteDesc = Dictionary(grouping: realTimeUpdates, by: { $0.routeDesc ?? "" })

        var arrivals: [TransitArrival] = []
        let now = Date()

        for route in routesInStop {
            let routeID = MOTRouteID(rawValue: route.routeId)
            let routeDesc = route.routeDesc ?? ""
            let updates = updatesByRouteDesc[routeDesc] ?? []

            if let liveUpdate = updates.first {
                let mins = liveUpdate.minutesToArrival ?? 0
                let est = Calendar.current.date(byAdding: .minute, value: mins, to: now) ?? now
                let loc = liveUpdate.vehicleLocation.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                let arrival = TransitArrival(
                    routeID: routeID,
                    lineName: route.routeName,
                    destination: route.destinationName ?? route.routeLongName ?? "",
                    scheduledTime: est,
                    estimatedTime: est,
                    minutesToArrival: mins,
                    isRealTime: liveUpdate.isRealTime ?? true,
                    vehicleLocation: loc
                )
                arrivals.append(arrival)
            } else {
                // Scheduled fallback
                let arrival = TransitArrival(
                    routeID: routeID,
                    lineName: route.routeName,
                    destination: route.destinationName ?? route.routeLongName ?? "",
                    scheduledTime: now.addingTimeInterval(600), // Default 10 min placeholder
                    estimatedTime: nil,
                    minutesToArrival: nil,
                    isRealTime: false,
                    vehicleLocation: nil
                )
                arrivals.append(arrival)
            }
        }

        return arrivals.sorted { $0.scheduledTime < $1.scheduledTime }
    }
}
