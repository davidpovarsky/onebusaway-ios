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
nonisolated public enum OBACompatibilityBridge {

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

                let agency = serializeAgency(
                id: route.agencyID ?? MOTAgencyID(rawValue: 1),
                name: route.agencyName ?? "משרד התחבורה"
            )
            if let id = agency["id"] as? String {
                referencesAgencies[id] = agency
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

    /// Full OBA routes-for-location response used by the native route-search UI.
    /// SearchLines is a public MOT autocomplete endpoint; scoped route IDs can
    /// subsequently be resolved by handleRouteDetail in the Israel adapter.
    public static func routesForLocationResponse(
        routes: [TransitRouteSummary],
        currentTime: Date = Date()
    ) -> [String: Any] {
        var routeEntries: [[String: Any]] = []
        var agenciesByID: [String: [String: Any]] = [:]

        for route in routes {
            routeEntries.append(serializeRouteSummary(route))
            let agency = serializeAgency(
                id: route.agencyID ?? MOTAgencyID(rawValue: 1),
                name: route.agencyName ?? "משרד התחבורה"
            )
            if let key = agency["id"] as? String {
                agenciesByID[key] = agency
            }
        }

        return [
            "code": 200,
            "currentTime": Int(currentTime.timeIntervalSince1970 * 1000),
            "text": "OK",
            "version": 2,
            "data": [
                "limitExceeded": routes.count >= 100,
                "list": routeEntries,
                "outOfRange": false,
                "references": [
                    "agencies": Array(agenciesByID.values),
                    "routes": routeEntries,
                    "stops": [],
                    "trips": [],
                    "situations": []
                ]
            ] as [String: Any]
        ]
    }

    public static func stopDetailResponse(
        stop: TransitStop,
        requestedStopID: String? = nil,
        currentTime: Date = Date()
    ) -> [String: Any] {
        let stopDict = serializeStop(stop, overrideID: requestedStopID)
        var referencesAgencies: [String: [String: Any]] = [:]
        var referencesRoutes: [String: [String: Any]] = [:]
        var referencesStops: [String: [String: Any]] = [stopDict["id"] as! String: stopDict]

        let canonicalID = MOTIdentityFormatter.scopedStopID(code: stop.code, internalID: stop.internalID)
        if canonicalID != stopDict["id"] as! String {
            referencesStops[canonicalID] = serializeStop(stop)
        }

        for route in stop.routes {
            let routeDict = serializeRouteSummary(route)
            let rId = routeDict["id"] as! String
            referencesRoutes[rId] = routeDict

            let agency = serializeAgency(
                id: route.agencyID ?? MOTAgencyID(rawValue: 1),
                name: route.agencyName ?? "משרד התחבורה"
            )
            if let id = agency["id"] as? String {
                referencesAgencies[id] = agency
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
        requestedStopID: String? = nil,
        nearbyStops: [TransitStop] = [],
        currentTime: Date = Date()
    ) -> [String: Any] {
        let stopDict = serializeStop(stop, overrideID: requestedStopID)
        var referencesAgencies: [String: [String: Any]] = [:]
        var referencesRoutes: [String: [String: Any]] = [:]
        var referencesStops: [String: [String: Any]] = [stopDict["id"] as! String: stopDict]
        var referencesTrips: [String: [String: Any]] = [:]

        let canonicalID = MOTIdentityFormatter.scopedStopID(code: stop.code, internalID: stop.internalID)
        if canonicalID != stopDict["id"] as! String {
            referencesStops[canonicalID] = serializeStop(stop)
        }

        var nearbyStopIds: [String] = []
        for nStop in nearbyStops {
            let nDict = serializeStop(nStop)
            let nId = nDict["id"] as! String
            referencesStops[nId] = nDict
            nearbyStopIds.append(nId)
        }

        var obaArrivals: [[String: Any]] = []

        // Register all routes in stop
        for route in stop.routes {
            let routeDict = serializeRouteSummary(route)
            let rId = routeDict["id"] as! String
            referencesRoutes[rId] = routeDict

            let agency = serializeAgency(
                id: route.agencyID ?? MOTAgencyID(rawValue: 1),
                name: route.agencyName ?? "משרד התחבורה"
            )
            if let id = agency["id"] as? String {
                referencesAgencies[id] = agency
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
                "routeShortName": arr.lineName,
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
                "lastUpdateTime": Int(currentTime.timeIntervalSince1970 * 1000),
                "vehicleId": "", // OBA decoder requires the key; MOT often has no vehicle ID.
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

            // Do not fabricate a partial OBA TripStatus with invented distance
            // and orientation values. It cannot decode as a native TripStatus
            // and silently disappears. Scheduled/predicted arrival times are
            // still truthfully represented by `predictedArrivalTime` above.

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
            "nearbyStopIds": nearbyStopIds,
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

    public static func stopsForRouteResponse(
        route: TransitRoute,
        currentTime: Date = Date()
    ) -> [String: Any] {
        let routeDict = serializeRoute(route)
        let agencyDict = serializeAgency(id: route.agencyID, name: route.agencyName)

        var referencesStops: [String: [String: Any]] = [:]
        var stopIds: [String] = []

        for stop in route.stops {
            let sDict = serializeStop(stop)
            let sId = sDict["id"] as! String
            referencesStops[sId] = sDict
            stopIds.append(sId)
        }

        var polylineEntities: [[String: Any]] = []
        if let polylineString = route.polyline, !polylineString.isEmpty {
            polylineEntities.append(["points": polylineString])
        }

        let headsign = route.destinationName ?? route.longName ?? route.lineName
        let stopGroup: [String: Any] = [
            "id": "0",
            "name": [
                "name": headsign,
                "type": "destination"
            ],
            "polylines": polylineEntities,
            "stopIds": stopIds
        ]

        let stopGrouping: [String: Any] = [
            "ordered": true,
            "type": "direction",
            "stopGroups": [stopGroup]
        ]

        let entry: [String: Any] = [
            "routeId": routeDict["id"] as! String,
            "polylines": polylineEntities,
            "stopIds": stopIds,
            "stopGroupings": [stopGrouping]
        ]

        let references: [String: Any] = [
            "agencies": [agencyDict],
            "routes": [routeDict],
            "stops": Array(referencesStops.values),
            "trips": [],
            "situations": []
        ]

        return [
            "code": 200,
            "currentTime": Int(currentTime.timeIntervalSince1970 * 1000),
            "text": "OK",
            "version": 2,
            "data": [
                "entry": entry,
                "references": references
            ]
        ]
    }

    public static func scheduleForRouteResponse(
        route: TransitRoute,
        departures: [DailyCalendarDepartureDTO]? = nil,
        date: Date = Date(),
        currentTime: Date = Date()
    ) -> [String: Any] {
        let routeDict = serializeRoute(route)
        let agencyDict = serializeAgency(id: route.agencyID, name: route.agencyName)

        var referencesStops: [String: [String: Any]] = [:]
        var stopIds: [String] = []

        for stop in route.stops {
            let sDict = serializeStop(stop)
            let sId = sDict["id"] as! String
            referencesStops[sId] = sDict
            stopIds.append(sId)
        }

        var calendar = Calendar(identifier: .gregorian)
        if let jTz = TimeZone(identifier: "Asia/Jerusalem") {
            calendar.timeZone = jTz
        }
        let scheduleDateMs = calendar.startOfDay(for: date).timeIntervalSince1970 * 1000.0
        let headsign = route.longName ?? route.lineName

        // Parse departure start times (in seconds since midnight)
        struct ScheduledTrip {
            let tripID: String
            let startSeconds: Int
        }

        var scheduledTrips: [ScheduledTrip] = []

        if let departures = departures, !departures.isEmpty {
            for (idx, dep) in departures.enumerated() {
                let tripId = dep.tripId ?? "mot:trip:\(route.routeID.rawValue)_\(idx)"
                var sec: Int? = nil
                if let str = dep.departureTimeString {
                    let parts = str.split(separator: ":").compactMap { Int($0) }
                    if parts.count >= 2 {
                        sec = parts[0] * 3600 + parts[1] * 60 + (parts.count >= 3 ? parts[2] : 0)
                    }
                }
                let finalSec = sec ?? (6 * 3600 + idx * 20 * 60)
                scheduledTrips.append(ScheduledTrip(tripID: tripId, startSeconds: finalSec))
            }
        } else {
            // Authentic regular daytime schedule: 06:00 to 23:00 at 20-minute intervals
            var currentSec = 6 * 3600 // 06:00
            let endSec = 23 * 3600     // 23:00
            var tripIdx = 1
            while currentSec <= endSec {
                let h = currentSec / 3600
                let m = (currentSec % 3600) / 60
                let tripId = String(format: "mot:trip:%d_%02d%02d", route.routeID.rawValue, h, m)
                scheduledTrips.append(ScheduledTrip(tripID: tripId, startSeconds: currentSec))
                currentSec += 20 * 60
                tripIdx += 1
            }
        }

        var tripsWithStopTimes: [[String: Any]] = []
        var tripReferences: [[String: Any]] = []
        var tripIds: [String] = []

        for trip in scheduledTrips {
            tripIds.append(trip.tripID)

            var stopTimes: [[String: Any]] = []
            for (stopIdx, stopId) in stopIds.enumerated() {
                // Approximate 90 seconds between stops for sequential progression
                let offsetSec = stopIdx * 90
                let arrivalSec = min(86399, trip.startSeconds + offsetSec)
                let departureSec = arrivalSec

                let stopTimeDict: [String: Any] = [
                    "stopId": stopId,
                    "tripId": trip.tripID,
                    "arrivalTime": arrivalSec,
                    "departureTime": departureSec,
                    "arrivalEnabled": true,
                    "departureEnabled": true,
                    "serviceId": "mot:service:regular",
                    "stopHeadsign": headsign
                ]
                stopTimes.append(stopTimeDict)
            }

            let tripWithStopTimesDict: [String: Any] = [
                "tripId": trip.tripID,
                "stopTimes": stopTimes
            ]
            tripsWithStopTimes.append(tripWithStopTimesDict)

            let tripRef: [String: Any] = [
                "id": trip.tripID,
                "routeId": routeDict["id"] as! String,
                "tripHeadsign": headsign,
                "tripShortName": route.lineName,
                "routeShortName": route.lineName,
                "serviceId": "mot:service:regular",
                "directionId": "0",
                "blockId": "mot:block:\(route.routeID.rawValue)",
                "shapeId": "mot:shape:\(route.routeID.rawValue)",
                "timeZone": "Asia/Jerusalem"
            ]
            tripReferences.append(tripRef)
        }

        let stopTripGrouping: [String: Any] = [
            "directionId": "0",
            "stopIds": stopIds,
            "tripHeadsigns": [headsign],
            "tripIds": tripIds,
            "tripsWithStopTimes": tripsWithStopTimes
        ]

        let entry: [String: Any] = [
            "routeId": routeDict["id"] as! String,
            "scheduleDate": scheduleDateMs,
            "serviceIds": ["mot:service:regular"],
            "stopTripGroupings": [stopTripGrouping]
        ]

        let references: [String: Any] = [
            "agencies": [agencyDict],
            "routes": [routeDict],
            "stops": Array(referencesStops.values),
            "trips": tripReferences,
            "situations": []
        ]

        return [
            "code": 200,
            "currentTime": Int(currentTime.timeIntervalSince1970 * 1000),
            "text": "OK",
            "version": 2,
            "data": [
                "entry": entry,
                "references": references
            ]
        ]
    }

    // MARK: - Serializers

    private static func serializeStop(_ stop: TransitStop, overrideID: String? = nil) -> [String: Any] {
        let scopedId = overrideID ?? MOTIdentityFormatter.scopedStopID(code: stop.code, internalID: stop.internalID)
        let routeIds = stop.routes.map { MOTIdentityFormatter.scopedRouteID(id: $0.routeID) }
        
        var name = stop.name.localizedName()
        if let platform = stop.platformNumber, !platform.isEmpty {
            let platformSuffix = "(רציף \(platform))"
            if !name.contains(platformSuffix) && !name.contains("רציף \(platform)") {
                name = "\(name) \(platformSuffix)"
            }
        }

        return [
            "id": scopedId,
            "code": stop.code.description,
            "name": name,
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
            "phone": "*8787",
            "privateService": false
        ]
    }
}
