//
//  IsraelActivityLifecycleService.swift
//  OBAKit
//
//  Unified orchestration and lifecycle management for Israeli Live Activities and background tracking.
//

import Foundation
import ActivityKit
import CoreLocation
import OBAKitCore

@MainActor
public final class IsraelActivityLifecycleService: ObservableObject {
    public static let shared = IsraelActivityLifecycleService()

    public private(set) var localCoordinator: IsraelLocalLiveActivityCoordinator?
    public private(set) var trackingCoordinator: IsraelTripBackgroundTrackingCoordinator?

    private var isConfigured = false

    public init() {}

    /// Configures the unified coordinators and wires their bidirectional lifecycle callbacks.
    public func configure(
        apiServiceProvider: @escaping () -> RESTAPIService?,
        userDefaults: UserDefaults = .standard,
        locationManager: TripLocationManagerProtocol = CLLocationManager()
    ) {
        guard !isConfigured else { return }

        let local = IsraelLocalLiveActivityCoordinator(
            apiServiceProvider: apiServiceProvider,
            userDefaults: userDefaults
        )

        let tracking = IsraelTripBackgroundTrackingCoordinator(
            locationManager: locationManager,
            liveActivityCoordinator: local
        )

        // Ensure tracking coordinator is wired
        local.onActivityTracked = { [weak tracking] ctx in
            IsraelActivityDiagnostics.shared.recordEvent("Activity tracked: ID=\(ctx.activityID), trip=\(ctx.tripID), stop=\(ctx.stopID)")
            tracking?.startActiveTripSession(tripID: ctx.tripID, stopID: ctx.stopID)
        }

        local.onAllActivitiesEnded = { [weak tracking] in
            IsraelActivityDiagnostics.shared.recordEvent("All activities ended. Stopping background session.")
            tracking?.stopActiveTripSession()
        }

        self.localCoordinator = local
        self.trackingCoordinator = tracking
        self.isConfigured = true

        // Reconcile and wake tracking if activities were already active
        local.reconcileRunningActivities()
        if let firstContext = local.trackedContexts.values.first {
            IsraelActivityDiagnostics.shared.recordEvent("Reconciled existing activity: waking background session for trip \(firstContext.tripID)")
            tracking.startActiveTripSession(tripID: firstContext.tripID, stopID: firstContext.stopID)
        }
    }

    /// Unified track call used by StopPage, TripPage, and Bookmarks.
    public func startTracking(
        activity: Activity<TripAttributes>,
        departure: ArrivalDeparture? = nil,
        arrivalDepartures: [ArrivalDeparture] = []
    ) {
        guard let local = localCoordinator else {
            Logger.error("IsraelActivityLifecycleService not configured before tracking.")
            return
        }

        if !arrivalDepartures.isEmpty {
            local.track(activity: activity, arrivalDepartures: arrivalDepartures)
        } else {
            local.track(activity: activity, departure: departure)
        }

        // Direct guarantee of background session start
        let staticData = activity.attributes.staticData
        let resolvedTripID = !staticData.tripID.isEmpty ? staticData.tripID : (departure?.tripID ?? "")
        let resolvedStopID = !staticData.stopID.isEmpty ? staticData.stopID : (departure?.stopID ?? "")
        trackingCoordinator?.startActiveTripSession(tripID: resolvedTripID, stopID: resolvedStopID)
    }

    /// Legacy bridge accessors for backwards compatibility with existing properties and tests.
    public func legacyLocalCoordinator(
        apiServiceProvider: @escaping () -> RESTAPIService?,
        userDefaults: UserDefaults = .standard
    ) -> IsraelLocalLiveActivityCoordinator {
        if let local = localCoordinator {
            return local
        }
        configure(apiServiceProvider: apiServiceProvider, userDefaults: userDefaults)
        return localCoordinator!
    }

    public var legacyTrackingCoordinator: IsraelTripBackgroundTrackingCoordinator {
        if let tracking = trackingCoordinator {
            return tracking
        }
        configure(apiServiceProvider: { nil })
        return trackingCoordinator!
    }
}
