//
//  IsraelStopCatalogTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (Local Spatial Stop Catalog)
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelStopCatalogTests {

    @Test
    func testCatalogAvailabilityAndMetadata() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else {
            Issue.record("IsraelStopCatalogRepository is unavailable")
            return
        }

        let count = repo.totalStopCount()
        #expect(count > 30000, "Expected >30,000 stops nationwide, got \(count)")

        let meta = repo.metadata()
        #expect(meta["source"] == "GTFS-MOT")
        #expect(meta["schema_version"] == "1.0")
        #expect(meta["record_count"] != nil)
    }

    @Test
    func testKnownStop5997Lookup() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        let stop = repo.stop(forCode: MOTStopCode(5997))
        #expect(stop != nil)
        #expect(stop?.code.rawValue == 5997)
        #expect(stop?.internalID?.rawValue == 11622)
        #expect(stop?.name.he?.contains("סילבר") == true)
        #expect(abs((stop?.location.latitude ?? 0) - 31.815188) < 0.001)
        #expect(abs((stop?.location.longitude ?? 0) - 35.203022) < 0.001)
    }

    @Test
    func testKnownStop2899Lookup() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        let stop = repo.stop(forCode: MOTStopCode(2899))
        #expect(stop != nil)
        #expect(stop?.code.rawValue == 2899)
        #expect(stop?.internalID?.rawValue == 10168)
        #expect(stop?.name.he?.contains("בר לב") == true)
    }

    @Test
    func testSpatialBoundingBoxQueryJerusalemCenter() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        // Bounding box for central Jerusalem
        let stops = repo.stops(
            minLat: 31.78,
            maxLat: 31.82,
            minLon: 35.20,
            maxLon: 35.23,
            limit: 200
        )

        #expect(!stops.isEmpty)
        #expect(stops.count <= 200)

        // Verify all returned stops are strictly within the bounding box
        for stop in stops {
            #expect(stop.location.latitude >= 31.78 && stop.location.latitude <= 31.82)
            #expect(stop.location.longitude >= 35.20 && stop.location.longitude <= 35.23)
        }
    }

    @Test
    func testOutOfBoundsReturnsEmpty() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        // Far outside Israel (somewhere in the Atlantic Ocean)
        let stops = repo.stops(
            minLat: 0.0,
            maxLat: 1.0,
            minLon: 0.0,
            maxLon: 1.0,
            limit: 100
        )
        #expect(stops.isEmpty)
    }

    @Test
    func testAutocompleteSearchStops() {
        let repo = IsraelStopCatalogRepository.shared
        guard repo.isAvailable else { return }

        // Numeric search
        let numericResults = repo.searchStops(query: "5997", limit: 5)
        #expect(!numericResults.isEmpty)
        #expect(numericResults.first?.code.rawValue == 5997)

        // Name search
        let textResults = repo.searchStops(query: "סילבר", limit: 10)
        #expect(!textResults.isEmpty)
        for s in textResults {
            #expect(s.name.he?.contains("סילבר") == true)
        }
    }
}
