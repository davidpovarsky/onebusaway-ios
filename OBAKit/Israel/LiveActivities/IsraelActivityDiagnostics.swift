//
//  IsraelActivityDiagnostics.swift
//  OBAKit
//
//  Diagnostic recorder and verification telemetry for Israel Live Activities.
//

import Foundation
import ActivityKit
import OBAKitCore
import OBAKitCoreiOS

public struct IsraelActivityDiagnosticsSnapshot: Sendable, Codable {
    public let timestamp: Date
    public let isAuthorized: Bool
    public let activeCount: Int
    public let trackedCount: Int
    public let isBackgroundTrackingActive: Bool
    public let currentTripID: String?
    public let currentStopID: String?
}

@MainActor
public final class IsraelActivityDiagnostics {
    public static let shared = IsraelActivityDiagnostics()

    private var recentEvents: [String] = []

    public init() {}

    public func recordEvent(_ message: String) {
        let entry = "[\(Date())] \(message)"
        recentEvents.append(entry)
        if recentEvents.count > 100 {
            recentEvents.removeFirst(recentEvents.count - 100)
        }
        Logger.info("[IsraelLiveActivity] \(message)")
    }

    public func snapshot(
        trackedCount: Int,
        isBackgroundTrackingActive: Bool,
        tripID: String?,
        stopID: String?
    ) -> IsraelActivityDiagnosticsSnapshot {
        let isAuth = ActivityAuthorizationInfo().areActivitiesEnabled
        let activeCount = Activity<TripAttributes>.activities.filter {
            $0.attributes.staticData.regionID == 972
        }.count

        return IsraelActivityDiagnosticsSnapshot(
            timestamp: Date(),
            isAuthorized: isAuth,
            activeCount: activeCount,
            trackedCount: trackedCount,
            isBackgroundTrackingActive: isBackgroundTrackingActive,
            currentTripID: tripID,
            currentStopID: stopID
        )
    }

    public func diagnosticSummary() -> [String] {
        recentEvents
    }
}
