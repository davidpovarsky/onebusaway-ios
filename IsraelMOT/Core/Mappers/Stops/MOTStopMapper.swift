//
//  MOTStopMapper.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

public enum MOTStopMapper {
    public static func map(from dto: StopFullDataResponseDTO) -> TransitStop {
        let code = MOTStopCode(rawValue: dto.stopcode)
        let internalID = MOTStopInternalID(rawValue: dto.stopid)
        let name = TransitMultiLanguageName(
            he: dto.name?.he,
            en: dto.name?.en,
            ar: dto.name?.ar
        )
        let location = CLLocationCoordinate2D(latitude: dto.lat, longitude: dto.lng)

        let routes = (dto.routesInStop ?? []).map { r in
            TransitRouteSummary(
                routeID: MOTRouteID(rawValue: r.routeId),
                lineName: r.routeName,
                routeDesc: r.routeDesc.map { MOTRouteDesc(rawValue: $0) },
                destinationName: r.destinationName ?? r.routeLongName,
                agencyID: r.agencyId.map { MOTAgencyID(rawValue: $0) },
                agencyName: r.agencyName
            )
        }

        return TransitStop(
            code: code,
            internalID: internalID,
            name: name,
            cityName: dto.cityName,
            streetName: dto.streetName,
            location: location,
            platformNumber: dto.platformNumber,
            isAccessible: nil,
            routes: routes
        )
    }

    public static func map(from dto: LocationAutoCompleteDTO) -> TransitStop? {
        guard let coords = dto.coordinates else { return nil }
        let stopCodeVal = dto.id.flatMap(Int.init) ?? 0
        let code = MOTStopCode(rawValue: stopCodeVal)
        let name = TransitMultiLanguageName(he: dto.title, en: nil, ar: nil)
        let location = CLLocationCoordinate2D(latitude: coords.lat, longitude: coords.lng)

        return TransitStop(
            code: code,
            name: name,
            cityName: dto.addressDetails?.city,
            streetName: dto.addressDetails?.street,
            location: location,
            routes: []
        )
    }
}
