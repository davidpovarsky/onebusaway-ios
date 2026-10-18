# תוכנית בדיקות אוטומטיות ומניעת רגרסיה — Test Coverage Plan
**תאריך:** 18 באוקטובר 2026  
**יעד:** הבטחת יציבות, כיסוי בדיקות יחידה, בדיקות אינטגרציה ובדיקות רגרסיה עבור מודול `IsraelMOT` ואפליקציית OneBusAway iOS.

---

## 1. מערך בדיקות יחידה חדשות (Unit Tests)

יש להוסיף את בדיקות היחידה הבאות תחת חבילת [IsraelMOT/Tests/](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Tests/):

### 1.1 בדיקות תאריכים ואזורי זמן (`MOTDateParserTests.swift`)
```swift
func testTripPlanningDateFormattingPreservesLocalJerusalemHour() {
    // קביעת תאריך מטרה: 18 באוקטובר 2026, בשעה 16:10:00 באזור זמן Asia/Jerusalem
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
    let components = DateComponents(year: 2026, month: 10, day: 18, hour: 16, minute: 10, second: 0)
    let targetDate = calendar.date(from: components)!
    
    let formatted = MOTTripPlanningAPIService.formatLocalPlanningDate(targetDate)
    
    // מוודא שהמחרוזת שנשלחת לשרת אינה מומרת ל-13:10Z (UTC) אלא שומרת על 16:10
    XCTAssertEqual(formatted, "2026-10-18T16:10:00")
    XCTAssertFalse(formatted.hasSuffix("Z"), "Dates to MOT planner must not contain trailing Z")
}
```

### 1.2 בדיקות מיפוי תחנות לקו (`MOTRouteStopsMappingTests.swift`)
```swift
func testStopsForRouteDTOProducesValidOBAEnvelope() throws {
    let fixtureData = MOTTestFixtures.loadJSON("route_31_stops_live.json")
    let decoded = try JSONDecoder().decode(RouteStopsResponseDTOServiceResponse.self, from: fixtureData)
    
    let envelope = OBACompatibilityBridge.stopsForRouteResponse(stopsContainer: decoded.data!)
    
    let entry = try XCTUnwrap(envelope["entry"] as? [String: Any])
    let stopIds = try XCTUnwrap(entry["stopIds"] as? [String])
    XCTAssertGreaterThan(stopIds.count, 0)
    
    let references = try XCTUnwrap(envelope["references"] as? [String: Any])
    let stops = try XCTUnwrap(references["stops"] as? [[String: Any]])
    XCTAssertEqual(stops.count, stopIds.count)
}
```

### 1.3 בדיקות סניטציה של חיפוש קווים (`MOTSearchSanitizationTests.swift`)
```swift
func testSearchLinesQueryExtractsNumberAndCityTokens() {
    let input = "31 ירושלים"
    let parsed = MOTSearchQueryParser.parse(input)
    
    XCTAssertEqual(parsed.lineQuery, "31")
    XCTAssertEqual(parsed.cityFilter, "ירושלים")
}
```

### 1.4 בדיקות חילוץ מיקום GPS של אוטובוס (`MOTRealtimeVehicleTests.swift`)
```swift
func testNextStopTimesExtractsVehicleGPSCoordinates() throws {
    let responseWithGPS = MOTTestFixtures.sampleNextStopTimesWithLocation
    let itinerary = MOTItineraryMapper.mapLeg(from: responseWithGPS)
    
    XCTAssertTrue(itinerary.isRealTime)
    XCTAssertNotNil(itinerary.vehicleLocation)
    XCTAssertEqual(itinerary.vehicleLocation?.latitude, 31.789, accuracy: 0.001)
}
```

### 1.5 בדיקות כפיית שיטה מטרית (`FormattersLocalizationTests.swift`)
```swift
func testDistanceFormattingForcesMetricInIsrael() {
    let distanceInMeters: Double = 1450.0
    let formatted = Formatters.formattedDistance(distanceInMeters, inIsraelRegion: true)
    
    XCTAssertTrue(formatted.contains("ק\"מ") || formatted.contains("km"))
    XCTAssertFalse(formatted.contains("mi"))
}
```

---

## 2. בדיקות אינטגרציה וסימולציית שרת (Integration & Mock Replay Tests)

שימוש בקבצי ה-JSON הגולמיים שנשמרו ב-[reports/raw/](file:///c:/Users/DAVID/Code/onebusaway-ios/reports/raw/) לבדיקת שרשרת הנתונים המלאה ללא תלות ברשת חיה:

1. **`testScenario1EndToEndWithMockServer`:**
   - טעינת [reports/raw/scenario1_routes.json](file:///c:/Users/DAVID/Code/onebusaway-ios/reports/raw/scenario1_routes.json).
   - העברת הבקשה דרך `MOTTripPlanningAPIService`.
   - אימות שהתוצאות כוללות את 4 המסלולים (64+3, 64, 71, 86+333) עם זמני יציאה והגעה תקינים.
2. **`testStopsForLocationDataLoaderDoesNotThrowUnsupportedEndpoint`:**
   - בדיקה שקריאה ל-`/api/where/stops-for-route/mot:route:33287.json` אינה זורקת `unsupportedOneBusAwayEndpoint`.
3. **`testMapStopsLoaderHandlesPaginationGracefully`:**
   - בדיקת טעינת ריבוי תחנות מעבר למגבלת 10 התחנות.

---

## 3. תרחישי בדיקת קבלה ורגרסיה ידנית (Manual Acceptance Criteria)

| תרחיש | פעולת בודק | תוצאה מצופה |
| :--- | :--- | :--- |
| **תכנון מסלול Arrive-By** | בחירת שעת הגעה 16:10 בתאריך עתידי | כל המסלולים המוצעים מגיעים לכל המאוחר ב-16:10, ואף מסלול אינו מציג יציאה בעבר. |
| **לחיצה על קו ברשימת חיפוש** | חיפוש קו 31 ולחיצה על השורה | פתיחת כרטיס הקו עם רשימת כל התחנות, מסלול הקו על גבי המפה, וללא שגיאת "stop list isn't available". |
| **גלילה וזום במפה** | גלילה באזור ירושלים או גוש דן | תחנות נטענות בצפיפות נכונה ואינן מוגבלות ל-10 תחנות בלבד. |
| **חיפוש קווים רציף** | חיפוש קו 3 -> בחירה -> חיפוש קו 31 | תוצאות קו 31 מתקבלות מיד ללא מסך ריק. |
| **רכב נוסע במפה** | פתיחת פרטי נסיעה עם זמן אמת | הופעת אייקון אוטובוס פעיל שנע על המפה. |
| **תצוגת מזהים נקייה** | צפייה במסכי תחנות וקווים | אין הופעה של מחרוזות טכניות כמו `mot:stop:2899`. |
