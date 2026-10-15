//
//  MOTCache.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

public actor MOTCache {
    private struct Entry<T> {
        let value: T
        let expiration: Date
    }

    private var stops: [MOTStopCode: Entry<TransitStop>] = [:]
    private var routes: [MOTRouteID: Entry<TransitRoute>] = [:]
    private var arrivals: [MOTStopCode: Entry<[TransitArrival]>] = [:]

    public init() {}

    public func getStop(code: MOTStopCode) -> TransitStop? {
        guard let entry = stops[code], entry.expiration > Date() else {
            stops.removeValue(forKey: code)
            return nil
        }
        return entry.value
    }

    public func setStop(_ stop: TransitStop, code: MOTStopCode, ttl: TimeInterval = 300) {
        stops[code] = Entry(value: stop, expiration: Date().addingTimeInterval(ttl))
    }

    public func getRoute(id: MOTRouteID) -> TransitRoute? {
        guard let entry = routes[id], entry.expiration > Date() else {
            routes.removeValue(forKey: id)
            return nil
        }
        return entry.value
    }

    public func setRoute(_ route: TransitRoute, id: MOTRouteID, ttl: TimeInterval = 3600) {
        routes[id] = Entry(value: route, expiration: Date().addingTimeInterval(ttl))
    }

    public func getArrivals(stopCode: MOTStopCode) -> [TransitArrival]? {
        guard let entry = arrivals[stopCode], entry.expiration > Date() else {
            arrivals.removeValue(forKey: stopCode)
            return nil
        }
        return entry.value
    }

    public func setArrivals(_ list: [TransitArrival], stopCode: MOTStopCode, ttl: TimeInterval = 30) {
        arrivals[stopCode] = Entry(value: list, expiration: Date().addingTimeInterval(ttl))
    }

    public func clearAll() {
        stops.removeAll()
        routes.removeAll()
        arrivals.removeAll()
    }
}
