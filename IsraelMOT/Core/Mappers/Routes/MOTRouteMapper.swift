//
//  MOTRouteMapper.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

public enum MOTRouteMapper {
    public static func map(
        routeDTO: RouteFullDataResponseDTO,
        stopsDTO: RouteWithStopsDTO? = nil
    ) -> TransitRoute {
        let routeID = MOTRouteID(rawValue: routeDTO.routeId)
        let routeDesc = routeDTO.routeDesc.map { MOTRouteDesc(rawValue: $0) }
        let agencyID = MOTAgencyID(rawValue: routeDTO.agencyId)

        let stops: [TransitStop] = (stopsDTO?.stops ?? []).compactMap { s in
            let code = MOTStopCode(rawValue: s.stopcode)
            let internalID = MOTStopInternalID(rawValue: s.stopid)
            let name = TransitMultiLanguageName(he: s.name?.he, en: s.name?.en, ar: s.name?.ar)
            let loc = CLLocationCoordinate2D(latitude: s.lat ?? 0.0, longitude: s.lng ?? 0.0)
            return TransitStop(
                code: code,
                internalID: internalID,
                name: name,
                cityName: routeDTO.cityName,
                location: loc,
                routes: []
            )
        }

        return TransitRoute(
            routeID: routeID,
            lineName: routeDTO.routeName,
            longName: routeDTO.routeLongName,
            routeDesc: routeDesc,
            agencyID: agencyID,
            agencyName: routeDTO.agencyName,
            cityName: routeDTO.cityName,
            polyline: routeDTO.polyline,
            stops: stops
        )
    }
}
