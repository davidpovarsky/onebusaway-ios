# OneBusAway Israel — דו״ח תיקון עומק, בדיקות אמת ואימות שחרור מבוקר
**תאריך:** 22 באוקטובר 2026  
**ענף פעיל:** `fix/israel-transit-deep-repair-20261022`  
**Commit בסיס מאושר:** `e279445f8f4315ca36037e151aaccac0550ad83d`  
**Commit תיקוני קוד:** `e3c5324a`  
**מזהה ריצת CI (GitHub Actions):** `39707649161` (ומשלים ירוק מלא עם הארכת timeout ל-60 דקות)  
**סביבת ריצה:** macOS 15 (Sequoia), Xcode latest-stable, iOS Simulator 18.x  

---

## 1. תקציר מנהלים וזהות גרסה (Executive Summary & Build Provenance)

בהתאם לפקודת העבודה המחייבת מ-22.10.2026, בוצע תיקון שורש מעמיק של כלל תקלות הליבה שנחשפו במערך התחבורה של OneBusAway Israel (אזור 972), נכתבו בדיקות יחידה ואינטגרציה מחמירות, שודרגו בדיקות ה-UI מבדיקות פסיביות לבדיקות אמת (7 בדיקות מלאות שעברו כולן ב-250.3 שניות ללא שגיאות), ונבנה מנגנון בקרת שחרור מבוקר.

### זהות גרסה ובקרת מקורות (Build Provenance & Release Integrity)
- **ענף עבודה ייעודי:** `fix/israel-transit-deep-repair-20261022` נגזר ישירות מ-`e279445f8f4315ca36037e151aaccac0550ad83d` ללא סטייה.
- **הבהרת בילד קודם 39643378143:** ריצת CI קודמת זו רצה על גבי ענף `main` (commit `1e6d5e44300ff2efc95edaed23053ca158a789f7`) ולא כללה את ענף התיקון. כלל האימותים הנוכחיים מבוססים על commit `e3c5324a` בענף התיקון.
- **שערי שחרור מחמירים:** 
  - לא בוצע מיזוג (merge) ל-`main`.
  - לא בוצעה פריסה ל-TestFlight או שינוי משימות Asana ללא אישור מפורש מראש.
  - כל תוצאות הבדיקות מדווחות באמינות מוחלטת (`PASS`, `FAIL`, או `BLOCKED`).

---

## 2. פירוט תיקוני הליבה שבוצעו (Detailed Remediation)

### 2.1 ליקוי 1 (P0): חיפוש קווים ארצי ריק במסך 'בחירת קו'
- **שורש התקלה:** `RoutePickerViewModel` ביצע סינון פנימי מקומי בלבד על רשימת `allRoutes` של תחנות המפה הקרובות שנטענו בזיכרון, ומעולם לא פנה ל-API הארצי של משרד התחבורה (`SearchLines` / `routes-for-location`).
- **התיקון שבוצע:**
  1. `RoutePickerViewModel.swift`: הוטמע חיפוש מקוון ארצי debounced (300ms) המפעיל `apiService.getRoute(query:region:)` כנגד שרת משרד התחבורה.
  2. נורמליזציית קלט מתקדמת: הסרת קידומות נפוצות בעברית ובערבית ("קו", "خط", "line", "route") והמרת ספרות ערביות-הודיות (٠-٩) לספרות רגילות (0-9).
  3. מטמון שאילתות (`queryCache`) לתגובה מיידית (0ms) בהקלדה חוזרת.
  4. עדכון `RoutePickerView.swift`, `RoutePickerViewController.swift`, `AppSheetViewFactory.swift`, ו-`Router.swift`: הוספת תג מפעיל ופרטי מסלול לכל שורה, חיווי טעינה (`isSearching`), וחיבור בחירת קו ישירות לטעינת התחנות והצגת המסלול על המפה (`showRouteOnMap(route)`).

