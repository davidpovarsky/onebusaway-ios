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
    func testOutdatedStoredIsraelDefinitionIsReplacedAtLaunch() throws {
        let bundledData = try Data(contentsOf: URL(fileURLWithPath: bundledRegionsPath))
        let bundled = try JSONDecoder.RESTDecoder().decode(
            RESTAPIResponse<[Region]>.self, from: bundledData
        )
        let canonicalIsrael = try #require(bundled.list.first { $0.regionIdentifier == 972 })
        #expect(canonicalIsrael.sidecarBaseURL == nil)

        // Simulate the prior IPA's cached region 972 with its invalid Obaco URL.
        let encoded = try JSONEncoder().encode(canonicalIsrael)
        var oldJSON = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        oldJSON["sidecarBaseUrl"] = "https://api.bus.gov.il/prod"
        oldJSON["otpBaseUrl"] = "https://api.bus.gov.il/prod/RoutePlanning/GetRoutes"
        let oldData = try JSONSerialization.data(withJSONObject: oldJSON)
        let staleIsrael = try JSONDecoder().decode(Region.self, from: oldData)
        #expect(staleIsrael.sidecarBaseURL != nil)

        let storage = MockRegionsFileStorage(defaultRegions: [staleIsrael])
        let location = LocationService(
            userDefaults: userDefaults,
            locationManager: LocationManagerMock()
        )
        userDefaults.set(972, forKey: RegionsService.currentRegionIdentifierUserDefaultsKey)
        let service = RegionsService(
            apiService: nil,
            locationService: location,
            userDefaults: userDefaults,
            bundledRegionsFilePath: bundledRegionsPath,
            apiPath: nil,
            fileStorage: storage,
            fixedRegionName: "Israel",
            pinnedBundledRegionIdentifiers: [972]
        )
        let selected = try #require(service.currentRegion)
        #expect(selected.regionIdentifier == 972)
        #expect(selected.sidecarBaseURL == nil)
        #expect(selected.openTripPlannerURL?.absoluteString.contains("route-planner-prod/api/") == true)
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
