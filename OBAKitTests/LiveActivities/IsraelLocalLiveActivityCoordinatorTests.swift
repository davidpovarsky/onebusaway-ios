//
//  IsraelLocalLiveActivityCoordinatorTests.swift
//  OBAKitTests
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import Testing
import ActivityKit
@testable import OBAKit
@testable import OBAKitCore

@MainActor
@Suite(.serialized)
struct IsraelLocalLiveActivityCoordinatorTests {

    @Test
    func testTrackedActivityContextCodableRoundTrip() throws {
        let original = IsraelTrackedActivityContext(
            activityID: "act_12345",
            stopID: "5130",
            routeShortName: "71",
            routeHeadsign: "רמות",
            tripID: "trip_999",
            lastDepartureTime: 1774051200,
            lastUpdateTime: Date(timeIntervalSince1970: 1774050000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IsraelTrackedActivityContext.self, from: data)

        #expect(decoded.activityID == original.activityID)
        #expect(decoded.stopID == original.stopID)
        #expect(decoded.routeShortName == original.routeShortName)
        #expect(decoded.routeHeadsign == original.routeHeadsign)
        #expect(decoded.tripID == original.tripID)
        #expect(decoded.lastDepartureTime == original.lastDepartureTime)
    }

    @Test
    func testCoordinatorReconcileCleansUpDeadContexts() throws {
        let userDefaults = UserDefaults(suiteName: "test.israel.live_activities.\(UUID().uuidString)")!
        let context = IsraelTrackedActivityContext(
            activityID: "dead_activity_999",
            stopID: "5130",
            routeShortName: "71",
            routeHeadsign: "רמות",
            tripID: "trip_1"
        )
        let data = try JSONEncoder().encode([context])
        userDefaults.set(data, forKey: "org.onebusaway.israel.live_activities.tracked")

        let coordinator = IsraelLocalLiveActivityCoordinator(
            apiServiceProvider: { nil },
            userDefaults: userDefaults
        )

        // Since dead_activity_999 is not in Activity<TripAttributes>.activities, reconcile removes it
        #expect(!coordinator.isTracking(activityID: "dead_activity_999"))
        #expect(coordinator.trackedContexts.isEmpty)
    }

    @Test
    func testRefreshWithNilAPIServiceDoesNotCrash() async {
        let userDefaults = UserDefaults(suiteName: "test.israel.live_activities.\(UUID().uuidString)")!
        let coordinator = IsraelLocalLiveActivityCoordinator(
            apiServiceProvider: { nil },
            userDefaults: userDefaults
        )

        await coordinator.refreshTrackedActivities()
        #expect(coordinator.trackedContexts.isEmpty)
    }

    @Test
    func testLifecycleServiceInitializationAndDiagnostics() {
        let service = IsraelActivityLifecycleService.shared
        service.configure(apiServiceProvider: { nil })

        #expect(service.localCoordinator != nil)
        #expect(service.trackingCoordinator != nil)

        let snapshot = IsraelActivityDiagnostics.shared.snapshot(
            trackedCount: 0,
            isBackgroundTrackingActive: false,
            tripID: nil,
            stopID: nil
        )
        #expect(snapshot.trackedCount == 0)
        #expect(snapshot.isBackgroundTrackingActive == false)
    }
}
