# דוח פערי ממשק משתמש והגדרות — UI Feature Gap Report
**תאריך בדיקה:** 18 באוקטובר 2026  
**השוואה בין:** אתר משרד התחבורה הרשמי ([route.bus.gov.il](https://route.bus.gov.il/)) מול אפליקציית iOS [onebusaway-ios](file:///c:/Users/DAVID/Code/onebusaway-ios).

---

## 1. טבלת השוואת הגדרות תכנון מסלול (Trip Planning Options)

באתר הרשמי של משרד התחבורה קיים פאנל הגדרות מתקדמות ("אפשרויות חיפוש נוספות") המשפיע ישירות על הפרמטרים הנשלחים ל-API (`RoutePlanning/GetRoutes`).  
באפליקציה הנוכחית, רוב הפרמטרים הללו מקודדים קשיח (hardcoded) בקובץ [MOTTripPlanningAPIService.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OTPAdapter/MOTTripPlanningAPIService.swift#L65-L85) ללא כל ייצוג ב-UI.

| אפשרות באתר הרשמי | פרמטר ב-API של משרד התחבורה | ערך שנשלח באפליקציה | סטטוס באפליקציה | השפעה על המשתמש |
| :--- | :--- | :--- | :--- | :--- |
| **נסיעות ישירות בלבד** | `changes: false` (בוליאני) | מקודד קשיח: `changes: true` | ❌ חסר ב-UI | נוסע המעוניין בקו ישיר נאלץ לראות מסלולים עם החלפות. |
| **אופן מיון תוצאות** | `sortBy`: 0 (משוקלל), 1 (משך נסיעה), 2 (מינימום הליכה), 3 (מינימום החלפות) | מקודד קשיח: `sortBy: 0` | ❌ חסר ב-UI | לא ניתן למיין לפי מינימום הליכה עבור אנשים עם מוגבלות או משא כבד. |
| **סינון אמצעי תחבורה** | `transportations`: מערך מחרוזות מתוך `["bus", "train", "lightRail", "carmelit", "cableCar", "car"]` | מקודד קשיח: `["bus", "train", "lightRail"]` | ❌ חסר ב-UI | לא ניתן לבודד נסיעה ברק"ל בלבד בירושלים או גוש דן, ולא ניתן לבטל רכבת ישראל. |
| **זמן הליכה מקסימלי** | `maxWalkTime`: 5, 10, 15, 20, 30 (דקות) | מקודד קשיח: `maxWalkTime: 120` | ❌ חסר ב-UI | האפליקציה עלולה להציע מסלולים עם הליכות ארוכות ולא סבירות (עד שעתיים הליכה). |
| **זמן נסיעה מקסימלי** | `maxTravelTime`: מספר דקות | מקודד קשיח: `maxTravelTime: 600` | ❌ חסר ב-UI | קבוע ל-10 שעות ללא שליטה. |
| **הימנעות מכבישי אגרה** | `avoidTolls`: true / false | לא נשלח (ברירת מחדל false) | ❌ חסר ב-UI | רלוונטי לתכנון מסלול משולב רכב (חנה וסע). |
| **שילוב רכב פרטי (חנה וסע)** | `transportations: ["car", ...]` | לא נשלח | ❌ חסר ב-UI | האתר מאפשר לתכנן נסיעה ברכב לחניון "חנה וסע" ומשם בתחבורה ציבורית. |
| **החלפת כיוון נסיעה (Swap)** | כפתור החלפת מוצא ויעד בלחיצה אחת | נתמך חלקית ב-UI של OBA | ⚠️ חלקי | בלחיצה על החלפה, לעיתים נדרש איפוס שדות חיפוש. |

---

## 2. פערי ממשק במסך פרטי תחנה (Stop Details)

| תכונה באתר הרשמי | תמיכה בשרת משרד התחבורה | מצב באפליקציה | קובץ רלוונטי בקוד | פער ודרישת תיקון |
| :--- | :--- | :--- | :--- | :--- |
| **מספרי רציפים** | מחזיר `platformNumber` במסגרת `GetStopFullData` | השדה נמחק במיפוי | [MOTStopMapper.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Core/Mappers/Stops/MOTStopMapper.swift) | בתחנות מרכזיות וברכבת המשתמש אינו יודע מאיזה רציף יוצא הקו. |
| **לוח זמנים מתוכנן מלא לתחנה** | מחזיר מערך `timetable` מלא לכל ימות השבוע | מוצגות רק נסיעות קרובות | [OBACompatibilityBridge.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/OBACompatibilityBridge.swift#L230-L260) | המשתמש אינו יכול לראות את שעות היציאה המאוחרות של היום. |
| **חיווי נגישות לתחנה** | שדות `isAccessible`, `hasElevator`, `audioGuidance` | לא מוצג | [TransitDomainModels.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Contracts/TransitDomainModels.swift) | חסר תג נגישות ויזואלי בתחנה. |
| **סינון קווים עוברים** | קיימת אפשרות סינון לפי מספר קו | לא קיים בתצוגת התחנה | תצוגות OBAKit | המשתמש נאלץ לגלול ברשימה ארוכה בתחנות עמוסות. |

---

## 3. פערי ממשק במסך קו ורשימת תחנות (Route & Stops Details)

| תכונה באתר הרשמי | תמיכה בשרת משרד התחבורה | מצב באפליקציה | קובץ רלוונטי בקוד | פער ודרישת תיקון |
| :--- | :--- | :--- | :--- | :--- |
| **רשימת תחנות של קו** | `Routes/GetRouteStops` מחזיר את כל רשימת התחנות | **שגיאה: "stop list isn't available"** | [MOTCompatibilityDataLoader.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift#L44-L102) | קריטי: לחיצה על קו ברשימת חיפוש מציגה שגיאה במקום רשימת התחנות שלו. |
| **החלפת כיוון הקו** | `oppositeDirectionRoute` מחזיר את הכיוון הנגדי | לא מוצג מתג כיוונים | [RouteFullDataResponseDTO.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Core/DTO/Scheduler/RouteFullDataResponseDTO.swift#L35) | המשתמש אינו יכול לעבור לכיוון הנגדי של אותו קו ללא חיפוש חדש. |
| **זמני הגעה של כל תחנה במסלול** | זמני מעבר מתוכננים ומדויקים בכל תחנה | חסר | מודל `Trip` ב-OBAKit | מוצג רק שם התחנה ללא שעת הגעה צפויה אליה. |
| **לוח זמנים שבועי לקו** | `Routes/GetRouteFullData` מחזיר אובייקט `calendar` | נמחק במיפוי | [MOTRouteMapper.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Core/Mappers/Routes/MOTRouteMapper.swift) | אין לוח נסיעות שבועי של הקו. |

---

## 4. פערי מפה ושכבות מידע (Map Layers & Real-Time Tracking)

| תכונה באתר הרשמי | תמיכה בשרת משרד התחבורה | מצב באפליקציה | קובץ רלוונטי בקוד | השפעה |
| :--- | :--- | :--- | :--- | :--- |
| **מעקב אחר אוטובוס פעיל בזמן אמת** | `Routes/GetNextStopTimesAndLocation` ו-`GetRouteLocations` מחזירים קואורדינטות GPS ומהירות | המיקום נמחק במיפוי | [MOTItineraryMapper.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OTPAdapter/MOTItineraryMapper.swift#L123), [OBACompatibilityBridge.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/OBACompatibilityBridge.swift#L252-L256) | המשתמש אינו רואה אייקון של אוטובוס מתקדם על המפה במסלול הנסיעה שלו. |
| **שכבת חניוני "חנה וסע"** | `Location/GetMapParkAndGoLots` מחזיר חניונים ותפוסה | לא קיים | - | אי אפשר לראות חניוני חנה וסע במפה. |
| **שכבת עמדות רב-קו** | `Location/GetMapRavKavStations` מחזיר נקודות שירות | לא קיים | - | אי אפשר למצוא עמדות טעינה ושירות רב-קו. |
| **טעינת תחנות במפה ללא מגבלה** | `Location/GetMapStops` תומך ב-Bounding Box מלא | האפליקציה משתמשת ב-`GetStopsCloseToLocationByRadius` המוגבל ל-10 תחנות | [MOTEndpoints.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Core/HTTP/MOTEndpoints.swift#L70), [MOTCompatibilityDataLoader.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift#L160) | תחנות נעלמות או מוצגות בדלילות רבה בזמן גלילה או שינוי זום. |

---

## 5. יחידות מידה ושפה (Localization & Units)

| נושא | אתר משרד התחבורה | אפליקציית iOS | קובץ רלוונטי בקוד | פער |
| :--- | :--- | :--- | :--- | :--- |
| **יחידות מרחק** | תמיד מטרים וקילומטרים (מטרי) | תלוי בהגדרת ה-Locale של המכשיר (`MKDistanceFormatter`) | [Formatters.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKitCore/Utilities/Formatters.swift) | במכשירים שהשפה הראשית בהם היא אנגלית (US), מרחקי הליכה בישראל מוצגים במיילים ורגליים (Miles / Feet). |
| **טקסטים באנגלית** | תרגום שמות תחנות וקווים דרך סגמנט `/en/` | מחרוזות מזהים פנימיות כמו `mot:stop:2899` דולפות לממשק | [AppSheetViewFactory.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/Sheet/DI/AppSheetViewFactory.swift#L561), [Identifiers.swift](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Contracts/Identifiers.swift) | המשתמש רואה מזהים טכניים באנגלית במקום שמות בעברית/אנגלית. |
