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
        #expect(stopURL.absoluteString.contains("Stops/GetStopFullData"))
        #expect(stopURL.absoluteString.contains("stopCode=5997"))

        // 2. Route full data URL
        let routeURL = endpoints.routeFullDataURL(routeID: MOTRouteID(33285))
        #expect(routeURL.absoluteString.contains("Routes/GetRouteFullData"))
        #expect(routeURL.absoluteString.contains("routeId=33285"))

        // 3. Route stops URL
        let stopsURL = endpoints.routeStopsURL(routeID: MOTRouteID(33285))
        #expect(stopsURL.absoluteString.contains("Routes/GetRouteStops"))
        #expect(stopsURL.absoluteString.contains("RouteId=33285"))

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

        #expect(d1 >= 0.35)
        #expect(d2 >= d1 || d2 > 0)
        #expect(d10 <= 6.5) // capped at maxDelay + jitter (5.0 * 1.2 = 6.0)
    }

    @Test
    func testMOTCacheStoreAndRetrieve() async {
        let cache = MOTCache()
        let stop = TransitStop(
            code: MOTStopCode(5997),
            internalID: MOTStopInternalID(11622),
            name: TransitMultiLanguageName(he: "שרי ישראל", en: "Sarei Yisrael", ar: nil),
            cityName: "ירושלים",
            streetName: "שרי ישראל",
            location: CLLocationCoordinate2D(latitude: 31.78913, longitude: 35.20465)
        )

        await cache.setStop(stop, code: stop.code, ttl: 60)
        let retrieved = await cache.getStop(code: stop.code)
        #expect(retrieved?.code == stop.code)

        let missing = await cache.getStop(code: MOTStopCode(99999))
        #expect(missing == nil)
    }

    @Test
    func testMOTIdentityStore() async {
        let store = MOTIdentityStore()
        let code = MOTStopCode(5997)
        let internalID = MOTStopInternalID(11622)

        await store.register(code: code, internalID: internalID)
        let resolvedInternal = await store.internalID(for: code)
        let resolvedCode = await store.code(for: internalID)

        #expect(resolvedInternal == internalID)
        #expect(resolvedCode == code)
    }

    @Test
    func testMOTHTTPErrorDescriptions() {
        let wafError = MOTHTTPError.wafBlocked(supportID: "test-support-1234")
        #expect(wafError.localizedDescription.contains("test-support-1234") || wafError.localizedDescription.contains("F5"))

        let rateLimitError = MOTHTTPError.rateLimited(retryAfterSeconds: 30)
        #expect(rateLimitError.localizedDescription.contains("30") || rateLimitError.localizedDescription.contains("בקשות"))
    }
}
