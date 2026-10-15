//
//  MOTItineraryMapper.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

#if canImport(OTPKit)
import OTPKit
#endif

public enum MOTItineraryMapper {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let fallbackISOFormatter = ISO8601DateFormatter()

    private static func parseDate(_ string: String?) -> Date {
        guard let s = string, !s.isEmpty else { return Date() }
        if let d = isoFormatter.date(from: s) { return d }
        if let d = fallbackISOFormatter.date(from: s) { return d }
        return Date()
    }

    #if canImport(OTPKit)
    public static func map(from responseDTO: RouteResponseDTOListServiceResponse, requestOrigin: CLLocationCoordinate2D, requestDest: CLLocationCoordinate2D) -> OTPResponse {
        let routes = responseDTO.data ?? []
        let itineraries = routes.compactMap { mapItinerary(from: $0, fallbackOrigin: requestOrigin, fallbackDest: requestDest) }

        let fromPlace = Place(
            name: "מוצא",
            lon: requestOrigin.longitude,
            lat: requestOrigin.latitude,
            vertexType: "NORMAL"
        )
        let toPlace = Place(
            name: "יעד",
            lon: requestDest.longitude,
            lat: requestDest.latitude,
            vertexType: "NORMAL"
        )

        let plan = Plan(
            date: Date(),
            from: fromPlace,
            to: toPlace,
            itineraries: itineraries
        )

        let requestParams = RequestParameters()

        return OTPResponse(
            requestParameters: requestParams,
            plan: plan,
            error: nil
        )
    }

    public static func mapItinerary(from dto: RouteResponseDTO, fallbackOrigin: CLLocationCoordinate2D, fallbackDest: CLLocationCoordinate2D) -> Itinerary? {
        guard !dto.sections.isEmpty else { return nil }

        var legs: [Leg] = []
        var totalWalkTime = 0
        var totalTransitTime = 0
        var totalWalkDistance = 0.0
        var transferCount = 0

        for section in dto.sections {
            let legStartTime = parseDate(section.departure?.time)
            let legEndTime = parseDate(section.arrival?.time)
            let legDuration = section.travelSummary?.duration ?? max(Int(legEndTime.timeIntervalSince(legStartTime)), 0)
            let legDistance = Double(section.travelSummary?.length ?? 0)

            let isWalk = (section.type?.lowercased() == "walk" || section.transport == nil)
            let mode = isWalk ? "WALK" : (section.transport?.mode?.uppercased() ?? "BUS")

            if isWalk {
                totalWalkTime += legDuration
                totalWalkDistance += legDistance
            } else {
                totalTransitTime += legDuration
                transferCount += 1
            }

            let originCoord = section.departure?.place?.location.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) } ?? fallbackOrigin
            let destCoord = section.arrival?.place?.location.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) } ?? fallbackDest

            let fromPlace = Place(
                name: section.departure?.place?.name ?? "",
                lon: originCoord.longitude,
                lat: originCoord.latitude,
                vertexType: isWalk ? "NORMAL" : "STOP",
                stopId: section.departure?.place?.code,
                stopCode: section.departure?.place?.code
            )

            let toPlace = Place(
                name: section.arrival?.place?.name ?? "",
                lon: destCoord.longitude,
                lat: destCoord.latitude,
                vertexType: isWalk ? "NORMAL" : "STOP",
                stopId: section.arrival?.place?.code,
                stopCode: section.arrival?.place?.code
            )

            let geometry = MOTLegGeometryMapper.map(
                fromPolyline: section.polyline,
                fallbackOrigin: originCoord,
                fallbackDest: destCoord
            )

            let routeType: RouteType = isWalk ? .nonTransit : (mode == "RAIL" ? .train : (mode == "TRAM" ? .tram : .bus))

            let isRealTime = section.departure?.nextStopsTimes?.first?.isRealTime ?? false

            let leg = Leg(
                startTime: legStartTime,
                endTime: legEndTime,
                mode: mode,
                routeType: routeType,
                routeColor: section.transport?.color,
                routeTextColor: "#FFFFFF",
                route: section.transport?.shortName ?? section.transport?.name,
                agencyName: section.agency?.name,
                from: fromPlace,
                to: toPlace,
                legGeometry: geometry,
                distance: legDistance,
                transitLeg: !isWalk,
                rentedBike: false,
                duration: legDuration,
                realTime: isRealTime,
                departureDelay: 0,
                arrivalDelay: 0,
                streetNames: nil,
                pathway: nil,
                steps: nil,
                headsign: section.transport?.headsign,
                intermediateStops: []
            )

            legs.append(leg)
        }

        let firstStartTime = legs.first?.startTime ?? Date()
        let lastEndTime = legs.last?.endTime ?? Date()
        let totalDuration = max(Int(lastEndTime.timeIntervalSince(firstStartTime)), totalWalkTime + totalTransitTime)

        return Itinerary(
            duration: totalDuration,
            startTime: firstStartTime,
            endTime: lastEndTime,
            walkTime: totalWalkTime,
            transitTime: totalTransitTime,
            waitingTime: max(totalDuration - (totalWalkTime + totalTransitTime), 0),
            walkDistance: totalWalkDistance,
            walkLimitExceeded: false,
            elevationLost: 0,
            elevationGained: 0,
            transfers: max(transferCount - 1, 0),
            legs: legs
        )
    }
    #endif
}
