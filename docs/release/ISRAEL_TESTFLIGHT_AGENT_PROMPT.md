# משימת סוכן — העלאה בטוחה ל־TestFlight ואיסוף דוחות קריסה

**הקשר:** OneBusAway Israel קורסת באייפד כאשר מרחיקים זום ומרחיבים את המפה. בעל הפרויקט רוצה להפיץ גרסת TestFlight **פנימית וחתומה** כדי לקבל Crash Reports ודוחות זיכרון, ללא שימוש בכבל USB, ללא iMazing, ללא מיזוג ל־main וללא פרסום לציבור.

מאגר: https://github.com/davidpovarsky/onebusaway-ios

ענף פיתוח תשתית ההפצה: `feature/israel-testflight-signing-crash-diagnostics`. ה־Workflow וקובצי העזר מותקנים גם בענף ברירת המחדל `main` כדי שיופיעו ב־Actions ויאפשרו להריץ כל ענף/Tag/SHA, כולל main, בלי להעביר את קוד IsraelMOT אל main.

**חובה להתחיל בקריאת הקבצים שכבר הוכנו**, ולא לשכתב תהליך:
- `docs/release/ISRAEL_TESTFLIGHT_SETUP.md` — זהויות, הרשאות וחוסרים מאומתים.
- `.github/workflows/israel-testflight.yml` — תהליך ידני עם מצבי `validate` ו־`upload`.
- `scripts/ci/prepare_israel_testflight.py` — התאמת XcodeGen בזמן בנייה בלבד.
- `scripts/ci/verify_israel_profiles.py` — אימות חתימות ופרופילים.
- `scripts/ci/check_israel_testflight_spec.py` — אימות התוצאה לאחר איחוד XcodeGen.
- `AGENTS.md`, `docs/ai-team/TEAM.md`, `docs/ai-team/PROJECT_ASSIGNMENTS.md`.

מטרתך: להשלים את ההכנה בצד Apple/GitHub, לאמת את תהליך הבנייה ואת החשבון בפועל, **ולבצע את ההעלאה המורשית לגרסת TestFlight פנימית**, אם כל שערי הבטיחות והחתימה עוברים.

## 1. עבודת צוות והגנות Upstream

בצע האצלה אמיתית בהתאם ל־AGENTS.md: **תומר** לאינטגרציה ו־CI, **דנה** לאימות ההרשאות והחתימה, **רוני** ל־QA עצמאי. אם בממשק אין תמיכה בסוכני משנה, דווח על כך ואל תייחס פעולות לאנשים שלא הופעלו.

אל תשנה את `Apps/OneBusAway/project.yml`, `OBAKit`, `OBAKitCore`, `OBAWidget` או את המנועים הפנימיים אלא אם נמצאה הכרחיות מוכחת. זהויות App Store מתחלפות ב־`project.yml` הזמני והמתעלמים ממנו ב־Git, לא בקובצי המקור.

אל תיגע ב־`fastlane beta` או ב־`testflight.yml` של upstream. התהליך החדש חייב להיות `workflow_dispatch` ידני בלבד; בלי הפעלה אוטומטית על push, בלי merge ל־main.

עבוד על ענף ההפצה הייעודי. הקפד ש־SHA של גרסת TestFlight תואם בדיוק לבנייה שנבדקה.

## 2. חשבון Apple — אימות אמיתי ולא ניחוש

בדוק דרך חשבון Apple המחובר במערכת, או באמצעות API מורשה:
- האם קיים מנוי Apple Developer בתשלום ובאיזה Team ID.
- האם מפתח App Store Connect הקיים מורשה להקים/לנהל App IDs, פרופילים, אפליקציות ובדיקות TestFlight.
- האם כבר קיימים מזהי האפליקציה המוצעים. אל תיצור כפילויות.
- האם תעודת Apple Distribution הקיימת בפרויקט Maktabah שייכת לאותו צוות, תקפה, והמפתח הפרטי שלה זמין בבניית CI.
- האם קיים רישום App Store Connect התואם ל־Bundle ID המיועד.

אם האתר מבקש 2FA, אפשר לבקש מהבעלים להשלים אימות פעם אחת. אין לבקש סיסמאות או מפתחות בצ'אט.

**אין להחליף, למחוק או לבטל תעודת חתימה העובדת בפרויקט אחר.**

## 3. רישום המשאבים המדויקים

