//
//  IsraelTripBackgroundTrackingCoordinator.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import CoreLocation
import Foundation
import UIKit
import OBAKitCore

public protocol TripLocationManagerProtocol: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var activityType: CLActivityType { get set }
    var allowsBackgroundLocationUpdates: Bool { get set }
    var pausesLocationUpdatesAutomatically: Bool { get set }
    var showsBackgroundLocationIndicator: Bool { get set }
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: TripLocationManagerProtocol {}

@MainActor
public final class IsraelTripBackgroundTrackingCoordinator: NSObject, CLLocationManagerDelegate {

    public private(set) var isActive = false
    public private(set) var currentTripID: String?
    public private(set) var currentStopID: String?

    private let locationManager: TripLocationManagerProtocol
    private weak var liveActivityCoordinator: IsraelLocalLiveActivityCoordinator?

    private var lastRefreshTime: Date?
    private var lastRefreshLocation: CLLocation?
    private var sessionStartTime: Date?
    private let maxSessionDuration: TimeInterval = 7200 // 2 hours failsafe
    private let minimumRefreshInterval: TimeInterval = 25.0 // Throttling: min 25s
    private let distanceRefreshThreshold: CLLocationDistance = 100.0 // Or 100m moved

    #if !targetEnvironment(simulator)
    private var backgroundActivitySession: Any? // CLBackgroundActivitySession on iOS 17+
    #endif

    public init(
        locationManager: TripLocationManagerProtocol = CLLocationManager(),
        liveActivityCoordinator: IsraelLocalLiveActivityCoordinator? = nil
    ) {
        self.locationManager = locationManager
        self.liveActivityCoordinator = liveActivityCoordinator
        super.init()
        self.locationManager.delegate = self
        self.liveActivityCoordinator?.onAllActivitiesEnded = { [weak self] in
            self?.stopActiveTripSession()
        }
        self.liveActivityCoordinator?.onActivityTracked = { [weak self] ctx in
            self?.startActiveTripSession(tripID: ctx.tripID, stopID: ctx.stopID)
        }
    }

    public func startActiveTripSession(
        tripID: String?,
        stopID: String?
    ) {
        self.currentTripID = tripID
        self.currentStopID = stopID
        self.isActive = true
        self.sessionStartTime = Date()
        self.lastRefreshTime = nil
        self.lastRefreshLocation = nil

        // Configure manager for navigation tracking
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true

        locationManager.allowsBackgroundLocationUpdates = true

        #if !targetEnvironment(simulator)
        if #available(iOS 17.0, *) {
            self.backgroundActivitySession = CLBackgroundActivitySession()
        }
        #endif

        locationManager.startUpdatingLocation()

        // Acquire screen awake lease
        ScreenAwakeCoordinator.shared.acquire(owner: ObjectIdentifier(self))
        Logger.info("IsraelTripBackgroundTrackingCoordinator: started active trip session for trip \(tripID ?? "nil") stop \(stopID ?? "nil").")
    }

    public func stopActiveTripSession() {
        guard isActive else { return }
        isActive = false
        currentTripID = nil
        currentStopID = nil
        sessionStartTime = nil

        locationManager.stopUpdatingLocation()

        #if !targetEnvironment(simulator)
        if #available(iOS 17.0, *) {
            if let session = backgroundActivitySession as? CLBackgroundActivitySession {
                session.invalidate()
            }
            backgroundActivitySession = nil
        }
        #endif

        // Release screen awake lease
        ScreenAwakeCoordinator.shared.release(owner: ObjectIdentifier(self))
        Logger.info("IsraelTripBackgroundTrackingCoordinator: stopped active trip session.")
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isActive else { return }

        // Check failsafe session duration
        if let start = sessionStartTime, Date().timeIntervalSince(start) > maxSessionDuration {
            Logger.warn("IsraelTripBackgroundTrackingCoordinator: session exceeded max duration 2h; stopping.")
            stopActiveTripSession()
            return
        }

        // Find best recent fix
        guard let location = locations.last(where: {
            $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 30.0
        }) else {
            return
        }

        // Renew screen awake lease in foreground
        ScreenAwakeCoordinator.shared.renew(owner: ObjectIdentifier(self))

        // Check throttle: time elapsed or significant distance moved
        let now = Date()
        let shouldRefresh: Bool
        if let lastTime = lastRefreshTime {
            let timeElapsed = now.timeIntervalSince(lastTime)
            if timeElapsed >= minimumRefreshInterval {
                shouldRefresh = true
            } else if let lastLoc = lastRefreshLocation, location.distance(from: lastLoc) >= distanceRefreshThreshold {
                shouldRefresh = true
            } else {
                shouldRefresh = false
            }
        } else {
            shouldRefresh = true
        }

        guard shouldRefresh else { return }

        lastRefreshTime = now
        lastRefreshLocation = location

        Logger.info("IsraelTripBackgroundTrackingCoordinator: throttled background location update (accuracy: \(location.horizontalAccuracy)m). Refreshing tracked activities.")

        Task { [weak self] in
            await self?.liveActivityCoordinator?.refreshTrackedActivities()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.error("IsraelTripBackgroundTrackingCoordinator location error: \(error)")
    }
}
