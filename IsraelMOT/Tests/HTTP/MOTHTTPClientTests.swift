//
//  MOTHTTPClientTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct MOTHTTPClientTests {

    @Test
    func testMOTEndpointsURLs() {
        let endpoints = MOTEndpoints()

        // 1. Stop full data URL
        let stopURL = endpoints.stopFullDataURL(stopCode: MOTStopCode(5997))
        #expect(stopURL.absoluteString.contains("StopData/GetStopFullData"))
        #expect(stopURL.absoluteString.contains("stopCode=5997"))

        // 2. Route full data URL
        let routeURL = endpoints.routeFullDataURL(routeID: MOTRouteID(33285))
        #expect(routeURL.absoluteString.contains("RouteData/GetRouteFullData"))
        #expect(routeURL.absoluteString.contains("routeId=33285"))

        // 3. Route stops URL
        let stopsURL = endpoints.routeStopsURL(routeID: MOTRouteID(33285))
        #expect(stopsURL.absoluteString.contains("RouteData/GetRouteStops"))
        #expect(stopsURL.absoluteString.contains("routeId=33285"))

        // 4. Search locations URL
        let searchURL = endpoints.searchLocationsURL(query: "ירושלים")
        #expect(searchURL.absoluteString.contains("AutoComplete/SearchLocations"))

        // 5. Trip planning URL
        let planningURL = endpoints.getRoutesURL()
        #expect(planningURL.absoluteString.contains("RoutePlanning/GetRoutes"))
    }

    @Test
    func testMOTBackoffIntervals() {
        let backoff = MOTBackoff(baseDelay: 0.5, maxDelay: 5.0)

        let d1 = backoff.delay(forAttempt: 1)
        let d2 = backoff.delay(forAttempt: 2)
        let d10 = backoff.delay(forAttempt: 10)

        #expect(d1 >= 0.5)
        #expect(d2 >= d1 || d2 > 0)
        #expect(d10 <= 5.5) // capped at maxDelay + jitter
    }

    @Test
    func testMOTCacheStoreAndRetrieve() async {
        let cache = MOTCache()
        let key = "test_key_1"
        let data = "sample_data".data(using: .utf8)!

        await cache.set(data, forKey: key, ttl: 60)
        let retrieved = await cache.get(forKey: key)
        #expect(retrieved == data)

        let missing = await cache.get(forKey: "non_existent_key")
        #expect(missing == nil)
    }

    @Test
    func testMOTIdentityStore() {
        let id1 = MOTIdentityStore.shared.anonymousDeviceID
        #expect(!id1.isEmpty)

        let id2 = MOTIdentityStore.shared.anonymousDeviceID
        #expect(id1 == id2)
    }

    @Test
    func testMOTHTTPErrorDescriptions() {
        let wafError = MOTHTTPError.wafBlocked(supportID: "test-support-1234")
        #expect(wafError.localizedDescription.contains("test-support-1234") || wafError.localizedDescription.contains("WAF"))

        let rateLimitError = MOTHTTPError.rateLimited(retryAfterSeconds: 30)
        #expect(rateLimitError.localizedDescription.contains("30") || rateLimitError.localizedDescription.contains("Rate"))
    }
}
