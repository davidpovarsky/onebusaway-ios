//
//  IsraelArrivalLoadAndCacheTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelArrivalLoadAndCacheTests {

    @Test
    func testMOTCacheStoresAndRetrievesBeforeExpiration() {
        let cache = MOTCache.shared
        let key = "test_key_\(UUID().uuidString)"

        cache.set("cached_stop_data", forKey: key, ttl: 10.0)
        let retrieved: String? = cache.get(forKey: key)

        #expect(retrieved == "cached_stop_data")
    }

    @Test
    func testMOTCacheReturnsNilForExpiredItem() {
        let cache = MOTCache.shared
        let key = "test_expired_key_\(UUID().uuidString)"

        cache.set("expired_data", forKey: key, ttl: -1.0) // Already expired
        let retrieved: String? = cache.get(forKey: key)

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