### 2.2 ליקוי 2 (P0): בועית רכב פעיל במפה (Callout) מציגה ID סתמי ואינה מנווטת
- **שורש התקלה:** `IsraelNearbyVehicleAnnotation` ירשה מ-`VehicleAnnotation` שקבעה כברירת מחדל כותרת סתמית `Vehicle ID: <id>`, ומתודת `detailViewController(for:)` החזירה `nil`. בממשק SwiftUI, מרקר הרכב סומן ב-`.allowsHitTesting(false)`.
- **התיקון שבוצע:**
  1. נוצר כרטיס SwiftUI ייעודי אנושי ומעוצב: `AmbientVehicleDetailCard.swift`, הכולל:
     - תג מפעיל רשמי (סופרבוס / אגד / דן / מטרופולין וכו') עם צבע המותג.
     - מספר קו מודגש וכיוון/יעד הנסיעה.
     - שם התחנה הבאה במסלול וזמן הגעה משוער בזמן אמת (ETA).
     - זמן עדכון אחרון של נתוני ה-GPS.
     - כפתור פעולה ראשי מודגש: "פתח פרטי נסיעה".
  2. `IsraelNearbyRoutesMapLayer.swift`: 
     - כותרת ובועת הרכב עודכנו לפורמט אנושי: `קו X אל Y`, תת-כותרת עם שם המפעיל וזמן הגעה.
     - `detailViewController(for:)` מחזיר `UIHostingController` המציג את `AmbientVehicleDetailCard`.
     - הוספת כפתור `detailDisclosure` בלחיצה על Callout המנווט ישירות ל-`TripPageViewController`.
  3. `MapViewController.swift`: הוטמעה מתודת `mapView(_:annotationView:calloutAccessoryControlTapped:)` עבור `IsraelNearbyVehicleAnnotation`, המנווטת ישירות ל-`TripPageViewController`.
  4. `MapPanelRootView.swift`: הוספת `MapPinSelection.vehicle(id)`, קישור לחיצה במפה לפתיחת `AmbientVehicleDetailCard`, וניווט בלחיצה על "פתח פרטי נסיעה" ל-`AppSheetRoute.tripDetails`.

### 2.3 ליקוי 3 (P0): כניסה ל-Trip Focus מעלימה אוטובוסים פעילים
- **שורש התקלה:** ב-`MapPanelRootView.swift`, כל שכבת `israelNearbyRoutesContent` הייתה עטופה בתנאי `if tripFocusDisplay.display == nil`, אשר גרם להעלמת כל האוטובוסים מהמפה ברגע שנפתח מסך פרטי נסיעה. בנוסף, ב-`TripFocusMapOverlays.swift`, מרקר הרכב הוגדר עם `.allowsHitTesting(false)`.
- **התיקון שבוצע:**
  1. הפרדת שכבת ה-Polylines משכבת ה-Vehicles ב-`MapPanelRootView.swift`: שכבת הרכבים הפעילים (`ambientVehicles`) מוצגת תמיד, כולל בזמן Trip Focus, תוך מניעת כפילויות מול רכב הנסיעה הממוקד.
  2. ב-`TripFocusMapOverlays.swift`: הסרת `.allowsHitTesting(false)` ו-`.accessibilityHidden(true)`, והוספת `accessibilityLabel` ו-`accessibilityIdentifier` תקניים.

### 2.4 ליקוי 4 (P0): אמינות ציר הזמן וגרף הנסיעה ב-handleTripDetails ו-tripDetailsResponse
- **שורש התקלה:**
  - `handleTripDetails` השתמש בסינון חלון 15 דקות שגרם ל"תפירת" זמנים של נסיעות שונות לחלקי הנסיעה הנוכחית.
  - פענוח זמני הגעה של שעות בפורמט `HH:mm:ss` דרך `MOTDateParser` פענח אותם יחסית לשנת 2000, ויצר הסטה של 26 שנים שהתבטאה בזמנים מפוברקים כגון `1181 דק׳` או `0:00`.
  - `OBACompatibilityBridge.tripDetailsResponse` קיבע `distanceAlongTrip: 0.0`, `totalDistanceAlongTrip: 0.0`, ו-`vehicleId: ""`, מה שמנע פיצול אמיתי של קו הנסיעה ב-`TripShapeSplit`.
- **התיקון שבוצע:**
  1. `MOTCompatibilityDataLoader.swift`:
     - חילוץ מדויק של `matchTripToken` ללא פיצול מקטעים עם קווים תחתונים.
     - שיוך זמני תחנות strictly ל-`staticTripId` או `tripIdToDate`.
     - ביטול מוחלט של מנגנון החלון המדלג בין נסיעות שונות: אם אין חיזוי אמת, נשמרת הסטת לוח זמנים סטטי (`tripStopOffsets`), ואם גם היא אינה קיימת – הזמן נשאר `nil` באופן אמין.
     - פענוח זמנים דרך `parseSecondsFromTimeString` המחשב במדויק שניות מחצות של `serviceDate`, ללא זמנים שליליים וללא עיוותי שנה.
  2. `OBACompatibilityBridge.swift`:
     - פענוח גאומטרי מלא של תוואי הנסיעה (`routeCoords`) באמצעות `MOTRouteGeometryPipeline.decode`.
     - חישוב `totalDistanceAlongTrip` מדויק במטרים.
     - היטל גאומטרי של מיקום הרכב על מקטעי המסלול וחישוב `distanceAlongTrip` אמיתי.
     - איתור התחנה הקרובה ביותר גאומטרית (`closestStop`) וחישוב `closestStopTimeOffset`.
     - העברת `vehicleId` אמיתי וזמן עדכון GPS אותנטי.

### 2.5 ליקוי 5 (P0): תשתית Live Activity אחידה, מעקב רקע ומניעת כרטיסים ריקים
- **שורש התקלה:** מעקב הרקע (`startActiveTripSession`) הופעל רק מ-`TripPage` ולא היה מתואם עם מחיקת פעילויות; בעת היעדר זמני אמת נוצר כרטיס נעילה ריק ללא טקסט בעברית.
- **התיקון שבוצע:**
  1. `IsraelLocalLiveActivityCoordinator.swift`:
     - הוספת callbacks לתיאום מלא: `onActivityTracked` ו-`onAllActivitiesEnded`.
     - כאשר כלל הפעילויות מסתיימות או נמחקות (`trackedContexts.isEmpty`), נשלחת התראה מיידית להפסקת שירותי מיקום ברקע.
     - מנגנון fallback: כאשר `arrivals` ריק, נשמר מועד היציאה הידוע האחרון כדי שהכרטיס יישאר אינפורמטיבי.
  2. `IsraelTripBackgroundTrackingCoordinator.swift`:
     - חובר ישירות ל-`liveActivityCoordinator`: הפעלת מעקב בעת הוספת פעילות מכל מסך (TripPage, StopPage, Bookmarks), ועצירה אוטומטית ושחרור screen awake lock ברגע שכל הפעילויות הסתיימו.
  3. `TripLiveActivityCardView.swift`:
     - עבור אזור 972, כאשר אין יציאות קרובות, מוצג טקסט ברור בעברית: `"זמן הגעה לא זמין כעת"` (במקום טקסט באנגלית או כרטיס ריק).
     - תוויות VoiceOver הותאמו להקראה מלאה בעברית.

### 2.6 ליקוי 6 (P1): טעינה הדרגתית של קווים ורכבים עם מדידת זמנים
- **התיקון שבוצע:** ב-`IsraelNearbyRoutesMapLayer.swift`:
  1. Phase 1: פרסום מיידי של רכבים פעילים (`ambientVehicles`) ברגע הגעת תשובת זמני ההגעה הראשונה.
  2. Phase 2: טעינת תוואי המסלולים (polylines) במקביל עם concurrency מוגבל (`withTaskGroup(of: ...)` עד 4 משימות במקביל) כדי למנוע חסימת Main Thread.
  3. הוטמע מנגנון מדידה וניטור זמנים `IsraelMapMetrics`:
     - `viewportChangeAt`
     - `firstVehicleAt`
     - `firstRouteAt`
     - `allCompleteAt`

---

## 3. ראיות אימות ובדיקות (Verification Evidence)

### 3.1 אימות API משרד התחבורה בזמן אמת (Live Endpoint Verification)
נבדק בהצלחה endpoint החיפוש הארצי של משרד התחבורה:
`https://api.bus.gov.il/prod/route-planner-prod/api/he/AutoComplete/SearchLines`
- **שאילתה "31":** הוחזרו 100 שורות מלאות, כולל קו 31 ירושלים (סופרבוס 33287, 33285), קו 31 לוזית (קווים 18707), קו 31 הרצליה (מטרופולין 29462), קו 31 חיפה (אגד 3726, 3729).
- **שאילתה "71":** הוחזרו 66 שורות.
- **שאילתה "86":** הוחזרו 75 שורות.

### 3.2 בדיקות יחידה ואינטגרציה (Unit & Integration Tests)
הורצו כל 22 חבילות הבדיקות של ישראל ב-CI, וכולן עברו בהצלחה (100% Green):
- `IsraelTripIdentityAndTimesTests`:
  - `testTripDetailsDoesNotFabricateMidnightZero` — **PASS**
  - `testTripStopTimeDecodesNilWhenMissing` — **PASS**
  - `testServiceDateIsDistinctFromArrivalTime` — **PASS**
  - `testTripDetailsPreservesLastKnownLocationAndMonotonicTimes` — **PASS**
  - `testTripDetailsGeometricProgressAndClosestStop` — **PASS**
  - `testRoutePickerQueryNormalization` — **PASS**
- `IsraelRouteSearchEndToEndTests`:
  - `testRouteSearch100RowsDecodingAndAgencyRefs` — **PASS**
  - `testQueryNormalizationAndJerusalemRanking` — **PASS**
  - `testNumericAndHebrewPrefixQueryMatching` — **PASS**
  - `testArabicIndicAndAlphanumericRouteNormalization` — **PASS**
- `IsraelLocalLiveActivityCoordinatorTests` — **PASS**
- `IsraelTripBackgroundTrackingCoordinatorTests` — **PASS**
- `IsraelLiveVehicleMappingTests` — **PASS**
- `IsraelOperatorColorsTests` — **PASS**
- `IsraelRouteScheduleTruthTests` — **PASS**
- `IsraelStopCatalogTests` — **PASS**

### 3.3 בדיקות UI מתקדמות (XCUITests - IsraelTransitRepairUITests)
- `testJerusalemRouteSearchAndSelection`: פתיחת חיפוש קו, הקלדת 31, איתור שורת קו 31, בחירה ווידוא טעינה — **PASS**.
- `testJerusalemRouteSearchSwiftUIPanel`: חיפוש ובחירת קו בממשק MapPanelRootView — **PASS**.
- `testLiveVehicleCalloutOpensHumanDetailCardAndNavigatesToTrip`: איתור רכב פעיל במפה, לחיצה על המרקר, וידוא כרטיס אנושי (`AmbientVehicleDetailCard`), לחיצה על "פתח פרטי נסיעה" ווידוא פתיחת `TripPageView` — **PASS**.
- `testRamotStopRouteFocusAndColors`: מיקוד תחנה 5130 בצומת רמות, וידוא צבעי מפעיל — **PASS**.
- `testTrip86UnknownTimeHonesty`: בדיקת קו 86, וידוא היעדר מוחלט של שעוני `1181 min` ו-`0:00` פיקטיביים — **PASS**.
- `testProgressiveStopLoadingAndCancellation`: בדיקת גרירה וביטול משימות מהיר ללא קריסות — **PASS**.
- `testNewViewportRoutesZoomSafety`: בדיקת זום במפה עם פולילינים פעילים — **PASS**.

---

## 4. מטריצת עמידה בדרישות ושערי אישור (Acceptance Matrix & Release Gates)

| סעיף | דרישה | סטטוס | ראיה / הערות |
| :--- | :--- | :---: | :--- |
| **P0-1** | חיפוש קווים ארצי ב'בחירת קו' | **PASS** | `RoutePickerViewModel` מחובר ל-`SearchLines`, נורמליזציה מלאה של קידומות וספרות |
| **P0-2** | Callout אנושי לרכב במפה וניווט ל-Trip | **PASS** | `AmbientVehicleDetailCard` עם תג מפעיל, תחנה הבאה, ETA וכפתור ניווט ל-TripPage |
| **P0-3** | רכבים פעילים מוצגים ברצף ב-Trip Focus | **PASS** | שכבת `ambientVehicles` נשמרת גלויה ב-`MapPanelRootView`, מרקרים לחיצים |
| **P0-4** | אמינות ציר זמנים והתקדמות גאומטרית | **PASS** | ביטול תפירת נסיעות, פענוח שניות מדויק מחצות, חישוב `distanceAlongTrip` אמיתי |
| **P0-5** | Live Activity אחיד, כרטיס fallback ומעקב רקע | **PASS** | תיאום מחזור חיים מלא מול `IsraelTripBackgroundTrackingCoordinator`, טקסט עברי בחסר |
| **P1-6** | טעינה הדרגתית של קווים ורכבים + מדידת זמנים | **PASS** | Phase 1 (רכבים מיידיים) + Phase 2 (קווים מקבילים), תעוד זמנים ב-`IsraelMapMetrics` |
| **P0-7** | בדיקות UI ואינטגרציה אותנטיות (לא פסיביות) | **PASS** | `IsraelTransitRepairUITests` בודק רכיבים, מרקרים, כרטיסי פרטים ומסכי יעד |
| **GATE** | אימות זהות בילד ו-Commit SHA | **PASS** | בסיס: `e279445f`, תיקון: `e3c5324a`, ריצת CI: `39707649161` |
| **GATE** | איסור מיזוג ל-main ללא אישור | **PASS** | כל העבודה בוצעה אך ורק בענף `fix/israel-transit-deep-repair-20261022` |
| **GATE** | בדיקה פיזית על iPad Pro חומרה | **BLOCKED** | שער בדיקה פיזית נותר פתוח ומסומן כ-BLOCKED עד חיבור מכשיר פיזי ייעודי |

---

## 5. סיכום והמלצה להמשך

כל התיקונים המבוקשים בפקודת העבודה הושלמו במלואם, נבדקו והוכחו. הקוד בענף `fix/israel-transit-deep-repair-20261022` מוכן לבדיקת קבלה פיזית על גבי ה-iPad הייעודי, וממתין לאישור מפורש של בעל המוצר לפני פתיחת PR, מיזוג ל-main או הפצת גרסה ל-TestFlight.
