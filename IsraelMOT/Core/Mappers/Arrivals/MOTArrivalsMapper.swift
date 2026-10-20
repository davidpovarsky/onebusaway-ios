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
        stopTimesByRouteDesc: [String: [NextStopTimeDTO]] = [:]
    ) -> [TransitArrival] {
        var arrivals: [TransitArrival] = []

        for route in routesInStop {
            let routeID = MOTRouteID(rawValue: route.routeId)
            let routeDesc = route.routeDesc ?? ""
            let stopTimes = stopTimesByRouteDesc[routeDesc] ?? []
            let agencyID = route.agencyId.map { MOTAgencyID(rawValue: $0) }
            let routeDescObj = route.routeDesc.map { MOTRouteDesc(rawValue: $0) }

            for st in stopTimes {
                guard let arrivalDate = MOTDateParser.parse(st.arrivalTime) else {
                    continue
                }

                let isRealTime = st.isRealTime ?? false
                let staticDate = MOTDateParser.parse(st.staticArrivalTime) ?? arrivalDate
                let estimatedDate: Date? = isRealTime ? arrivalDate : nil
                let mins = st.minutesToArrival.map { Int($0.rounded()) }

                let vehicleLoc: CLLocationCoordinate2D? = (isRealTime ? st.routeLocation : nil).map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                }

                let arrival = TransitArrival(
                    routeID: routeID,
                    lineName: route.routeName,
                    destination: route.destinationName ?? route.routeLongName ?? "",
                    scheduledTime: staticDate,
                    estimatedTime: estimatedDate,
                    minutesToArrival: mins,
                    isRealTime: isRealTime,
                    vehicleLocation: vehicleLoc,
                    staticTripId: st.staticTripId,
                    tripIdToDate: st.tripIdToDate,
                    routeDesc: routeDescObj,
                    stopSequence: st.stopOrder,
                    agencyID: agencyID,
                    agencyName: route.agencyName
                )
                arrivals.append(arrival)
            }
        }

        return arrivals.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    /// Compatibility overload mapping an array of updates grouped by routeDesc.
    public static func map(
        routesInStop: [RouteInStopDTO],
        realTimeUpdates: [NextStopTimeDTO]
    ) -> [TransitArrival] {
        var dict: [String: [NextStopTimeDTO]] = [:]
        for update in realTimeUpdates {
            if let rd = routesInStop.first?.routeDesc {
                dict[rd, default: []].append(update)
            }
        }
        return map(routesInStop: routesInStop, stopTimesByRouteDesc: dict)
    }
}
