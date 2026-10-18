//
//  MOTCompatibilityDataLoaderTests.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

private final class TestMockDataLoader: NSObject, URLDataLoader, @unchecked Sendable {
    var handledRequests: [URLRequest] = []
    var responseData: Data = "{\"code\": 200, \"text\": \"OK\"}".data(using: .utf8)!

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        handledRequests.append(request)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }
}

@Suite(.serialized)
struct MOTCompatibilityDataLoaderTests {

    @Test
    func testNonInterceptedRequestPassesToFallback() async throws {
        let fallback = TestMockDataLoader()
        let loader = MOTCompatibilityDataLoader(fallbackLoader: fallback)

        let pugetSoundURL = URL(string: "https://api.pugetsound.onebusaway.org/api/where/agencies-with-coverage.json?key=TEST")!
        let request = URLRequest(url: pugetSoundURL)

        let (data, response) = try await loader.data(for: request)

        #expect(fallback.handledRequests.count == 1)
        #expect(fallback.handledRequests.first?.url == pugetSoundURL)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(data == fallback.responseData)
    }

    @Test
    func testOBACompatibilityBridgeStopsEnvelopeStructure() {
        let dummyStop = TransitStop(
            code: MOTStopCode(5997),
            internalID: MOTStopInternalID(11622),
            name: TransitMultiLanguageName(he: "שרי ישראל", en: "Sarei Yisrael", ar: nil),
            cityName: "ירושלים",
            streetName: "שרי ישראל",
            location: CLLocationCoordinate2D(latitude: 31.78913, longitude: 35.20465),
            platformNumber: nil,
            isAccessible: true,
            routes: [
                TransitRouteSummary(
                    routeID: MOTRouteID(33285),
                    lineName: "15",
                    routeDesc: MOTRouteDesc("15015-1-0"),
                    destinationName: "תלפיות",
                    agencyID: MOTAgencyID(16),
                    agencyName: "סופרבוס"
                )
            ]
        )

        let envelope = OBACompatibilityBridge.stopsForLocationResponse(stops: [dummyStop])

        #expect(envelope["code"] as? Int == 200)
        #expect(envelope["text"] as? String == "OK")
        guard let data = envelope["data"] as? [String: Any] else {
            Issue.record("Expected data dictionary")
            return
        }

        guard let list = data["list"] as? [[String: Any]] else {
            Issue.record("Expected list array")
            return
        }
        #expect(list.count == 1)
        #expect(list[0]["id"] as? String == "mot:stop:5997")
        #expect(list[0]["code"] as? String == "5997")

        guard let references = data["references"] as? [String: Any] else {
            Issue.record("Expected references dictionary")
            return
        }
        guard let routes = references["routes"] as? [[String: Any]] else {
            Issue.record("Expected referenced routes")
            return
        }
        #expect(routes.contains { ($0["id"] as? String) == "mot:route:33285" })
    }

    @Test
    func testOBACompatibilityBridgeArrivalsEnvelopeStructure() {
        let dummyStop = TransitStop(
            code: MOTStopCode(5997),
            name: TransitMultiLanguageName(he: "שרי ישראל", en: nil, ar: nil),
            cityName: "ירושלים",
            location: CLLocationCoordinate2D(latitude: 31.78913, longitude: 35.20465),
            routes: []
        )

        let arrival = TransitArrival(
            routeID: MOTRouteID(101),
            lineName: "31",
            destination: "גילה",
            scheduledTime: Date().addingTimeInterval(300),
            estimatedTime: Date().addingTimeInterval(300),
            minutesToArrival: 5,
            isRealTime: true,
            vehicleLocation: CLLocationCoordinate2D(latitude: 31.78, longitude: 35.20)
        )

        let envelope = OBACompatibilityBridge.stopArrivalsResponse(stop: dummyStop, arrivals: [arrival])

        #expect(envelope["code"] as? Int == 200)
        guard let data = envelope["data"] as? [String: Any],
              let entry = data["entry"] as? [String: Any],
              let arrivalsAndDepartures = entry["arrivalsAndDepartures"] as? [[String: Any]] else {
            Issue.record("Expected arrivals and departures entry")
            return
        }

        #expect(arrivalsAndDepartures.count == 1)
        let firstArr = arrivalsAndDepartures[0]
        #expect(firstArr["routeShortName"] as? String == "31")
        #expect(firstArr["predicted"] as? Bool == true)
        #expect(firstArr["tripStatus"] != nil)
    }

