# ניתוח סיבות שורש לתקלות — Bug Root Causes Report
**תאריך:** 18 באוקטובר 2026  
**קוד מקור:** ענף `fix/israel-runtime-region-search-weather` במאגר [onebusaway-ios](file:///c:/Users/DAVID/Code/onebusaway-ios)  
**שרתי בדיקה:** `https://api.bus.gov.il/prod/`  
**אופן אימות:** ביקורת סטטית בקוד, הרצת בדיקות חיות ב-Python/Playwright והשוואת חוזים.

---

## תקלה 1: תכנון מסלול מקדים בשעה ומחזיר מסלולים שכבר יצאו (Timezone Shift)

### חומרה: קריטית (P0)
### תסמינים למשתמש:
משתמש בוחר "הגעה עד 16:10" (למשל מ-לואי ליפסקי 39 לישיבת מיר), ומקבל תוצאות המגיעות בסביבות 15:00 ומקדימות בשעה שלמה, כאשר חלקן מציגות נסיעות שכבר יצאו לדרכן.

### מיקום מדויק בקוד:
- **קובץ:** [MOTTripPlanningAPIService.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OTPAdapter/MOTTripPlanningAPIService.swift#L44-L48)
- **פונקציה:** `isoFormatter` (שורות 44–48) והקריאה ב-`planTrip` (שורה 60):
```swift
private let isoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    formatter.timeZone = TimeZone(secondsFromGMT: 0) // <-- כפיית אזור זמן אפס (GMT)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()
```

### ראיות מהשרת והאתר:
- בבדיקה חיה ב-API (`RoutePlanning/GetRoutes`), כאשר נשלח תאריך עם סיומת 'Z' כמו `2026-10-18T13:10:00.000Z` (16:10 שעון קיץ ישראלי UTC+3 שהומר ל-UTC), מנוע ה-API של משרד התחבורה ממיר זאת לפי שעון חורף ישראלי (UTC+2) או מתעלם מסימול ה-'Z', ומחשב את שעת היעד כ-**15:10**!
- השרת החזיר בדיוק נמרץ את ארבעת המסלולים שנראו בצילום האפליקציה (יציאות ב-14:22, 14:27, 14:28, 14:37 והגעה עד 15:06).
- באתר הרשמי (`chunk-PCGESSUS.js`), הפונקציה ששולחת את הבקשה שומרת על שעה מקומית מלאה ללא 'Z' וללא כפיית GMT: `2026-10-18T16:10:00`.

### סיבת שורש:
שימוש בפורמטר המאלץ `timeZone = TimeZone(secondsFromGMT: 0)` עבור API שמצפה לזמן מקומי ישראלי או שאינו מטפל כראוי בסיומת 'Z'.

### תיקון מוצע:
הגדרת הפורמטר לעבודה עם אזור הזמן הישראלי:
```swift
formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current
formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
```

---

## תקלה 2: "stop list isn't available" ונקודות קצה חסרות (Missing Route Stops & Schedule)

### חומרה: קריטית (P0)
### תסמינים למשתמש:
לחיצה על קו אוטובוס בתוצאות החיפוש מציגה הודעת שגיאה חוסמת: "stop list isn't available". המשתמש אינו יכול לראות את רשימת התחנות של הקו או את מסלולו על המפה.

### מיקום מדויק בקוד:
- **קובץ:** [MOTCompatibilityDataLoader.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift#L44-L102)
- **פונקציה:** `data(for request: URLRequest)`
- **קובץ קורא:** [SearchResultRouter.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/Sheet/Content/Search/SearchResultRouter.swift#L146-L152)

### ראיות מהקוד והשרת:
1. ב-[MOTCompatibilityDataLoader.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift#L44-L67), ה-DataLoader מיירט רק 5 נקודות קצה:
   - `stops-for-location`
   - `/where/stop/`
   - `arrivals-and-departures-for-stop`
   - `routes-for-location`
   - `/where/route/`
2. כאשר OBAKit פונה לטעון את תחנות הקו דרך `/api/where/stops-for-route/{routeID}.json` או `/schedule-for-route/{routeID}.json`, הבקשה אינה נתפסת באף תנאי `if`, ומגיעה לשורה 100:
   ```swift
   if url.host?.lowercased() == "api.bus.gov.il",
      path.hasPrefix("/prod/api/") {
       throw MOTCompatibilityError.unsupportedOneBusAwayEndpoint(url.path)
   }
   ```
3. שגיאה זו נזרקת ישירות ל-OBAKit, אשר קורא אותה ב-`SearchResultRouter.swift`, מעדכן את `lastError`, ומציג את ההודעה "stop list isn't available".
4. **שרת משרד התחבורה תומך בנקודת הקצה במלואה!** בבדיקה חיה של `Routes/GetRouteStops?RouteId=33287` ו-`Routes/GetRouteFullData?routeId=33287`, השרת מחזיר בהצלחה מלאה את כל רשימת התחנות (`route` ו-`oppositeDirectionRoute`), כולל שמות תחנות, מזהים, קואורדינטות ו-polyline מלא של המסלול!
5. יתרה מזאת: הקלאס [MOTEndpoints.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Core/HTTP/MOTEndpoints.swift#L100-L105) כבר מכיל את המתודה `routeStopsURL(routeID:)`, והמודלים [RouteFullDataResponseDTO.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Core/DTO/Scheduler/RouteFullDataResponseDTO.swift#L28-L55) כבר מוגדרים! אך המתאם לא חיבר ביניהם!

### סיבת שורש:
חוסר יירוט של נתיבי `stops-for-route` ו-`schedule-for-route` ב-`MOTCompatibilityDataLoader.swift`.

### תיקון מוצע:
הוספת יירוט ב-`MOTCompatibilityDataLoader.swift`:
```swift
if path.contains("stops-for-route") || path.contains("schedule-for-route") {
    return try await handleStopsForRoute(url: url)
}
```
ויישום `handleStopsForRoute` באמצעות קריאה ל-`endpoints.routeStopsURL(routeID:)` ומיפוי לחוזה OBA של `stops-for-route` (הכולל `entry` עם `stopIds`, `stopGroupings`, ו-`polylines`, ו-`references.stops`).

---

## תקלה 3: תחנות במפה אינן נטענות בעקביות, נעלמות או מופיעות בדלילות (Map Stops Pan/Zoom)

### חומרה: גבוהה (P1)
### תסמינים למשתמש:
בזמן הזזת המפה או שינוי זום, תחנות אוטובוס רבות חסרות, נעלמות לפתע, או שמופיעות רק 10 תחנות בכל אזור המפה.

### מיקום מדויק בקוד:
- **קובץ 1:** [MOTCompatibilityDataLoader.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift#L160-L178)
- **קובץ 2:** [MapRegionManager.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/Mapping/MapRegionManager.swift#L822, #L1024, #L1669)

### ראיות מהקוד והשרת:
1. **מגבלת שרת קשיחה (Server Hard Cap):** בבדיקה חיה של `Stops/GetStopsCloseToLocationByRadius` (שנשמרה ב-[reports/raw/stops_test_result.json](file:///c:/Users/DAVID/Code/onebusaway-ios/reports/raw/stops_test_result.json)), שרת משרד התחבורה מחזיר **לכל היותר 10 תחנות בדיוק**, ללא קשר לרדיוס (בין אם נשלח רדיוס 500 מטר ובין אם 15,000 מטר!).
2. האפליקציה ממפה את הבקשה של OBAKit (`stops-for-location`) ישירות ל-`GetStopsCloseToLocationByRadius`. כתוצאה מכך, בכל תנועת מפה, המשתמש רואה מקסימום 10 תחנות בכל שטח המסך!
3. **חסימת רענון במפה (Map Region Override):** ב-[MapRegionManager.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/Mapping/MapRegionManager.swift#L822), הפונקציה `searchResponseOverridesStopLoading()` מחזירה `true` כאשר תוצאת חיפוש קודמת או קו פעיל שמורים בזיכרון, מה שמונע טעינת תחנות חדשות בעת הזזת המפה.
4. האתר הרשמי פותר זאת על ידי שימוש בנקודת הקצה `Location/GetMapStops` עם פרמטרי Bounding Box ועימוד (`skip`/`take`), אשר מחזירה את כל התחנות באזור ללא מגבלת 10 התחנות.

### סיבת שורש:
שימוש בנקודת קצה מוגבלת של השרת (`GetStopsCloseToLocationByRadius` עם hard-cap של 10 תחנות) ושמירת חסימת טעינה ב-`MapRegionManager`.

### תיקון מוצע:
1. מעבר לשימוש ב-`Location/GetMapStops` בעת טעינת תחנות במפה, או פיצול ה-viewport לרשת (tiling grid) לקבלת כלל התחנות.
2. איפוס דגל ה-override של תוצאות החיפוש ב-`MapRegionManager` כאשר המשתמש מזיז את המפה באופן יזום.

---

## תקלה 4: חיפוש קו 31 מחזיר לעיתים רשימה ריקה ולעיתים תוצאות (Search Lines Inconsistency)

### חומרה: בינונית (P1)
### תסמינים למשתמש:
חיפוש מספר קו (למשל קו 31) מציג רשימה ריקה או תוצאות לא עקביות, במיוחד לאחר בחירת קו קודם או הקלדת שם עיר בצמוד למספר הקו.

### מיקום מדויק בקוד:
- **קובץ 1:** [MOTCompatibilityDataLoader.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift#L280-L308)
- **קובץ 2:** [SearchRequest.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/Search/SearchRequest.swift#L155-L163)
- **קובץ 3:** [MapRegionManager.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/Mapping/MapRegionManager.swift#L909-L928)

### ראיות מהקוד והשרת:
1. ב-[MOTCompatibilityDataLoader.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift#L295):
   ```swift
   let filtered = lines.filter { line in
       line.routeName.localizedCaseInsensitiveContains(query) ||
       (line.cityName?.localizedCaseInsensitiveContains(query) == true)
   }
   ```
   כאשר משתמש מקליד "31 ירושלים", שאילתת ה-`query` היא המחרוזת כולה. הסינון המקומי בודק האם `routeName` מכיל את "31 ירושלים". מכיוון ש-`routeName` ב-DTO הוא המחרוזת `"31"` בלבד, הבדיקה נכשלת והרשימה מוחזרת ריקה!
2. יתרה מזאת: כאשר המשתמש בחר קו קודם (למשל קו 64), ה-`SearchManager` ב-OBAKit שומר את תוצאת הניווט האחרונה. אם המפה בתנועה ו-`lastVisibleMapRect` ריק באופן רגעי, חיפוש הקו הבא נכשל או מחזיר "No Region Selected".

### סיבת שורש:
סינון מחרוזת קשיח שאינו מפרק את מחרוזת החיפוש לטוקנים נפרדים (מספר קו + עיר), בשילוב עם תלות רגעית ב-`lastVisibleMapRect`.

### תיקון מוצע:
פירוק מחרוזת החיפוש לטוקנים: בדיקה שמספר הקו מתאים לספרות, ושם העיר מתאים לשאר המחרוזת, תוך ביצוע חיפוש ישיר מול `SearchLines`.

---

## תקלה 5: נתונים גולמיים ומזהים טכניים מוצגים למשתמש (`mot:stop:2899`, `mot:route:12416`)

### חומרה: בינונית (P2)
### תסמינים למשתמש:
המשתמש רואה מחרוזות פנימיות של המערכת כגון `mot:stop:2899` או `mot:route:12416` בכותרות, בהודעות שגיאה ובמסכי מעבר, במקום מספר תחנה (2899) או מספר קו (31). יחידות המרחק מוצגות לעיתים במיילים.

### מיקום מדויק בקוד:
- **קובץ 1:** [AppSheetViewFactory.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/Sheet/DI/AppSheetViewFactory.swift#L561, #L582)
- **קובץ 2:** [Identifiers.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Contracts/Identifiers.swift#L107-L117)
- **קובץ 3:** [Formatters.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKitCore/Utilities/Formatters.swift)

### ראיות מהקוד:
1. ב-[AppSheetViewFactory.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/Sheet/DI/AppSheetViewFactory.swift#L582):
   ```swift
   Text("Unimplemented route: \(route.id)")
   ```
   השדה `route.id` מכיל את המזהה ה-Scoped הפנימי של OBA (`"mot:route:12416"`).
2. ב-[Formatters.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKitCore/Utilities/Formatters.swift): ה-`MKDistanceFormatter` אינו מאולץ להשתמש בשיטה מטרית (`.metric`), ולכן מכשירים בהגדרת אנגלית-ארה"ב מציגים מרחקים במיילים.

### סיבת שורש:
שימוש ב-ID הטכני הפנימי של OneBusAway כ-Fallback לתצוגה, והיעדר כפיית שיטה מטרית בפורמטר המרחקים.

### תיקון מוצע:
1. חילוץ מספר הקו (`route.shortName`) או מספר התחנה (`stop.code`) בכל תצוגה.
2. הגדרת `formatter.unitStyle = .metric` עבור מחוז ישראל.

---

## תקלה 6: איבוד מיקום ה-GPS של האוטובוס בזמן אמת (Real-Time Vehicle Location Dropped)

### חומרה: בינונית-גבוהה (P1)
### תסמינים למשתמש:
האפליקציה מציגה "זמן אמת" (בדקות שנותרו להגעה), אך אינה מציגה את סימון האוטובוס הנוסע על גבי המפה.

### מיקום מדויק בקוד:
- **קובץ 1:** [MOTItineraryMapper.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OTPAdapter/MOTItineraryMapper.swift#L123)
- **קובץ 2:** [OBACompatibilityBridge.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/OBACompatibilityBridge.swift#L252-L256)

### ראיות מהקוד והשרת:
1. שרת משרד התחבורה מחזיר ב-`Routes/GetNextStopTimesAndLocation` אובייקט מלא:
   `{ "isRealTime": true, "routeLocation": { "lat": 31.789, "lng": 35.215, "speed": 34 } }`.
2. ב-[MOTItineraryMapper.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OTPAdapter/MOTItineraryMapper.swift#L123), הממפה קורא רק את ה-Boolean `isRealTime`, ומתעלם מ-`routeLocation`.
3. ב-[OBACompatibilityBridge.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/OBACompatibilityBridge.swift#L252), האובייקט `tripStatus` שמכיל את קואורדינטות הרכב הושמט במפורש בהערה `// Omit tripStatus for now`.
4. היעדר `tripStatus` מונע מ-OBAKit ליצור `VehicleAnnotation` על המפה.

### סיבת שורש:
השמטה מכוונת של שדות המיקום של הרכב במתאם ה-Bridge.

### תיקון מוצע:
אכלוס אובייקט `tripStatus` עם הקואורדינטות שהתקבלו מ-`routeLocation`, מה שיאפשר ל-OBAKit להציג את האוטובוס בזמן אמת.

---

## תקלה 7: היעדר מוחלט של הגדרות סינון מסלול בממשק (Missing Route Planning Filters)

### חומרה: בינונית (P2)
### תסמינים למשתמש:
אי אפשר לבחור מסלול ללא החלפות, אי אפשר לבחור מיון לפי הליכה מועטה, ואי אפשר לסנן רק"ל או רכבת.

### מיקום מדויק בקוד:
[MOTTripPlanningAPIService.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OTPAdapter/MOTTripPlanningAPIService.swift#L65-L85)

### סיבת שורש:
פרמטרי החיפוש מקודדים כערכים קבועים (hardcoded constants) במקום להיות מוזנים מאובייקט `TripPlanningOptions`.

### תיקון מוצע:
חשיפת `TripPlanningOptions` בממשק המשתמש של OBAKit והעברתם ישירות ל-`MOTTripPlanningAPIService`.
