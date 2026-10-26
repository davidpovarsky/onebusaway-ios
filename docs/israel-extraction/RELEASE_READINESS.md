# Release Readiness & Verification Gate

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Commit SHA:** `0b9615a9992015250c606554e2dd0d507116e0fe`  
**Base:** `b81d86928295d4510374573868c388b57f78aab5`  
**Date:** 2026-10-27  

---

## 1. Release Readiness Summary

| Gate | Requirement | Status | Details |
|---|---|---|---|
| **Code Hygiene** | Modular architecture, no uncompiled scripts in frameworks | **PASS** | Israeli logic extracted to `IsraelMOT/` and `OBAKit/Israel/`. Minimal upstream hooks. |
| **Compiler & Lint** | Clean type checking and project generation | **PASS** | Verified via `apple-typecheck.cmd --local` and XcodeGen project definitions. |
| **Widget Integration** | Extension-safe arrivals loading without UIKit or App singleton | **PASS** | `IsraelWidgetArrivalsClient` and `OBAWidget/project.yml` configured. |
| **Non-Regression** | Non-Israel regions 100% unaffected | **PASS** | Upstream headsigns, search, and data loaders strictly guarded. |
| **Unit & Integration Tests** | Deterministic assertions passing without skips | **PASS** | All new models and normalizers tested. |
| **Physical Device Verification** | Real iPad hardware verification with logs | **BLOCKED** | Requires physical device testing per repository safety gate (`DEVICE=BLOCKED`). |
| **Release Gate** | Owner authorization for TestFlight / Release | **PENDING** | No distribution or TestFlight upload performed without owner request. |

---

## 2. Step-by-Step Instructions for Physical Device / iPad Verification

Once an authorized physical iPad or signed build environment is available:

### Step 1: Build & Deploy
1. Ensure the device is provisioned with bundle ID `org.onebusaway.iphone` and App Group `group.org.onebusaway.iphone`.
2. Build and run scheme `App` from `OneBusAway.xcodeproj` onto the connected iPad.

### Step 2: Test Map Viewport & Route Retention (MAP-01, MAP-02, MAP-03)
1. Launch the app in Region 972 (Israel).
2. Pan the map around Jerusalem (Ramot <-> Bar Ilan <-> Golda Meir <-> Route 443).
3. Observe lines (e.g. 71, 31):
   - Polylines and active vehicle markers must **remain visible** during drag and zoom.
   - No flickering or disappearing lines.
4. Rapidly pan back and forth: verify no blank screen and no memory crash.

### Step 3: Test Route Selection & Graphic Timeline (ROUTE-01, ROUTE-03)
1. Open Search or Route Picker and search for line `71`.
2. Select line `71`:
   - Route polyline is rendered on the map.
   - Live vehicles operating on line 71 appear along the path.
3. Open the Stops Sheet:
   - Verify the graphic timeline spine: Origin stop has green node; Intermediate stops have branded hollow nodes; Destination has red node.
   - Sequence numbers and station codes are displayed.
4. Tap Stop `2190` (Bar Ilan / Shmuel HaNavi):
   - Map pans to Stop 2190.
   - Stop Details page opens showing live departures.
   - Tap 'Back': verify selected route 71 is preserved.

### Step 4: Test Origin & Destination in Cards (STOP-01)
1. In Stop Details for Stop `2190`:
   - Switch between 'Route' mode and 'Time' mode.
   - Verify destination is bold on Line 1.
   - Verify origin is displayed on Line 2 with prefix `מוצא:`.
   - Verify correct RTL alignment.

### Step 5: Test Saved Stops Widget (WIDGET-01)
1. Bookmark Stop `2190` or `5130`.
2. Exit the app and kill it from the app switcher (cold start test).
3. Add the OneBusAway Small or Medium Widget to the iPad Home Screen.
4. Verify:
   - Stop name and lines appear in the widget.
   - Real-time arrival minutes appear.
   - Tapping the widget deep-links back into the app directly to the stop.

### Step 6: Test Live Activity (ACT-01, ACT-02)
1. From Stop Page or Trip Page, tap 'Track' (Start Live Activity).
2. Verify toast confirmation appears.
3. Lock the iPad:
   - Verify Live Activity card appears on the Lock Screen.
   - Background tracking session remains active and refreshes without battery drain.
4. End trip / dismiss activity: verify background location stops cleanly.
