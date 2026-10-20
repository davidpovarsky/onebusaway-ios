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

        var calendar = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "Asia/Jerusalem") {
            calendar.timeZone = tz
        }

        // Build ArrivalDeparture records
        for (idx, arr) in arrivals.enumerated() {
            let scopedRouteId = MOTIdentityFormatter.scopedRouteID(id: arr.routeID)

            let tripInstanceSuffix: String = {
                if let staticId = arr.staticTripId, !staticId.isEmpty {
                    return staticId
                }
                if let tripIdToDate = arr.tripIdToDate {
                    return "\(tripIdToDate)"
                }
                let schedSec = Int(arr.scheduledTime.timeIntervalSince1970)
                return "\(schedSec)"
            }()
            let tripId = MOTIdentityFormatter.scopedTripID(routeID: arr.routeID, suffix: tripInstanceSuffix)
            let shapeId = MOTIdentityFormatter.scopedShapeID(routeID: arr.routeID)

            // Ensure route reference exists
            if referencesRoutes[scopedRouteId] == nil {
                let fallbackRouteDict: [String: Any] = [
                    "id": scopedRouteId,
                    "agencyId": arr.agencyID.map { MOTIdentityFormatter.scopedAgencyID(id: $0) } ?? "mot:agency:1",
                    "shortName": arr.lineName,
                    "longName": arr.destination,
                    "description": arr.destination,
                    "type": 3,
                    "url": ""
                ]
                referencesRoutes[scopedRouteId] = fallbackRouteDict
                let agency = serializeAgency(id: arr.agencyID ?? MOTAgencyID(rawValue: 1), name: arr.agencyName ?? "משרד התחבורה")
                if let aid = agency["id"] as? String {
                    referencesAgencies[aid] = agency
                }
            }

            // Ensure trip reference exists with valid shapeId
            let tripDict: [String: Any] = [
                "id": tripId,
                "routeId": scopedRouteId,
                "serviceId": "mot:service:default",
                "tripHeadsign": arr.destination,
                "tripShortName": arr.lineName,
                "routeShortName": arr.lineName,
                "directionId": "0",
                "blockId": "mot:block:\(arr.routeID.rawValue)",
                "shapeId": shapeId,
                "timeZone": "Asia/Jerusalem"
            ]
            referencesTrips[tripId] = tripDict

            let schedMs = Int(arr.scheduledTime.timeIntervalSince1970 * 1000)
            let predMs = arr.isRealTime ? arr.estimatedTime.map { Int($0.timeIntervalSince1970 * 1000) } : nil
            let serviceDateMs = Int(calendar.startOfDay(for: arr.scheduledTime).timeIntervalSince1970 * 1000)

            var arrivalDict: [String: Any] = [
                "routeId": scopedRouteId,
                "routeShortName": arr.lineName,
                "routeLongName": arr.destination,
                "tripId": tripId,
                "tripHeadsign": arr.destination,
                "stopId": stopDict["id"] as! String,
                "stopSequence": arr.stopSequence ?? (idx + 1),
                "scheduledArrivalTime": schedMs,
                "scheduledDepartureTime": schedMs,
                "predicted": arr.isRealTime,
                "lastUpdateTime": Int(currentTime.timeIntervalSince1970 * 1000),
                "vehicleId": arr.staticTripId ?? "",
                "serviceDate": serviceDateMs,
                "distanceFromStop": -1.0,
                "numberOfStopsAway": -1,
                "status": arr.isRealTime ? "default" : "scheduled",
                "arrivalEnabled": true,
                "departureEnabled": true,
                "blockTripSequence": 1,
                "situationIds": []
            ]

            if let tripStatus = serializeTripStatus(
                arrival: arr,
                tripId: tripId,
                stopId: stopDict["id"] as! String,
                serviceDateMs: serviceDateMs,
                currentTime: currentTime
            ) {
                arrivalDict["tripStatus"] = tripStatus
            }

            if let predMs = predMs {
                arrivalDict["predictedArrivalTime"] = predMs
                arrivalDict["predictedDepartureTime"] = predMs
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
        if let polylineString = route.polyline,
           let googleE5 = MOTRouteGeometryPipeline.toGoogleE5(source: polylineString) {
            polylineEntities.append(["points": googleE5])
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

    // MARK: - Shape Response
    public static func shapeResponse(
        routeID: MOTRouteID,
        polyline: String?,
        currentTime: Date = Date()
    ) -> [String: Any]? {
        guard let polyline = polyline,
              let googleE5 = MOTRouteGeometryPipeline.toGoogleE5(source: polyline) else {
            return nil
        }

        let entry: [String: Any] = [
            "points": googleE5
        ]

        let references: [String: Any] = [
            "agencies": [],
            "routes": [],
            "stops": [],
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

    // MARK: - Trip Details Response
    public static func tripDetailsResponse(
        tripID: String,
        route: TransitRoute,
        stopTimes: [(stop: TransitStop, arrivalSec: Int?, departureSec: Int?)],
        vehicleLocation: CLLocationCoordinate2D? = nil,
        serviceDate: Date = Date(),
        currentTime: Date = Date()
    ) -> [String: Any] {
        let routeDict = serializeRoute(route)
        let agencyDict = serializeAgency(id: route.agencyID, name: route.agencyName)

        var referencesStops: [String: [String: Any]] = [:]
        for stop in route.stops {
            let sDict = serializeStop(stop)
            let sId = sDict["id"] as! String
            referencesStops[sId] = sDict
        }
        for (stop, _, _) in stopTimes {
            let sDict = serializeStop(stop)
            let sId = sDict["id"] as! String
            referencesStops[sId] = sDict
        }

        let scopedRouteId = MOTIdentityFormatter.scopedRouteID(id: route.routeID)
        let shapeId = MOTIdentityFormatter.scopedShapeID(routeID: route.routeID)
        let headsign = route.destinationName ?? route.longName ?? route.lineName

        let tripDict: [String: Any] = [
            "id": tripID,
            "routeId": scopedRouteId,
            "serviceId": "mot:service:default",
            "tripHeadsign": headsign,
            "tripShortName": route.lineName,
            "routeShortName": route.lineName,
            "directionId": "0",
            "blockId": "mot:block:\(route.routeID.rawValue)",
            "shapeId": shapeId,
            "timeZone": "Asia/Jerusalem"
        ]

        var calendar = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "Asia/Jerusalem") {
            calendar.timeZone = tz
        }
        let serviceDateMs = Int(calendar.startOfDay(for: serviceDate).timeIntervalSince1970 * 1000)

        var obaStopTimes: [[String: Any]] = []
        for item in stopTimes {
            let sId = serializeStop(item.stop)["id"] as! String
            var stDict: [String: Any] = [
                "stopId": sId
            ]
            if let arr = item.arrivalSec {
                stDict["arrivalTime"] = arr
            }
            if let dep = item.departureSec {
                stDict["departureTime"] = dep
            }
            obaStopTimes.append(stDict)
        }

        let schedule: [String: Any] = [
            "timeZone": "Asia/Jerusalem",
            "stopTimes": obaStopTimes
        ]

        var entry: [String: Any] = [
            "tripId": tripID,
            "serviceDate": serviceDateMs,
            "schedule": schedule,
            "situationIds": []
        ]

        if let loc = vehicleLocation, loc.latitude.isFinite, loc.longitude.isFinite,
           !(abs(loc.latitude) < 0.001 && abs(loc.longitude) < 0.001),
           loc.latitude >= 29.0, loc.latitude <= 33.5, loc.longitude >= 34.0, loc.longitude <= 36.0 {
            let nowMs = Int(currentTime.timeIntervalSince1970 * 1000)
            let closestStopId = obaStopTimes.first?["stopId"] as? String ?? ""
            entry["status"] = [
                "activeTripId": tripID,
                "blockTripSequence": 1,
                "closestStop": closestStopId,
                "closestStopTimeOffset": 0,
                "distanceAlongTrip": 0.0,
                "lastLocationUpdateTime": Int64(nowMs),
                "lastUpdateTime": nowMs,
                "nextStopTimeOffset": 0,
                "orientation": 0.0,
                "phase": "in_progress",
                "position": [
                    "lat": loc.latitude,
                    "lon": loc.longitude
                ],
                "predicted": true,
                "scheduleDeviation": 0,
                "scheduledDistanceAlongTrip": 0.0,
                "serviceDate": serviceDateMs,
                "situationIds": [] as [String],
                "status": "default",
                "totalDistanceAlongTrip": 0.0,
                "vehicleId": ""
            ]
        }

        let references: [String: Any] = [
            "agencies": [agencyDict],
            "routes": [routeDict],
            "stops": Array(referencesStops.values),
            "trips": [tripDict],
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

    // MARK: - Single Arrival and Departure for Stop
    public static func arrivalAndDepartureForStopResponse(
        stop: TransitStop,
        arrival: TransitArrival,
        requestedStopID: String? = nil,
        currentTime: Date = Date()
    ) -> [String: Any] {
        let stopDict = serializeStop(stop, overrideID: requestedStopID)
        let scopedRouteId = MOTIdentityFormatter.scopedRouteID(id: arrival.routeID)

        let routeDict: [String: Any] = [
            "id": scopedRouteId,
            "agencyId": arrival.agencyID.map { MOTIdentityFormatter.scopedAgencyID(id: $0) } ?? "mot:agency:1",
            "shortName": arrival.lineName,
            "longName": arrival.destination,
            "description": arrival.destination,
            "type": 3,
            "url": ""
        ]

        let agencyDict = serializeAgency(
            id: arrival.agencyID ?? MOTAgencyID(rawValue: 1),
            name: arrival.agencyName ?? "משרד התחבורה"
        )

        let tripInstanceSuffix: String = {
            if let staticId = arrival.staticTripId, !staticId.isEmpty {
                return staticId
            }
            if let tripIdToDate = arrival.tripIdToDate {
                return "\(tripIdToDate)"
            }
            let schedSec = Int(arrival.scheduledTime.timeIntervalSince1970)
            return "\(schedSec)"
        }()
        let tripId = MOTIdentityFormatter.scopedTripID(routeID: arrival.routeID, suffix: tripInstanceSuffix)
        let shapeId = MOTIdentityFormatter.scopedShapeID(routeID: arrival.routeID)

        let tripDict: [String: Any] = [
            "id": tripId,
            "routeId": scopedRouteId,
            "serviceId": "mot:service:default",
            "tripHeadsign": arrival.destination,
            "tripShortName": arrival.lineName,
            "routeShortName": arrival.lineName,
            "directionId": "0",
            "blockId": "mot:block:\(arrival.routeID.rawValue)",
            "shapeId": shapeId,
            "timeZone": "Asia/Jerusalem"
        ]

        var calendar = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "Asia/Jerusalem") {
            calendar.timeZone = tz
        }
        let serviceDateMs = Int(calendar.startOfDay(for: arrival.scheduledTime).timeIntervalSince1970 * 1000)
        let schedMs = Int(arrival.scheduledTime.timeIntervalSince1970 * 1000)
        let predMs = arrival.isRealTime ? arrival.estimatedTime.map { Int($0.timeIntervalSince1970 * 1000) } : nil

        var entry: [String: Any] = [
            "routeId": scopedRouteId,
            "routeShortName": arrival.lineName,
            "routeLongName": arrival.destination,
            "tripId": tripId,
            "tripHeadsign": arrival.destination,
            "stopId": stopDict["id"] as! String,
            "stopSequence": arrival.stopSequence ?? 1,
            "scheduledArrivalTime": schedMs,
            "scheduledDepartureTime": schedMs,
            "predicted": arrival.isRealTime,
            "lastUpdateTime": Int(currentTime.timeIntervalSince1970 * 1000),
            "vehicleId": arrival.staticTripId ?? "",
            "serviceDate": serviceDateMs,
            "distanceFromStop": -1.0,
            "numberOfStopsAway": -1,
            "status": arrival.isRealTime ? "default" : "scheduled",
            "arrivalEnabled": true,
            "departureEnabled": true,
            "blockTripSequence": 1,
            "situationIds": []
        ]

        if let tripStatus = serializeTripStatus(
            arrival: arrival,
            tripId: tripId,
            stopId: stopDict["id"] as! String,
            serviceDateMs: serviceDateMs,
            currentTime: currentTime
        ) {
            entry["tripStatus"] = tripStatus
        }

        if let predMs = predMs {
            entry["predictedArrivalTime"] = predMs
            entry["predictedDepartureTime"] = predMs
        }

        let references: [String: Any] = [
            "agencies": [agencyDict],
            "routes": [routeDict],
            "stops": [stopDict],
            "trips": [tripDict],
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

        struct ScheduledTrip {
            let tripID: String
            let startSeconds: Int
        }

        var scheduledTrips: [ScheduledTrip] = []

        if let departures = departures, !departures.isEmpty {
            for (idx, dep) in departures.enumerated() {
                let tripId = dep.tripId ?? "mot:trip:\(route.routeID.rawValue)_\(idx)"
                var sec: Int? = nil
                if let str = dep.departureTimeString ?? dep.departureTime {
                    let parts = str.split(separator: ":").compactMap { Int($0) }
                    if parts.count >= 2 {
                        sec = parts[0] * 3600 + parts[1] * 60 + (parts.count >= 3 ? parts[2] : 0)
                    }
                }
                if let validSec = sec {
                    scheduledTrips.append(ScheduledTrip(tripID: tripId, startSeconds: validSec))
                }
            }
        }
        // NOTE: Truth-first schedule policy. Zero fabricated departures when departures is nil or empty.

        var tripsWithStopTimes: [[String: Any]] = []
        var tripReferences: [[String: Any]] = []
        var tripIds: [String] = []

        for trip in scheduledTrips {
            tripIds.append(trip.tripID)

            var stopTimes: [[String: Any]] = []
            for (stopIdx, stopId) in stopIds.enumerated() {
                var stopTimeDict: [String: Any] = [
                    "stopId": stopId,
                    "tripId": trip.tripID,
                    "arrivalEnabled": true,
                    "departureEnabled": true,
                    "serviceId": "mot:service:regular",
                    "stopHeadsign": headsign,
                    "stopSequence": stopIdx
                ]
                // Truth-first policy: only the initial departure has an authoritative departure time from DailyCalendar.
                // Do NOT synthesize artificial 90-second delays or clamp overnight trips to 86399.
                if stopIdx == 0 {
                    stopTimeDict["arrivalTime"] = trip.startSeconds
                    stopTimeDict["departureTime"] = trip.startSeconds
                } else {
                    stopTimeDict["arrivalTime"] = -1
                    stopTimeDict["departureTime"] = -1
                }
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
            "tripHeadsigns": scheduledTrips.isEmpty ? [] : [headsign],
            "tripIds": tripIds,
            "tripsWithStopTimes": tripsWithStopTimes
        ]

        let entry: [String: Any] = [
            "routeId": routeDict["id"] as! String,
            "scheduleDate": scheduleDateMs,
            "serviceIds": scheduledTrips.isEmpty ? [] : ["mot:service:regular"],
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
        let colors = MOTAgencyColorResolver.resolve(agencyID: route.agencyID, customColor: nil)
        return [
            "id": scopedId,
            "agencyId": agencyId,
            "shortName": route.lineName,
            "longName": route.destinationName ?? route.lineName,
            "description": route.destinationName ?? "",
            "type": 3, // Bus
            "color": colors.colorHex,
            "textColor": colors.textColorHex,
            "url": ""
        ]
    }

    private static func serializeRoute(_ route: TransitRoute) -> [String: Any] {
        let scopedId = MOTIdentityFormatter.scopedRouteID(id: route.routeID)
        let agencyId = MOTIdentityFormatter.scopedAgencyID(id: route.agencyID)
        let colors = MOTAgencyColorResolver.resolve(agencyID: route.agencyID, customColor: nil)
        return [
            "id": scopedId,
            "agencyId": agencyId,
            "shortName": route.lineName,
            "longName": route.longName ?? route.lineName,
            "description": route.longName ?? "",
            "type": 3, // Bus
            "color": colors.colorHex,
            "textColor": colors.textColorHex,
            "url": ""
        ]
    }

    public static func serializeTripStatus(
        arrival: TransitArrival,
        tripId: String,
        stopId: String,
        serviceDateMs: Int,
        currentTime: Date = Date()
    ) -> [String: Any]? {
        guard arrival.isRealTime, let loc = arrival.vehicleLocation else { return nil }
        guard loc.latitude.isFinite, loc.longitude.isFinite else { return nil }
        guard !(abs(loc.latitude) < 0.001 && abs(loc.longitude) < 0.001) else { return nil }
        // Service boundary for State of Israel
        guard loc.latitude >= 29.0 && loc.latitude <= 33.5 && loc.longitude >= 34.0 && loc.longitude <= 36.0 else {
            return nil
        }

        let nowMs = Int(currentTime.timeIntervalSince1970 * 1000)
        return [
            "activeTripId": tripId,
            "blockTripSequence": 1,
            "closestStop": stopId,
            "closestStopTimeOffset": 0,
            "distanceAlongTrip": 0.0,
            "lastLocationUpdateTime": Int64(nowMs),
            "lastUpdateTime": nowMs,
            "nextStopTimeOffset": 0,
            "orientation": 0.0,
            "phase": "in_progress",
            "position": [
                "lat": loc.latitude,
                "lon": loc.longitude
            ],
            "predicted": true,
            "scheduleDeviation": 0,
            "scheduledDistanceAlongTrip": 0.0,
            "serviceDate": serviceDateMs,
            "situationIds": [] as [String],
            "status": "default",
            "totalDistanceAlongTrip": 0.0,
            "vehicleId": arrival.staticTripId ?? ""
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