    @Test
    func testOBACompatibilityBridgeStopDetailEntryEnvelope() {
        let dummyStop = TransitStop(
            code: MOTStopCode(5997),
            internalID: MOTStopInternalID(11622),
            name: TransitMultiLanguageName(he: "שרי ישראל", en: "Sarei Yisrael", ar: nil),
            cityName: "ירושלים",
            location: CLLocationCoordinate2D(latitude: 31.78913, longitude: 35.20465),
            routes: []
        )

        let envelope = OBACompatibilityBridge.stopDetailResponse(stop: dummyStop)

        #expect(envelope["code"] as? Int == 200)
        guard let data = envelope["data"] as? [String: Any] else {
            Issue.record("Expected data dictionary")
            return
        }

        // Single stop MUST be in "entry", NOT "list"
        #expect(data["entry"] != nil)
        #expect(data["list"] == nil)

        guard let entry = data["entry"] as? [String: Any] else {
            Issue.record("Expected entry dictionary")
            return
        }
        #expect(entry["id"] as? String == "mot:stop:5997")
        #expect(entry["code"] as? String == "5997")
    }

    @Test
    func testStableTripIDAcrossRefreshes() {
        let dummyStop = TransitStop(
            code: MOTStopCode(5997),
            name: TransitMultiLanguageName(he: "שרי ישראל", en: nil, ar: nil),
            cityName: "ירושלים",
            location: CLLocationCoordinate2D(latitude: 31.78913, longitude: 35.20465),
            routes: []
        )

        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let arrival = TransitArrival(
            routeID: MOTRouteID(33285),
            lineName: "15",
            destination: "תלפיות",
            scheduledTime: fixedDate,
            isRealTime: false
        )

        let envelope1 = OBACompatibilityBridge.stopArrivalsResponse(stop: dummyStop, arrivals: [arrival])
        let envelope2 = OBACompatibilityBridge.stopArrivalsResponse(stop: dummyStop, arrivals: [arrival])

        let entry1 = (envelope1["data"] as? [String: Any])?["entry"] as? [String: Any]
        let entry2 = (envelope2["data"] as? [String: Any])?["entry"] as? [String: Any]

        let arrs1 = entry1?["arrivalsAndDepartures"] as? [[String: Any]]
        let arrs2 = entry2?["arrivalsAndDepartures"] as? [[String: Any]]

        let tripId1 = arrs1?.first?["tripId"] as? String
        let tripId2 = arrs2?.first?["tripId"] as? String

        #expect(tripId1 != nil)
        #expect(tripId1 == tripId2)
        #expect(tripId1 == "mot:trip:33285_1700000000")
    }

    @Test
    func testScheduledArrivalNeverPresentedAsRealTime() {
        let dummyStop = TransitStop(
            code: MOTStopCode(5997),
            name: TransitMultiLanguageName(he: "שרי ישראל", en: nil, ar: nil),
            cityName: "ירושלים",
            location: CLLocationCoordinate2D(latitude: 31.78913, longitude: 35.20465),
            routes: []
        )

        let arrival = TransitArrival(
            routeID: MOTRouteID(33285),
            lineName: "15",
            destination: "תלפיות",
            scheduledTime: Date().addingTimeInterval(600),
            estimatedTime: nil,
            minutesToArrival: nil,
            isRealTime: false,
            vehicleLocation: nil
        )

        let envelope = OBACompatibilityBridge.stopArrivalsResponse(stop: dummyStop, arrivals: [arrival])
        let entry = (envelope["data"] as? [String: Any])?["entry"] as? [String: Any]
        let arrs = entry?["arrivalsAndDepartures"] as? [[String: Any]]
        let record = arrs?.first

        #expect(record?["predicted"] as? Bool == false)
        #expect(record?["status"] as? String == "scheduled")
        #expect(record?["predictedArrivalTime"] == nil)
        #expect(record?["tripStatus"] == nil)
    }

