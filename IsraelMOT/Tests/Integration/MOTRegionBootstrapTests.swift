//
//  MOTRegionBootstrapTests.swift
//  IsraelMOTTests
//
//  Regression: the installed Israel build must not revert to MTA New York
//  just because the public OBA regions endpoint does not list Israel.
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
final class MOTRegionBootstrapTests: OBATestCase {

    @Test
    func testStoredUSRegionsRestoreBundledIsraelAndRepairWrongSelection() throws {
        let remoteUSRegions = try Fixtures.loadSomeRegions()
        #expect(remoteUSRegions.contains { $0.regionIdentifier == 2 })

        let storedRegions = MockRegionsFileStorage(defaultRegions: remoteUSRegions)
        userDefaults.set(2, forKey: RegionsService.currentRegionIdentifierUserDefaultsKey)

        let location = LocationService(
            userDefaults: userDefaults,
            locationManager: LocationManagerMock()
        )
        let service = RegionsService(
            apiService: nil,
            locationService: location,
            userDefaults: userDefaults,
            bundledRegionsFilePath: bundledRegionsPath,
            apiPath: nil,
            fileStorage: storedRegions,
            fixedRegionName: "Israel",
            pinnedBundledRegionIdentifiers: [972]
        )

        #expect(service.regions.contains { $0.regionIdentifier == 972 })
        #expect(service.currentRegion?.regionIdentifier == 972)
        #expect(service.automaticallySelectRegion)

        // Once an explicit manual selection is made, the one-time repair does
        // not override it on every subsequent launch.
        let manualChoice = try #require(service.regions.first { $0.regionIdentifier == 1 })
        service.currentRegion = manualChoice
        let secondLaunch = RegionsService(
            apiService: nil,
            locationService: location,
            userDefaults: userDefaults,
            bundledRegionsFilePath: bundledRegionsPath,
            apiPath: nil,
            fileStorage: storedRegions,
            fixedRegionName: "Israel",
            pinnedBundledRegionIdentifiers: [972]
        )
        #expect(secondLaunch.currentRegion?.regionIdentifier == 1)
    }

    @Test
    func testRemoteRefreshCannotRemovePinnedIsrael() async throws {
        let remoteUSRegions = try Fixtures.loadSomeRegions()
        let storedRegions = MockRegionsFileStorage(defaultRegions: remoteUSRegions)
        let loader = try #require(regionsAPIService.dataLoader as? MockDataLoader)
        stubRegionsJustPugetSound(dataLoader: loader)

        let location = LocationService(
            userDefaults: userDefaults,
            locationManager: LocationManagerMock()
        )
        let service = RegionsService(
            apiService: regionsAPIService,
            locationService: location,
            userDefaults: userDefaults,
            bundledRegionsFilePath: bundledRegionsPath,
            apiPath: regionsAPIPath,
            fileStorage: storedRegions,
            fixedRegionName: "Israel",
            pinnedBundledRegionIdentifiers: [972]
        )

        try await service.refreshRegions()
        #expect(service.regions.contains { $0.regionIdentifier == 972 })
        #expect(service.regions.contains { $0.regionIdentifier == 1 })
        #expect(storedRegions.storedDefaultRegions?.contains { $0.regionIdentifier == 972 } == true)
    }
}
