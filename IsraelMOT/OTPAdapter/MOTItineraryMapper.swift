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

nonisolated public enum MOTItineraryMapper {
    #if canImport(OTPKit)
    public static func map(
        from responseDTO: RouteResponseDTOListServiceResponse,
        requestOrigin: CLLocationCoordinate2D,
        requestDest: CLLocationCoordinate2D
    ) -> OTPResponse {
        let routes = responseDTO.data ?? []
        let itineraries = routes.compactMap {
            mapItinerary(from: $0, fallbackOrigin: requestOrigin, fallbackDest: requestDest)
        }

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

        let firstPlanDate = itineraries.first?.startTime ?? Date()
        let plan = Plan(
            date: firstPlanDate,
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

    public static func mapItinerary(
        from dto: RouteResponseDTO,
        fallbackOrigin: CLLocationCoordinate2D,
        fallbackDest: CLLocationCoordinate2D
    ) -> Itinerary? {
        guard !dto.sections.isEmpty else { return nil }

        var legs: [Leg] = []
        var totalWalkTime = 0
        var totalTransitTime = 0
        var totalWalkDistance = 0.0
        var transitLegCount = 0

        for section in dto.sections {
            guard let legStartTime = MOTDateParser.parse(section.departure?.time),
                  let legEndTime = MOTDateParser.parse(section.arrival?.time) else {
                return nil
            }

            let isWalk = MOTSectionModeMapper.isWalkSection(section)
            let mode = MOTSectionModeMapper.modeString(for: section)
            let routeType = MOTSectionModeMapper.routeType(for: section)

            let legDuration = section.travelSummary?.duration ?? max(Int(legEndTime.timeIntervalSince(legStartTime)), 0)
            let legDistance = Double(section.travelSummary?.length ?? 0)

            let transitLegIndex = transitLegCount
            if isWalk {
                totalWalkTime += legDuration
                totalWalkDistance += legDistance
            } else {
                totalTransitTime += legDuration
                transitLegCount += 1
            }

            let originCoord = section.departure?.place?.location.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            } ?? fallbackOrigin

            let destCoord = section.arrival?.place?.location.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            } ?? fallbackDest

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

            let isRealTime = section.departure?.nextStopsTimes?.first?.isRealTime ?? false
            let steps = mapSteps(from: section.actions, polyline: section.polyline, fallbackCoord: originCoord)

            let legColor = MOTLegStyleResolver.resolveColor(
                transportColor: section.transport?.color,
                transitLegIndex: transitLegIndex,
                isWalk: isWalk
            )
            let legTextColor = MOTLegStyleResolver.resolveTextColor(forBackgroundColor: legColor)

            let intermediateStops: [Place] = (section.intermediateStops ?? []).compactMap { stopDTO in
                guard let placeDTO = stopDTO.departure?.place,
                      let loc = placeDTO.location else {
                    return nil
                }
                return Place(
                    name: placeDTO.name ?? "",
                    lon: loc.lng,
                    lat: loc.lat,
                    vertexType: "STOP",
                    stopId: placeDTO.code,
                    stopCode: placeDTO.code
                )
            }

            let leg = Leg(
                startTime: legStartTime,
                endTime: legEndTime,
                mode: mode,
                routeType: routeType,
                routeColor: legColor,
                routeTextColor: legTextColor,
                route: section.transport?.shortName ?? section.transport?.name,
                agencyName: section.agency?.name,
                from: fromPlace,
                to: toPlace,
                legGeometry: geometry,
                distance: legDistance,
                transitLeg: !isWalk,
                duration: legDuration,
                realTime: isRealTime,
                streetNames: nil,
                pathway: nil,
                steps: steps.isEmpty ? nil : steps,
                headsign: section.transport?.headsign,
                intermediateStops: intermediateStops.isEmpty ? nil : intermediateStops,
                departureDelay: 0,
                arrivalDelay: 0,
                rentedBike: false
            )

            legs.append(leg)
        }

        guard let firstStartTime = legs.first?.startTime,
              let lastEndTime = legs.last?.endTime else {
            return nil
        }

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
            transfers: max(transitLegCount - 1, 0),
            legs: legs
        )
    }

    private static func mapSteps(
        from actions: [MOTActionDTO]?,
        polyline: String?,
        fallbackCoord: CLLocationCoordinate2D
    ) -> [Step] {
        guard let actions = actions, !actions.isEmpty else { return [] }
        let coordinates = MOTLegGeometryMapper.decodeToCoordinates(polyline: polyline)

        return actions.map { action in
            let relativeDir: String?
            if let dir = action.direction?.lowercased() {
                if dir == "left" {
                    relativeDir = "LEFT"
                } else if dir == "right" {
                    relativeDir = "RIGHT"
                } else {
                    relativeDir = nil
                }
            } else if action.action?.lowercased() == "depart" {
                relativeDir = "DEPART"
            } else {
                relativeDir = nil
            }

            let coord: CLLocationCoordinate2D
            if let offset = action.offset, offset >= 0, offset < coordinates.count {
                coord = coordinates[offset]
            } else {
                coord = fallbackCoord
            }

            return Step(
                distance: action.length ?? 0.0,
                streetName: action.instruction ?? "",
                relativeDirection: relativeDir,
                elevationChange: nil,
                lon: coord.longitude,
                lat: coord.latitude
            )
        }
    }
    #endif
}