    // These are INTEGRATION decoder tests, not just JSON-shape assertions.
    // They exercise exactly the OneBusAway RESTAPIResponse<...> classes used
    // by the real map, stop page, arrival panel and route-search UI.
    private func decodeAppResponse<T: Decodable>(
        _ envelope: [String: Any], as type: T.Type
    ) throws -> RESTAPIResponse<T> {
        let bytes = try JSONSerialization.data(withJSONObject: envelope)
        return try JSONDecoder.RESTDecoder(regionIdentifier: 972)
            .decode(RESTAPIResponse<T>.self, from: bytes)
    }

    private var jerusalemStop: TransitStop {
        TransitStop(
            code: MOTStopCode(5997),
            internalID: MOTStopInternalID(11622),
            name: TransitMultiLanguageName(he: "סילבר/שכטמן", en: "Silver/Shechtman", ar: nil),
            cityName: "ירושלים",
            location: CLLocationCoordinate2D(latitude: 31.81642, longitude: 35.20312),
            routes: [
                TransitRouteSummary(
                    routeID: MOTRouteID(33287),
                    lineName: "31",
                    routeDesc: MOTRouteDesc("15031-1-0"),
                    destinationName: "רמות",
                    agencyID: MOTAgencyID(16),
                    agencyName: "סופרבוס"
                )
            ]
        )
    }

    @Test
    func testNativeOBAStopListDecoderResolvesAgencyAndRoutes() throws {
        let json = OBACompatibilityBridge.stopsForLocationResponse(stops: [jerusalemStop])
        let response = try decodeAppResponse(json, as: [Stop].self)
        let stop = try #require(response.list.first)
        #expect(stop.code == "5997")
        #expect(stop.name.contains("סילבר"))
        #expect(stop.regionIdentifier == 972)

        // This failed on the real iPad when agency.privateService was missing.
        let route = try #require(stop.routes.first)
        #expect(route.shortName == "31")
        let agency = try #require(route.agency)
        #expect(agency.name == "סופרבוס")
        #expect(!agency.isPrivateService)
        #expect(agency.timeZone == "Asia/Jerusalem")
    }

    @Test
    func testNativeOBAStopDetailDecoderWithReferences() throws {
        let payload = OBACompatibilityBridge.stopDetailResponse(stop: jerusalemStop)
        let response = try decodeAppResponse(payload, as: Stop.self)
        #expect(response.entry.id == "mot:stop:5997")
        #expect(response.entry.routes.count == 1)
        #expect(response.entry.routes[0].agency?.name == "סופרבוס")
    }

    @Test
    func testNativeOBARouteSearchDecoderAndAgencyReference() throws {
        let payload = OBACompatibilityBridge.routesForLocationResponse(routes: jerusalemStop.routes)
        let response = try decodeAppResponse(payload, as: [Route].self)
        #expect(response.list.count == 1)
        let route = try #require(response.list.first)
        #expect(route.id == "mot:route:33287")
        #expect(route.shortName == "31")
        #expect(route.agency?.name == "סופרבוס")
    }

    @Test
    func testNativeOBAArrivalsDecoderAndTripReferences() throws {
        let scheduled = Date().addingTimeInterval(300)
        let arrival = TransitArrival(
            routeID: MOTRouteID(33287),
            lineName: "31",
            destination: "רמות",
            scheduledTime: scheduled,
            estimatedTime: scheduled.addingTimeInterval(60),
            minutesToArrival: 5,
            isRealTime: true,
            vehicleLocation: CLLocationCoordinate2D(latitude: 31.82, longitude: 35.20)
        )
        let json = OBACompatibilityBridge.stopArrivalsResponse(
            stop: jerusalemStop, arrivals: [arrival]
        )
        let response = try decodeAppResponse(json, as: StopArrivals.self)
        #expect(response.entry.stop?.id == "mot:stop:5997")
        let first = try #require(response.entry.arrivalsAndDepartures.first)
        #expect(first.predicted)
        #expect(first.route?.shortName == "31")
        #expect(first.trip?.shortName == "31")
        #expect(first.trip?.route?.agency?.name == "סופרבוס")
        #expect(first.lastUpdated.timeIntervalSince1970 > 0)
        // Current adapter lacks a complete authoritative TripStatus. Do not
        // silently assume vehicle tracking works merely because a key exists.
        #expect(first.tripStatus == nil)
    }

