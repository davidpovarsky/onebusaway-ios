//
//  OBACompatibilityBridge.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

/// Bridges Israel MOT domain models into valid OneBusAway REST JSON envelopes
/// with complete and strictly resolved reference graphs (stops, routes, trips, agencies).
public enum OBACompatibilityBridge {

    // MARK: - Envelopes

    public static func stopsForLocationResponse(
        stops: [TransitStop],
        currentTime: Date = Date()
    ) -> [String: Any] {
        var obaStops: [[String: Any]] = []
        var referencesAgencies: [String: [String: Any]] = [:]
        var referencesRoutes: [String: [String: Any]] = [:]
        var referencesStops: [String: [String: Any]] = [:]

        for stop in stops {
            let stopDict = serializeStop(stop)
            obaStops.append(stopDict)
            referencesStops[stopDict["id"] as! String] = stopDict

            for route in stop.routes {
                let routeDict = serializeRouteSummary(route)
                let rId = routeDict["id"] as! String
                referencesRoutes[rId] = routeDict

                if let agId = route.agencyID {
                    let agDict = serializeAgency(id: agId, name: route.agencyName ?? "משרד התחבורה")
                    referencesAgencies[agDict["id"] as! String] = agDict
                }
            }
        }

        let references: [String: Any] = [
            "agencies": Array(referencesAgencies.values),
            "routes": Array(referencesRoutes.values),
            "stops": Array(referencesStops.values),
            "trips": [],
            "situations": []
        ]

        let data: [String: Any] = [
            "limitExceeded": false,
            "list": obaStops,
            "outOfRange": false,
            "references": references
        ]

        return [
            "code": 200,
            "currentTime": Int(currentTime.timeIntervalSince1970 * 1000),
            "text": "OK",
            "version": 2,
            "data": data
        ]
    }

    public static func stopDetailResponse(
        stop: TransitStop,
        currentTime: Date = Date()
    ) -> [String: Any] {
        let stopDict = serializeStop(stop)
        var referencesAgencies: [String: [String: Any]] = [:]
        var referencesRoutes: [String: [String: Any]] = [:]
        var referencesStops: [String: [String: Any]] = [stopDict["id"] as! String: stopDict]

        for route in stop.routes {
            let routeDict = serializeRouteSummary(route)
            let rId = routeDict["id"] as! String
            referencesRoutes[rId] = routeDict

            if let agId = route.agencyID {
                let agDict = serializeAgency(id: agId, name: route.agencyName ?? "משרד התחבורה")
                referencesAgencies[agDict["id"] as! String] = agDict
            }
        }

        let references: [String: Any] = [
            "agencies": Array(referencesAgencies.values),
            "routes": Array(referencesRoutes.values),
            "stops": Array(referencesStops.values),
            "trips": [],
            "situations": []
        ]

        let data: [String: Any] = [
            "entry": stopDict,
            "references": references
        ]

        return [
            "code": 200,
            "currentTime": Int(currentTime.timeIntervalSince1970 * 1000),
            "text": "OK",
            "version": 2,
            "data": data
        ]
    }

    public static func stopArrivalsResponse(
        stop: TransitStop,
        arrivals: [TransitArrival],
        currentTime: Date = Date()
    ) -> [String: Any] {
        let stopDict = serializeStop(stop)
        var referencesAgencies: [String: [String: Any]] = [:]
        var referencesRoutes: [String: [String: Any]] = [:]
        var referencesStops: [String: [String: Any]] = [stopDict["id"] as! String: stopDict]
        var referencesTrips: [String: [String: Any]] = [:]

        var obaArrivals: [[String: Any]] = []

        // Register all routes in stop
        for route in stop.routes {
            let routeDict = serializeRouteSummary(route)
            let rId = routeDict["id"] as! String
            referencesRoutes[rId] = routeDict

            if let agId = route.agencyID {
                let agDict = serializeAgency(id: agId, name: route.agencyName ?? "משרד התחבורה")
                referencesAgencies[agDict["id"] as! String] = agDict
            }
        }

        // Build ArrivalDeparture records
        for (idx, arr) in arrivals.enumerated() {
            let scopedRouteId = MOTIdentityFormatter.scopedRouteID(id: arr.routeID)
            let schedSec = Int(arr.scheduledTime.timeIntervalSince1970)
            let syntheticTripId = "mot:trip:\(arr.routeID.rawValue)_\(schedSec)"

            // Ensure route reference exists
            if referencesRoutes[scopedRouteId] == nil {
                let fallbackRouteDict: [String: Any] = [
                    "id": scopedRouteId,
                    "agencyId": "mot:agency:1",
                    "shortName": arr.lineName,
                    "longName": arr.destination,
                    "description": arr.destination,
                    "type": 3,
                    "url": ""
                ]
                referencesRoutes[scopedRouteId] = fallbackRouteDict
                referencesAgencies["mot:agency:1"] = serializeAgency(id: MOTAgencyID(rawValue: 1), name: "משרד התחבורה")
            }

            // Ensure trip reference exists
            let tripDict: [String: Any] = [
                "id": syntheticTripId,
                "routeId": scopedRouteId,
                "serviceId": "mot:service:default",
                "tripHeadsign": arr.destination,
                "tripShortName": arr.lineName,
                "directionId": "0",
                "blockId": "",
                "shapeId": "",
                "timeZone": "Asia/Jerusalem"
            ]
            referencesTrips[syntheticTripId] = tripDict

            let schedMs = Int(arr.scheduledTime.timeIntervalSince1970 * 1000)
            let predMs = arr.isRealTime ? arr.estimatedTime.map { Int($0.timeIntervalSince1970 * 1000) } : nil

            var arrivalDict: [String: Any] = [
                "routeId": scopedRouteId,
                "routeShortName": arr.lineName,
                "routeLongName": arr.destination,
                "tripId": syntheticTripId,
                "tripHeadsign": arr.destination,
                "stopId": stopDict["id"] as! String,
                "stopSequence": idx + 1,
                "scheduledArrivalTime": schedMs,
                "scheduledDepartureTime": schedMs,
                "predicted": arr.isRealTime,
                "serviceDate": Int(Calendar.current.startOfDay(for: arr.scheduledTime).timeIntervalSince1970 * 1000),
                "distanceFromStop": 0.0,
                "numberOfStopsAway": 0,
                "status": arr.isRealTime ? "default" : "scheduled",
                "arrivalEnabled": true,
                "departureEnabled": true,
                "totalStopsInTrip": 20,
                "blockTripSequence": 1,
                "situationIds": []
            ]

            if let predMs = predMs {
                arrivalDict["predictedArrivalTime"] = predMs
                arrivalDict["predictedDepartureTime"] = predMs
            }

            if arr.isRealTime, let loc = arr.vehicleLocation {
                arrivalDict["tripStatus"] = [
                    "activeTripId": syntheticTripId,
                    "blockTripSequence": 1,
                    "serviceDate": Int(Calendar.current.startOfDay(for: arr.scheduledTime).timeIntervalSince1970 * 1000),
                    "scheduledDistanceAlongTrip": 0.0,
                    "totalDistanceAlongTrip": 1000.0,
                    "position": ["lat": loc.latitude, "lon": loc.longitude],
                    "predicted": true,
                    "status": "default",
                    "phase": "in_progress"
                ]
            }

            obaArrivals.append(arrivalDict)
        }

        let references: [String: Any] = [
            "agencies": Array(referencesAgencies.values),
            "routes": Array(referencesRoutes.values),
            "stops": Array(referencesStops.values),
            "trips": Array(referencesTrips.values),
            "situations": []
        ]

        let entry: [String: Any] = [
            "stopId": stopDict["id"] as! String,
            "arrivalsAndDepartures": obaArrivals,
            "nearbyStopIds": [],
            "situationIds": []
        ]

        let data: [String: Any] = [
            "entry": entry,
            "references": references
        ]

        return [
            "code": 200,
            "currentTime": Int(currentTime.timeIntervalSince1970 * 1000),
            "text": "OK",
            "version": 2,
            "data": data
        ]
    }

