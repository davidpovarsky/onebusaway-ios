//
//  TransitProviderRegistryTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (Multi-Provider Architecture)
//

import Foundation
import Testing
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct TransitProviderRegistryTests {

    @Test
    func testRegisteredProvidersList() {
        let registry = TransitProviderRegistry.shared
        let providers = registry.allProviders

        #expect(providers.count >= 3)
        let ids = Set(providers.map { $0.id })
        #expect(ids.contains(.israelMOT))
        #expect(ids.contains(.busNearby))
        #expect(ids.contains(.oneBusAwayNative))
    }

    @Test
    func testDefaultProviderIsIsraelMOT() {
        let registry = TransitProviderRegistry.shared
        let mot = registry.provider(for: .israelMOT)

        #expect(mot != nil)
        #expect(mot?.isAvailable == true)
        #expect(mot?.capabilities.mapViewportStops.isSupported == true)
        #expect(mot?.capabilities.planJourney.isSupported == true)
        #expect(mot?.capabilities.searchLines.isSupported == true)
    }

    @MainActor
    @Test
    func testBusNearbyIsFuturePlaceholderAndNotAvailable() async throws {
        let registry = TransitProviderRegistry.shared
        let busNearby = registry.provider(for: .busNearby)

        #expect(busNearby != nil)
        #expect(busNearby?.isAvailable == false)
        #expect(busNearby?.isExperimental == true)
        #expect(busNearby?.capabilities.planJourney.isSupported == false)

        // Verify selection store rejects activating unavailable provider
        let store = TransitProviderSelectionStore.shared
        let activated = store.selectProvider(.busNearby)
        #expect(activated == false)
        #expect(store.activeProviderID != .busNearby)
    }

    @MainActor
    @Test
    func testProviderSwitchingEndToEnd() async throws {
        let store = TransitProviderSelectionStore.shared

        // Initial default is Israel MOT
        #expect(store.activeProviderID == .israelMOT)
        #expect(TransitProviderSelectionStore.currentProviderID() == .israelMOT)

        // Switch to OneBusAway Native
        let switched = store.selectProvider(.oneBusAwayNative)
        #expect(switched == true)
        #expect(store.activeProviderID == .oneBusAwayNative)
        #expect(TransitProviderSelectionStore.currentProviderID() == .oneBusAwayNative)

        // Switch back to Israel MOT
        let restored = store.selectProvider(.israelMOT)
        #expect(restored == true)
        #expect(store.activeProviderID == .israelMOT)
        #expect(TransitProviderSelectionStore.currentProviderID() == .israelMOT)
    }

    @Test
    func testCapabilityStatusInspection() {
        let motCaps = TransitProviderCapabilities.israelMOT
        #expect(motCaps.nearbyStops.isSupported)
        #expect(motCaps.mapViewportStops.isSupported)
        #expect(motCaps.searchLines.isSupported)
        #expect(motCaps.predictions.isSupported)

        if case .degraded(let reason) = motCaps.vehicleLocations {
            #expect(!reason.isEmpty)
        } else {
            Issue.record("Expected vehicleLocations to be degraded with note")
        }
    }
}