השתמש בערכים המוגדרים במסמך ההתקנה, בכפוף לאימות שאין התנגשויות:
- Main Bundle ID: `com.davidpovarsky.onebusawayisrael`.
- Widget Bundle ID: `com.davidpovarsky.onebusawayisrael.OBAWidget`.
- App Group לשניהם: `group.com.davidpovarsky.onebusawayisrael`.
- שם אפליקציית App Store Connect: `OneBusAway Israel` או חלופה מתועדת אם השם תפוס.
- SKU: `onebusaway-israel-ios`, שפה ראשית עברית, iOS.
- ב־App ID הראשי: App Groups, HealthKit, Push Notifications.
- ב־Widget App ID: App Groups.
- אין Associated Domains של OneBusAway המקורית ואין Apple Pay Merchant שאינו בבעלותנו.
- אין Watch app בשלב הנוכחי.

צור רק משאבים חסרים: מזהי Bundle, App Group, שיוך יכולות, רישום App Store Connect ושני פרופילי App Store Distribution תקפים עבור App ו־Widget, על אותה תעודת Distribution.

צפה במספר האפליקציה החדש (Apple numeric App ID) ושמור אותו בשם GitHub Repository Variable: `ISRAEL_APP_STORE_CONNECT_APP_ID`. לעולם אל תשאיר את מספר האפליקציה המקורית של OneBusAway.

## 4. תשתית סודות GitHub

במאגר OneBusAway אין כרגע את הסודות הנחוצים, ואילו בפרויקט Maktabah קיימים שמות הסודות הרלוונטיים. בדוק בעצמך שמות, קיום, בעלות והרשאות.

נדרשים במאגר OneBusAway: `APPLE_TEAM_ID`, `APPLE_CERTIFICATE_P12_B64`, `APPLE_CERTIFICATE_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ISRAEL_APP_PROVISIONING_PROFILE_B64`, `ISRAEL_WIDGET_PROVISIONING_PROFILE_B64`.

ששת ערכי צוות/תעודה/API ניתנים לשימוש חוזר רק לאחר אימות אותו Team ID. שני הפרופילים חייבים להיות חדשים ל־Bundle IDs שנבחרו; אין להשתמש בפרופיל Maktabah עבור OneBusAway.

**אבטחה מחייבת:** לא להציג במסך, בלוג או בתוצרי Actions את תוכן המפתחות, הסיסמאות, ה־JWT, קובצי P8/P12 או ה־mobileprovision. השתמש בזרימת credentials מוצפנת מאושרת בלבד; אם אי אפשר לגשת לערכים המוגנים — הסבר מה חסר, אל תמציא ואל תשתמש במעקף לא מאובטח.

## 5. הרצת בנייה ובדיקות

תחילה הרץ את ה־Workflow הרשום ב־`main` במצב `operation=validate` עם בחירת המקור הרצוי: `source_ref` ריק = ענף שנבחר ב־Actions; לחלופין `source_ref` = שם כל ענף אחר, תג או SHA. הרץ בדיקה גם על `main` וגם על ענף IsraelMOT, ללא ערבוב קוד ביניהם.
בדוק במפורש:
1. Xcode ו־XcodeGen מייצרים פרויקט מה־manifest המקורי.
2. `prepare_israel_testflight.py` משנה רק את ה־manifest הזמני; הקובץ המקורי נשאר זהה.
3. `xcodegen dump --type json` והסקריפט `check_israel_testflight_spec.py` מאמתים App/Widget, Entitlements ו־App Group.
4. כל 11 קבוצות בדיקות IsraelMOT עוברות (כולל SQLite, מיפוי, Trip Planning, Registry ו־API adapters).
5. אם יש כשל, בדוק את השגיאה המדויקת ותקן רק את רכיב תהליך ההפצה; אל תשנה את קוד המפה כדי להעלים את הקריסה לפני שאוספים אבחנה.
6. בצע ביקורת סופית שאין אף קובץ מפתח, סיסמה, פרופיל הפצה או generated spec רגיש שנכנס ל־Git.