    public static func routeDetailResponse(
        route: TransitRoute,
        currentTime: Date = Date()
    ) -> [String: Any] {
        let routeDict = serializeRoute(route)
        let scopedRouteId = routeDict["id"] as! String
        let agencyDict = serializeAgency(id: route.agencyID, name: route.agencyName)

        var referencesStops: [String: [String: Any]] = [:]
        var stopIds: [String] = []

        for stop in route.stops {
            let sDict = serializeStop(stop)
            let sId = sDict["id"] as! String
            referencesStops[sId] = sDict
            stopIds.append(sId)
        }

        let references: [String: Any] = [
            "agencies": [agencyDict],
            "routes": [routeDict],
            "stops": Array(referencesStops.values),
            "trips": [],
            "situations": []
        ]

        let data: [String: Any] = [
            "entry": routeDict,
            "references": references
        ]

        return [
            "code": 200,
            "currentTime": Int(currentTime.timeIntervalSince1970 * 1000),
            "text": "OK",
            "version": 2,
            "data": data
        ]
    }

    // MARK: - Serializers

    private static func serializeStop(_ stop: TransitStop) -> [String: Any] {
        let scopedId = MOTIdentityFormatter.scopedStopID(code: stop.code)
        let routeIds = stop.routes.map { MOTIdentityFormatter.scopedRouteID(id: $0.routeID) }
        return [
            "id": scopedId,
            "code": stop.code.description,
            "name": stop.name.localizedName(),
            "lat": stop.location.latitude,
            "lon": stop.location.longitude,
            "direction": "unknown",
            "locationType": 0,
            "routeIds": routeIds,
            "wheelchairBoarding": stop.isAccessible == true ? "accessible" : "unknown"
        ]
    }

    private static func serializeRouteSummary(_ route: TransitRouteSummary) -> [String: Any] {
        let scopedId = MOTIdentityFormatter.scopedRouteID(id: route.routeID)
        let agencyId = route.agencyID != nil ? MOTIdentityFormatter.scopedAgencyID(id: route.agencyID!) : "mot:agency:1"
        return [
            "id": scopedId,
            "agencyId": agencyId,
            "shortName": route.lineName,
            "longName": route.destinationName ?? route.lineName,
            "description": route.destinationName ?? "",
            "type": 3, // Bus
            "url": ""
        ]
    }

    private static func serializeRoute(_ route: TransitRoute) -> [String: Any] {
        let scopedId = MOTIdentityFormatter.scopedRouteID(id: route.routeID)
        let agencyId = MOTIdentityFormatter.scopedAgencyID(id: route.agencyID)
        return [
            "id": scopedId,
            "agencyId": agencyId,
            "shortName": route.lineName,
            "longName": route.longName ?? route.lineName,
            "description": route.longName ?? "",
            "type": 3, // Bus
            "url": ""
        ]
    }

    private static func serializeAgency(id: MOTAgencyID, name: String) -> [String: Any] {
        let scopedId = MOTIdentityFormatter.scopedAgencyID(id: id)
        return [
            "id": scopedId,
            "name": name,
            "url": "https://bus.gov.il",
            "timezone": "Asia/Jerusalem",
            "lang": "he",
            "phone": "*8787"
        ]
    }
}
