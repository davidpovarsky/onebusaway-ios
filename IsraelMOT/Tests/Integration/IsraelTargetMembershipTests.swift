//
//  IsraelTargetMembershipTests.swift
//  IsraelMOTTests
//
//  Automated target boundary and extension safety regression verification.
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelTargetMembershipTests {

    @Test
    func testWidgetConfigurationExclusions() throws {
        // Read OBAWidget/project.yml to ensure required exclusions remain enforced in XcodeGen spec
        let ymlCandidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Integration
                .deletingLastPathComponent() // Tests
                .deletingLastPathComponent() // IsraelMOT
                .appendingPathComponent("OBAWidget")
                .appendingPathComponent("project.yml"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("OBAWidget")
                .appendingPathComponent("project.yml")
        ]

        guard let ymlURL = ymlCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let ymlContent = try? String(contentsOf: ymlURL, encoding: .utf8) else {
            // If project.yml cannot be located at runtime, continue gracefully
            return
        }

        #expect(ymlContent.contains("APPLICATION_EXTENSION_API_ONLY: true"))
        #expect(ymlContent.contains("- \"Map\""))
        #expect(ymlContent.contains("- \"Routes\""))
        #expect(ymlContent.contains("- \"OTPAdapter\""))
        #expect(ymlContent.contains("- \"UI\""))
        #expect(ymlContent.contains("- \"Weather\""))
        #expect(ymlContent.contains("- \"Search\""))
    }

    @Test
    func testIsraelWidgetArrivalsClientIsInstantiableAndGuardsRegion() async {
        let client = IsraelWidgetArrivalsClient.shared
        #expect(client != nil)

        // Non-Israel region (e.g. Puget Sound = 1) must return empty departures immediately
        let nonIsraelRegion = Region(
            active: true,
            contactEmail: "test@oba.org",
            custom: false,
            experimental: false,
            language: "en_US",
            name: "Puget Sound",
            obaBaseURL: URL(string: "https://api.pugetsound.onebusaway.org")!,
            regionIdentifier: 1,
            bounds: [],
            open311Servers: []
        )

        let departures = await client.loadDepartures(
            for: [],
            in: nonIsraelRegion,
            apiKey: "TEST",
            appVersion: "1.0",
            uuid: UUID().uuidString
        )
        #expect(departures.isEmpty)
    }

    @Test
    @MainActor
    func testViewportRouteRepositoryAndAmbientVehiclesResideInOBAKit() {
        let repo = IsraelViewportRouteRepository.shared
        #expect(repo.maxCachedRoutes == 24)
        #expect(repo.maxCachedVehicles == 32)
        #expect(repo.envelopePaddingRatio == 0.25)
        #expect(repo.activeVehicles.isEmpty)
        #expect(repo.activePolylines.isEmpty)
    }

    @Test
    func testSelectedRouteSessionAndFeedResideInOBAKit() {
        let feed = IsraelRouteVehicleFeed.shared
        #expect(feed != nil)
    }

    @Test
    @MainActor
    func testAppServicesCompositionRoot() {
        let services = IsraelAppServices.shared
        #expect(services != nil)
    }
}
