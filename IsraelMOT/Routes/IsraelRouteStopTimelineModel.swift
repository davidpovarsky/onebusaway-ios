//
//  IsraelRouteStopTimelineModel.swift
//  IsraelMOT
//
//  Structured data models for Israeli route stop timeline rendering.
//

import Foundation
import CoreLocation
import OBAKitCore

public struct IsraelRouteStopItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let stopCode: String
    public let name: String
    public let subtitle: String
    public let sequence: Int
    public let coordinate: CLLocationCoordinate2D
    public let isFirstStop: Bool
    public let isLastStop: Bool
    public let isAccessible: Bool

    public init(
        id: String,
        stopCode: String,
        name: String,
        subtitle: String = "",
        sequence: Int,
        coordinate: CLLocationCoordinate2D,
        isFirstStop: Bool,
        isLastStop: Bool,
        isAccessible: Bool = true
    ) {
        self.id = id
        self.stopCode = stopCode
        self.name = name
        self.subtitle = subtitle
        self.sequence = sequence
        self.coordinate = coordinate
        self.isFirstStop = isFirstStop
        self.isLastStop = isLastStop
        self.isAccessible = isAccessible
    }

    public static func == (lhs: IsraelRouteStopItem, rhs: IsraelRouteStopItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.stopCode == rhs.stopCode &&
        lhs.sequence == rhs.sequence &&
        lhs.isFirstStop == rhs.isFirstStop &&
        lhs.isLastStop == rhs.isLastStop
    }
}

public enum IsraelRouteStopTimelineFactory {
    /// Builds an ordered list of timeline items from `StopsForRoute`.
    public static func makeTimeline(from stopsForRoute: StopsForRoute) -> [IsraelRouteStopItem] {
        guard let stops = stopsForRoute.stops, !stops.isEmpty else { return [] }
        let count = stops.count
        return stops.enumerated().map { index, stop in
            let code = stop.code.isEmpty ? stop.id.replacingOccurrences(of: "mot:stop:", with: "") : stop.code
            let isFirst = index == 0
            let isLast = index == count - 1
            let dir = Formatters.adjectiveFormOfCardinalDirection(stop.direction) ?? ""
            return IsraelRouteStopItem(
                id: stop.id,
                stopCode: code,
                name: stop.name,
                subtitle: dir,
                sequence: index + 1,
                coordinate: stop.coordinate,
                isFirstStop: isFirst,
                isLastStop: isLast,
                isAccessible: true
            )
        }
    }
}
