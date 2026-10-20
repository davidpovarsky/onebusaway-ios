//
//  IsraelDirectionLabelTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelDirectionLabelTests {

    @Test
    func testHebrewArrowSeparation() {
        let headsigns = [
            ("תלפיות <-> הר נוף", "הר נוף", "תלפיות"),
            ("מסוף גילה/המרגלית < - > רמות", "רמות", "מסוף גילה/המרגלית"),
            ("ירושלים ↔ תל אביב", "תל אביב", "ירושלים"),
            ("תל אביב - חיפה", "חיפה", "תל אביב")
        ]

        for (input, expectedDest, expectedOrigin) in headsigns {
            let resolver = RouteDirectionLabelResolver(headsign: input)
            #expect(resolver.destination == expectedDest)
            #expect(resolver.origin == expectedOrigin)
        }
    }

    @Test
    func testSingleDestinationWithoutArrow() {
        let resolver = RouteDirectionLabelResolver(headsign: "רמות")
        #expect(resolver.destination == "רמות")
        #expect(resolver.origin == nil)
    }

    @Test
    func testTransitRouteDestinationAndOriginFromStops() {
        let stop1 = TransitStop(
            code: MOTStopCode(1001),
            internalID: MOTStopInternalID(1),
            name: TransitMultiLanguageName(he: "תחנת מוצא", en: nil, ar: nil),
            cityName: "ירושלים",
            streetName: "",
            location: .init(latitude: 31.8, longitude: 35.2),
            platformNumber: nil,
            isAccessible: true,
            routes: []
        )
        let stop2 = TransitStop(
            code: MOTStopCode(1002),
            internalID: MOTStopInternalID(2),
            name: TransitMultiLanguageName(he: "תחנת יעד", en: nil, ar: nil),
            cityName: "ירושלים",
            streetName: "",
            location: .init(latitude: 31.9, longitude: 35.3),
            platformNumber: nil,
            isAccessible: true,
            routes: []
        )

        let route = TransitRoute(
            routeID: MOTRouteID(31),
            lineName: "31",
            longName: "מוצא <-> יעד",
            routeDesc: MOTRouteDesc("10031-1-0"),
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס",
            cityName: "ירושלים",
            polyline: nil,
            stops: [stop1, stop2]
        )

        #expect(route.destinationName == "תחנת יעד")
        #expect(route.originName == "תחנת מוצא")
    }
}
