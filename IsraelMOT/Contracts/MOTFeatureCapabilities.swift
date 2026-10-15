//
//  MOTFeatureCapabilities.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Describes the verified capabilities and constraints of the Israel MOT backend.
public struct MOTFeatureCapabilities: Sendable {
    /// True if stop arrival predictions support real-time indicators per record.
    public let supportsPerRecordRealTime: Bool

    /// True if route full data provides exact map polyline geometry.
    public let supportsRouteGeometry: Bool

    /// True if native clients can call GetRoutes directly without F5 WAF proxying.
    public let supportsNativeTripPlanning: Bool

    /// True if bike share is supported. (MOT route site does not provide national bikeshare).
    public let supportsBikeshare: Bool

    /// True if real-time national vehicle fleet coordinates are available.
    public let supportsFleetTracking: Bool

    public static let current = MOTFeatureCapabilities(
        supportsPerRecordRealTime: true,
        supportsRouteGeometry: true,
        supportsNativeTripPlanning: false, // Blocked by F5 WAF on native HTTP POST without web gateway
        supportsBikeshare: false,
        supportsFleetTracking: false
    )
}