    @Test
    func testNativeOBAScheduledArrivalsDecodeWithoutRealTimeData() throws {
        let when = Date().addingTimeInterval(300)
        let scheduled = TransitArrival(
            routeID: MOTRouteID(33287),
            lineName: "31",
            destination: "רמות",
            scheduledTime: when,
            isRealTime: false
        )
        let payload = OBACompatibilityBridge.stopArrivalsResponse(
            stop: jerusalemStop, arrivals: [scheduled]
        )
        let decoded = try decodeAppResponse(payload, as: StopArrivals.self)
        let arrival = try #require(decoded.entry.arrivalsAndDepartures.first)
        #expect(!arrival.predicted)
        #expect(arrival.route?.shortName == "31")
        #expect(arrival.trip?.shortName == "31")
    }

    @Test
    func testNativeOBARouteDetailDecoderWithStopReferences() throws {
        let route = TransitRoute(
            routeID: MOTRouteID(33287),
            lineName: "31",
            longName: "גילה – רמות",
            routeDesc: MOTRouteDesc("15031-1-0"),
            agencyID: MOTAgencyID(16),
            agencyName: "סופרבוס",
            cityName: "ירושלים",
            polyline: nil,
            stops: [jerusalemStop]
        )
        let decoded = try decodeAppResponse(
            OBACompatibilityBridge.routeDetailResponse(route: route),
            as: Route.self
        )
        #expect(decoded.entry.id == "mot:route:33287")
        #expect(decoded.entry.agency?.name == "סופרבוס")
    }

    @Test
    func testIsraelAgencyCoverageCompatibilityDoesNotLeakToMinistry() async throws {
        let fallback = TestMockDataLoader()
        let loader = MOTCompatibilityDataLoader(fallbackLoader: fallback)
        let configuration = APIServiceConfiguration(
            baseURL: URL(string: "https://api.bus.gov.il/prod/")!,
            apiKey: "org.onebusaway.iphone",
            uuid: "test-user",
            appVersion: "26.4.0",
            regionIdentifier: 972
        )
        let appAPI = RESTAPIService(configuration, dataLoader: loader)
        let result = try await appAPI.getAgenciesWithCoverage()
        #expect(result.list.isEmpty)
        #expect(fallback.handledRequests.isEmpty)
    }

    @Test
    func testUnsupportedOBAEndpointNeverGoesToMinistry() async {
        let fallback = TestMockDataLoader()
        let loader = MOTCompatibilityDataLoader(fallbackLoader: fallback)
        let url = URL(string: "https://api.bus.gov.il/prod/api/ondemand/services-for-location.json?lat=31.78&lon=35.20")!
        do {
            _ = try await loader.data(for: URLRequest(url: url))
            Issue.record("Expected rejection of a nonexistent OBA endpoint")
        } catch is MOTCompatibilityError {
            // Expected: a capability error, not a fabricated F5 rejection.
        } catch {
            Issue.record("Unexpected error type: \\(error)")
        }
        #expect(fallback.handledRequests.isEmpty)
    }

    @Test
    func testIsraelSearchLinesBridgeWithOfficialResponseShape() throws {
        let sample = """
        {"data":[{"routeId":33287,"agencyId":16,"agencyName":"סופרבוס","routeName":"31","routeLongName":"מסוף גילה/המרגלית<->רמות","cityName":"ירושלים"}],"success":true,"message":""}
        """
        let decoded = try JSONDecoder().decode(
            MOTSearchLinesServiceResponse.self, from: Data(sample.utf8)
        )
        #expect(decoded.success)
        let routes = (decoded.data ?? []).map { $0.toTransitRouteSummary() }
        #expect(routes.count == 1)

        let envelope = OBACompatibilityBridge.routesForLocationResponse(routes: routes)
        let data = try JSONSerialization.data(withJSONObject: envelope)
        let output = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let responseData = output?["data"] as? [String: Any]
        let results = responseData?["list"] as? [[String: Any]]
        let references = responseData?["references"] as? [String: Any]
        #expect(results?.count == 1)
        #expect(results?.first?["id"] as? String == "mot:route:33287")
        #expect(results?.first?["shortName"] as? String == "31")
        #expect((results?.first?["longName"] as? String)?.contains("ירושלים") == true)
        #expect((references?["routes"] as? [[String: Any]])?.count == 1)
        #expect((references?["agencies"] as? [[String: Any]])?.count == 1)
    }
}
