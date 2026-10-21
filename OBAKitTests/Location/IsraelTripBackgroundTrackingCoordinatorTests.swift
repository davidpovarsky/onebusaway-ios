//
//  IsraelTripBackgroundTrackingCoordinatorTests.swift
//  OBAKitTests
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import Testing
import CoreLocation
import UIKit
@testable import OBAKit
@testable import OBAKitCore

@MainActor
final class MockTripLocationManager: NSObject, TripLocationManagerProtocol {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var activityType: CLActivityType = .other
    var allowsBackgroundLocationUpdates: Bool = false
    var pausesLocationUpdatesAutomatically: Bool = true
    var showsBackgroundLocationIndicator: Bool = false

    private(set) var startUpdatingCount = 0
    private(set) var stopUpdatingCount = 0

    func startUpdatingLocation() {
        startUpdatingCount += 1
    }

    func stopUpdatingLocation() {
        stopUpdatingCount += 1
    }

    func deliverLocations(_ locations: [CLLocation]) {
        delegate?.locationManager?(CLLocationManager(), didUpdateLocations: locations)
    }
}

@MainActor
@Suite(.serialized)
struct IsraelTripBackgroundTrackingCoordinatorTests {

    @Test
    func testStartActiveTripSessionConfiguresManagerAndScreenAwake() {
        ScreenAwakeCoordinator.shared.resetForTesting()
        let mockManager = MockTripLocationManager()
        let coordinator = IsraelTripBackgroundTrackingCoordinator(
            locationManager: mockManager,
            liveActivityCoordinator: nil
        )

        coordinator.startActiveTripSession(tripID: "trip_123", stopID: "stop_456")

        #expect(coordinator.isActive == true)
        #expect(coordinator.currentTripID == "trip_123")
        #expect(coordinator.currentStopID == "stop_456")
        #expect(mockManager.desiredAccuracy == kCLLocationAccuracyBestForNavigation)
        #expect(mockManager.activityType == .automotiveNavigation)
        #expect(mockManager.allowsBackgroundLocationUpdates == true)
        #expect(mockManager.pausesLocationUpdatesAutomatically == false)
        #expect(mockManager.showsBackgroundLocationIndicator == true)
        #expect(mockManager.startUpdatingCount == 1)
        #expect(ScreenAwakeCoordinator.shared.activeLeases == 1)

        coordinator.stopActiveTripSession()

        #expect(coordinator.isActive == false)
        #expect(coordinator.currentTripID == nil)
        #expect(coordinator.currentStopID == nil)
        #expect(mockManager.stopUpdatingCount == 1)
        #expect(ScreenAwakeCoordinator.shared.activeLeases == 0)

        ScreenAwakeCoordinator.shared.resetForTesting()
    }

    @Test
    func testLocationUpdateRenewsScreenAwakeLease() {
        ScreenAwakeCoordinator.shared.resetForTesting(failsafeInterval: 0.2)
        let mockManager = MockTripLocationManager()
        let coordinator = IsraelTripBackgroundTrackingCoordinator(
            locationManager: mockManager,
            liveActivityCoordinator: nil
        )

        coordinator.startActiveTripSession(tripID: "trip_123", stopID: "stop_456")
        let firstTimer = ScreenAwakeCoordinator.shared.armedFailsafe
        #expect(firstTimer != nil)

        // Deliver location
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 31.789, longitude: 35.204),
            altitude: 700,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: Date()
        )
        mockManager.deliverLocations([location])

        let renewedTimer = ScreenAwakeCoordinator.shared.armedFailsafe
        #expect(renewedTimer != nil)
        #expect(renewedTimer !== firstTimer)

        coordinator.stopActiveTripSession()
        ScreenAwakeCoordinator.shared.resetForTesting()
    }
}
