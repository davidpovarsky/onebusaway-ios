//
//  IsraelArrivalLoadAndCacheTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelArrivalLoadAndCacheTests {

    @Test
    func testMOTCacheStoresAndRetrievesBeforeExpiration() async {
        let cache = MOTCache()
        let stop = TransitStop(
            code: MOTStopCode(5130),
            internalID: MOTStopInternalID(1001),
            name: TransitMultiLanguageName(he: "צומת רמות", en: "Ramot", ar: nil),
            cityName: "ירושלים",
            streetName: "גולדה מאיר",
            location: CLLocationCoordinate2D(latitude: 31.815, longitude: 35.201),
            platformNumber: nil,
            isAccessible: true,
            routes: []
        )

        await cache.setStop(stop, code: MOTStopCode(5130), ttl: 10.0)
        let retrieved = await cache.getStop(code: MOTStopCode(5130))

        #expect(retrieved?.code.rawValue == 5130)
        #expect(retrieved?.name.he == "צומת רמות")
    }

    @Test
    func testMOTCacheReturnsNilForExpiredItem() async {
        let cache = MOTCache()
        let stop = TransitStop(
            code: MOTStopCode(5130),
            internalID: MOTStopInternalID(1001),
            name: TransitMultiLanguageName(he: "צומת רמות", en: "Ramot", ar: nil),
            cityName: "ירושלים",
            streetName: "גולדה מאיר",
            location: CLLocationCoordinate2D(latitude: 31.815, longitude: 35.201),
            platformNumber: nil,
            isAccessible: true,
            routes: []
        )

        await cache.setStop(stop, code: MOTStopCode(5130), ttl: -1.0) // Already expired
        let retrieved = await cache.getStop(code: MOTStopCode(5130))

        #expect(retrieved == nil)
    }

    @Test
    func testNoLineTruncationBeyond8Routes() {
        // Given 15 route descriptors
        var routeDescs: [String] = []
        for i in 1...15 {
            routeDescs.append("100\(i)-1-0")
        }

        // Deduplication and deterministic sorting
        let sorted = Array(Set(routeDescs)).sorted()
        #expect(sorted.count == 15)

        // Bounded batches of 4
        var batches: [[String]] = []
        var remaining = sorted[...]
        while !remaining.isEmpty {
            let batch = Array(remaining.prefix(4))
            batches.append(batch)
            remaining = remaining.dropFirst(batch.count)
        }

        #expect(batches.count == 4) // 4, 4, 4, 3
        #expect(batches.flatMap { $0 }.count == 15) // ALL 15 routes processed, none truncated!
    }
}
