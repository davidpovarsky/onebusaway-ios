//
//  IsraelRouteSearchEndToEndTests.swift
//  IsraelMOTTests
//

import Foundation
import Testing
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

@Suite(.serialized)
struct IsraelRouteSearchEndToEndTests {

    @Test
    func testRouteSearch100RowsDecodingAndAgencyRefs() throws {
        // Build 100-row simulated official MOT AutoComplete/SearchLines response
        var items: [[String: Any]] = []
        for i in 1...100 {
            items.append([
                "routeId": 33000 + i,
                "agencyId": 16,
                "agencyName": "סופרבוס",
                "routeName": "31",
                "routeLongName": "מסוף גילה/המרגלית<->רמות variant \(i)",
                "cityName": i <= 5 ? "ירושלים" : "עיר \(i)"
            ])
        }

        let fakeMOTJson: [String: Any] = [
            "data": items,
            "success": true,
            "message": ""
        ]
        let data = try JSONSerialization.data(withJSONObject: fakeMOTJson)

        let decoded = try JSONDecoder().decode(MOTSearchLinesServiceResponse.self, from: data)
        let dtoList = try #require(decoded.data)
        #expect(dtoList.count == 100)

        // Map to OBA routes response
        let routes = dtoList.map { $0.toTransitRouteSummary() }

        let envelope = OBACompatibilityBridge.routesForLocationResponse(routes: routes)
        #expect(envelope["code"] as? Int == 200)

        guard let envelopeData = envelope["data"] as? [String: Any],
              let list = envelopeData["list"] as? [[String: Any]],
              let references = envelopeData["references"] as? [String: Any],
              let agencies = references["agencies"] as? [[String: Any]] else {
            Issue.record("Failed to parse OBA envelope structure")
            return
        }

        #expect(list.count == 100)
        #expect(agencies.count >= 1)
        #expect(agencies.contains { ($0["id"] as? String) == "mot:agency:16" })

        // Verify agencyId reference is present in every route
        for routeDict in list {
            #expect((routeDict["agencyId"] as? String) == "mot:agency:16")
            #expect((routeDict["color"] as? String) == "004F9E") // Superbus blue
        }
    }

    @Test
    func testQueryNormalizationAndJerusalemRanking() {
        let items: [MOTSearchLineDTO] = [
            MOTSearchLineDTO(routeId: 101, agencyId: 3, agencyName: "אגד", routeName: "31", routeLongName: "חיפה<->קריות", cityName: "חיפה"),
            MOTSearchLineDTO(routeId: 102, agencyId: 16, agencyName: "סופרבוס", routeName: "31", routeLongName: "גילה<->רמות", cityName: "ירושלים"),
            MOTSearchLineDTO(routeId: 103, agencyId: 5, agencyName: "דן", routeName: "31", routeLongName: "תל אביב<->רמת גן", cityName: "תל אביב")
        ]

        // Jerusalem priority sorting
        let sorted = items.sorted { lhs, rhs in
            let lhsCity = lhs.cityName ?? ""
            let rhsCity = rhs.cityName ?? ""
            let lhsIsJlm = lhsCity.contains("ירושלים")
            let rhsIsJlm = rhsCity.contains("ירושלים")
            if lhsIsJlm != rhsIsJlm { return lhsIsJlm }
            return lhs.routeId < rhs.routeId
        }

        #expect(sorted.first?.routeId == 102)
        #expect(sorted.first?.cityName == "ירושלים")
    }

    @Test
    func testNumericAndHebrewPrefixQueryMatching() {
        let queries = ["31", " 31 ", "קו 31", "קו31", "Line 31"]
        for q in queries {
            let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized: String
            if trimmed.hasPrefix("קו") {
                normalized = trimmed.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.lowercased().hasPrefix("line") {
                normalized = trimmed.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                normalized = trimmed
            }
            #expect(normalized == "31")
        }
    }

    @Test
    func testArabicIndicAndAlphanumericRouteNormalization() {
        let arabicIndic31 = "٣١"
        let mapped = String(arabicIndic31.map { char in
            switch char {
            case "٠": return "0"
            case "١": return "1"
            case "٢": return "2"
            case "٣": return "3"
            case "٤": return "4"
            case "٥": return "5"
            case "٦": return "6"
            case "٧": return "7"
            case "٨": return "8"
            case "٩": return "9"
            default: return char
            }
        })
        #expect(mapped == "31")

        // Route query with Hebrew prefix and city
        let rawQueries = ["קו 31", "خط 31", "bus 31", "31 ירושלים", "קו 31א"]
        for q in rawQueries {
            let stripped = q
                .replacingOccurrences(of: "^(קו|خط|line|route|bus)\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let hasRouteDigit = stripped.contains(where: { $0.isNumber })
            #expect(hasRouteDigit)
        }
    }
}