לאחר מכן, אם כל פרטי Apple הושלמו, הרץ `operation=upload` עם `expected_sha` שהוא ה־SHA המלא והמאומת של הענף. ה־Workflow חייב:
- לאמת את שני פרופילי ה־App Store ואת התעודה, ללא הצגת מידע רגיש.
- לבנות Archive Release חתום על macOS, כולל Widget ו־`IsraelStopCatalog.sqlite`.
- לייצא IPA חתום באמצעות `app-store-connect` ולבדוק ב־IPA האמיתי את מזהי App/Widget.
- לשמור קובצי `dSYM` המתאימים ל־Build UUID, כדי לפענח קריסות.
- לבצע `altool --validate-app` ואז `--upload-app`, לא להעביר IPA לא חתום.
- לדווח בנפרד על ACCEPTED_UPLOAD, PROCESSING, COMPLETE/READY_TO_TEST ו־FAILED; הצלחת פקודת העלאה לבדה אינה נחשבת לזמינות ב־TestFlight.
- להוסיף את בעל החשבון לקבוצת Internal Testers ולהמתין שהגרסה תהיה זמינה להתקנה, ללא פרסום ציבורי.

אין לשנות את פרופילי החתימה או לקבוע הרשאות נוספות שאינן חיוניות.

## 6. דוח הקריסה וקריסת הזום

כאשר גרסת TestFlight מופיעה בחשבון וניתנת להתקנה:
- בצע בדיקת קבלה פיזית באייפד: בחר אזור ישראל, פתח מפה, התקרב לרמת רחוב, התרחק לזום עירוני וארצי וחזור כמה פעמים.
- ודא שהקריסה נצפית במכשיר המשתמש, ושה־Bundle ID/Build שבדוח תואמים בדיוק ל־IPA המופץ.
- פתח TestFlight > Feedback / App Store Connect > TestFlight > Crashes, או שלוף דרך API ייעודי, לפי ההרשאות.
- הורד Crash Report וסמלל אותו בעזרת `dSYMs` מה־Workflow לפי UUID, לא לפי שם בלבד.
- אם מדובר ב־Jetsam/Memory termination ולא מתקבל Crash Report סטנדרטי, בקש אבחון זיכרון מתאים; אין להכריז שהקריסה נפתרה רק בגלל שאין דוח.
- בדוק את `IsraelStopCatalogRepository.viewportStops` ואת מעברי הזום/אשכולות, עומס סמני MapKit, ביטול תוצאות ישנות, ועומס Main Thread; אלה חשדות סבירים, **לא סיבת שורש מאומתת**.

תיעוד קריסה נדרש: תאריך, שעה, סוג מכשיר, גרסת iPadOS, SHA, מספר Build, סוג הדוח, Backtrace מסומל, מדדי זיכרון אם קיימים, והשערת שורש מאומתת או מפורשת כלא־מאומתת.

אל תתקן את לוחות הזמנים הפיקטיביים במהלך משימת חתימה זו; זו תקלה נפרדת שזוהתה בעבר, שחייבת טיפול בהמשך. המטרה היא קודם להגיע למנגנון TestFlight ודוחות קריסה אמין.

## 7. סיום והגשת ראיות

בסיום הצג:
- Apple Team ID **המאומת**, App Bundle ID, Widget Bundle ID ו־App Group.
- App Store Connect numeric App ID, קישור לרשומה וקבוצת הבודקים הפנימית.
- מספר ריצת GitHub Actions, סטטוס CI, SHA מלא, build/version ו־IPA signing verification.
- קישור לארטיפקט `dSYMs`, תוקף הארטיפקט ו־UUID של הסמלים.
- סטטוס העלאה וסטטוס עיבוד Apple, האם אפשר כבר להתקין, וקישור/הנחיות TestFlight לבעלים.
- פירוט קצר מה נשאר פתוח — בלי להציג משימה חלקית כמושלמת.
- רשימת כל קובצי upstream ששונו; מצופה **אפס** שינויים בקוד upstream.

אין למזג **קוד מוצר** ל־main; מותר להתקין ב־main רק את קובצי Workflow וקובצי העזר כדי לרשום את תהליך GitHub Actions. אין App Store public submission, אין יצירת מפתחות מיותרים ואין שינוי Asana ללא בקשה מפורשת של הבעלים במשימה זו.

**המשך ברצף כל עוד ניתן לבצע בשלמות ובאופן מאובטח. אל תעצור לבקשת אישור על פעולות בדיקה שגרתיות. אם נדרשים פרטי כניסה/2FA או פעולת בעל־חשבון שאי אפשר לבצע אוטומטית, עצור רק בנקודה זו וציין בדיוק מה חסר.**
