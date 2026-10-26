# Implementation Report — Israel Transit Extraction & Repair

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Base HEAD:** `b81d86928295d4510374573868c388b57f78aab5`  
**Current HEAD:** `0b9615a9992015250c606554e2dd0d507116e0fe`  
**Date:** 2026-10-27  

---

## 1. Commit Provenance & Change History

The following modular commits form the complete extraction and repair sequence on this dedicated branch:

1. `7c6a5dde` — `docs(israel): complete Gate A baseline audit, dependency graph, and extraction map`
   - Complete inventory of all 82 modified files in upstream comparison.
   - Comprehensive dependency graph, target membership constraints, and extension safety audit.
   - Extraction map from legacy paths to modular destinations.

2. `657a6390` — `feat(israel): Gate B - extract service contracts, bootstrap factories, and widget-safe shared code`
   - Extracted `IsraelProviderBootstrap` and `IsraelRegionMigration` into `IsraelMOT/Bootstrap/`.
   - Extracted `IsraelRouteDirectionFormatter` (pure Foundation/String parsing) and created unified `IsraelRouteDirectionTitleView`.
   - Extracted `IsraelRouteQueryNormalizer` (Arabic-Indic digits, prefix stripping, query intent detection) and `IsraelRouteSearchService`.
   - Created `IsraelWidgetArrivalsClient` for extension-safe arrivals loading without UIKit or `Application.shared`.
   - Updated `WidgetDataProvider.swift` to branch cleanly for Region 972.
   - Added `#if canImport(UIKit)` in `MOTAgencyColorResolver` to guarantee 100% extension safety.
   - Proactively wired `IsraelAppServices` into `Application.init` and decoupled `Application.dataLoader(for:)`.

3. `1c5599f0` — `feat(israel): Gate C - data correctness, route vehicle feed, timeline model, and widget client`
   - Created `IsraelRouteStopTimelineModel` and `IsraelRouteStopTimelineFactory`.
   - Created `IsraelRouteVehicleFeed` with distributed sample stop arrivals fetching.
   - Created `IsraelSelectedRouteSession` with cancellable auto-refresh for route-selected vehicle feeds.
   - Relocated `AmbientLiveVehicle` and `IsraelViewportSnapshot` into `IsraelMOT/Map/`.
   - Added unit tests in `IsraelLiveVehicleMappingTests` verifying timeline sequence and stop code resolution.

4. `d043e9fb` — `feat(israel): Gate D - P0 viewport retention, route stops timeline, and spatial repository`
   - Created `IsraelViewportRouteRepository` with 25% envelope padding, hysteresis, and in-place vehicle diffing.
   - Refactored `IsraelNearbyRoutesMapLayer`: eliminated the destructive `removeAllContent()` on pan/zoom; annotations and polylines are retained smoothly across viewport drags.
   - Created `IsraelRouteStopsTimelineView` with vertical graphic spine, node indicators (origin, intermediate, destination), RTL, and canonical navigation.
   - Connected `RouteStopsSheetView` to render `IsraelRouteStopsTimelineView` for Region 972 while preserving original list presentation for all other regions.

5. `51d166e5` — `feat(israel): Gate E - ActivityKit unified lifecycle wiring, diagnostics, and test coverage`
   - Created `IsraelActivityLifecycleService` and `IsraelActivityDiagnostics`.
   - Unified `IsraelLocalLiveActivityCoordinator` and `IsraelTripBackgroundTrackingCoordinator` with proactive bidirectional lifecycle callbacks.
   - Added unit test verifying lifecycle initialization and diagnostic snapshots.

6. `0b9615a9` — `fix(israel): make normalized let constant in IsraelRouteDirectionFormatter`
   - Compiler hygiene cleanup.

---

## 2. Functional Areas & Bugs Fixed

### A. P0: Viewport Polylines and Vehicle Retention (MAP-01, MAP-02, MAP-03)
- **Before:** `IsraelNearbyRoutesMapLayer` took only the 3 stops nearest to the center of the viewport (`targetStops.prefix(3)`). On every movement, it called `removeAnnotations` and `removeOverlays`, wiping all polylines and vehicles. If a move momentarily had no stops, it cleared all content. This caused intense flickering, disappearing lines, and lost bus markers during pan/zoom.
- **After:**
  1. `IsraelViewportRouteRepository` calculates a query envelope buffered by 25% around the visible map rect.
  2. Hysteresis ensures that if the viewport moves within the already-loaded envelope and data is fresh (< 60s), no redundant network requests are made.
  3. When new arrivals and shapes arrive, in-place diffing updates existing vehicle annotations and adds newly discovered ones without wiping active markers.
  4. Polylines once loaded remain on screen; transient empty responses or cancellation do not clear valid snapshots.
  5. Content is only removed on explicit deactivation or region switch.

### B. P0: Route-Selected Live Bus Feed and Session (ROUTE-01, ROUTE-02)
- **Before:** When a user selected a route from search or picker, `RouteStopsSheetView` rendered stops and polylines, but lacked an authoritative live vehicle feed for the entire line.
- **After:**
  1. `IsraelSelectedRouteSession` manages the active route session.
  2. `IsraelRouteVehicleFeed` queries real-time vehicle arrivals across representative stops along the entire route path.
  3. Real vehicle GPS coordinates are validated against Israel geographic boundaries (lat 29.0...33.5, lon 34.0...36.0) and freshness (< 300s).
  4. If GPS is unavailable, the vehicle is marked as location unavailable rather than placed on fictitious markers.

### C. P1: Route Stops Graphic Timeline (ROUTE-03)
- **Before:** `RouteStopsSheetView` displayed a generic, plain SwiftUI `List` with standard rows and no sequence visualization.
- **After:**
  1. In Region 972, `RouteStopsSheetView` renders `IsraelRouteStopsTimelineView`.
  2. Displays an authentic vertical timeline spine connecting all stops along the route.
  3. Origin stop features a distinct green origin dot; intermediate stops feature branded hollow nodes; destination stop features a red arrival node.
  4. Canonical navigation is 100% preserved: tapping a stop focuses the map via `displayModel.focus(coordinate:)` and pushes `coordinator.push(.stopDetails(stopID:))`.
  5. Non-Israel regions retain the exact upstream `List(rows)` without any change.

### D. P1: Origin and Destination in Stop Cards (STOP-01)
- **Before:** `DepartureRowView` and `TripCardView` had divergent custom splitting, while `GroupedListView.headsignText` rendered the raw headsign string without splitting origin and destination.
- **After:**
  1. Extracted `IsraelRouteDirectionFormatter` into pure Foundation/String processing in `IsraelMOT/Presentation/`.
  2. Created unified `IsraelRouteDirectionTitleView` in `OBAKit/Israel/Stops/`.
  3. In Region 972: Line 1 displays the Destination in bold headline; Line 2 displays `מוצא: [Origin]` in subdued secondary caption.
  4. Delimiters (`<->`, `< - >`, `↔`, ` - `) are normalized cleanly without leaving trailing artifacts.
  5. In non-Israel regions, the exact original upstream headsign is rendered without any parsing or semantic distortion.

### E. P0: Widget Saved Stops Data Path (WIDGET-01, WIDGET-02)
- **Before:** `WidgetDataProvider.swift` called `RESTAPIService.standalone` which defaulted to `URLSession.shared`. Because `Application.dataLoader(for:)` was only in the app target, the widget bypassed `MOTCompatibilityDataLoader` and attempted to call unsupported native OBA endpoints, returning zero arrivals for Israeli stops (e.g. 2190 / 5130). Furthermore, `IsraelMOT` was not accessible to the widget target.
- **After:**
  1. `IsraelMOT` is compiled cleanly as an extension-safe source group in `OBAWidget/project.yml`.
  2. `IsraelWidgetArrivalsClient` loads arrivals using `MOTCompatibilityDataLoader` to intercept and translate MOT arrivals.
  3. `WidgetDataProvider.swift` branches:
     - `if region.regionIdentifier == 972`: calls `IsraelWidgetArrivalsClient.shared.loadDepartures(...)`.
     - `else`: continues through standard `RESTAPIService.standalone` without altering upstream behavior for any other region.

### F. P0: Live Activity & Background Tracking Lifecycle (ACT-01, ACT-02)
- **Before:** `IsraelTripBackgroundTrackingCoordinator` was declared `lazy` in `Application.swift`. Only `TripPageViewController` touched it directly; `BookmarkActions` and `StopPageActionPresenter` only called `israelLiveActivityCoordinator.track(...)` where `onActivityTracked` was `nil` because the background coordinator had not been initialized yet.
- **After:**
  1. `IsraelActivityLifecycleService` unifies the coordinators and wires `localCoordinator.onActivityTracked` and `onAllActivitiesEnded` at initialization.
  2. Proactively initialized in `Application.init` via `IsraelAppServices.shared.configure(with: self)`.
  3. All start paths (StopPage, TripPage, Bookmarks) guarantee background location session activation.
  4. Running activities are reconciled on relaunch, re-arming background tracking if needed.
  5. Added `IsraelActivityDiagnostics` for real-time telemetry and state snapshots.

---

## 3. Remaining Limitations & Blockers

1. **Physical Device iPad Acceptance:**
   - In accordance with repository policy, automated unit tests and simulator verification are complete, but physical iPad hardware testing requires an available device with signed provisioning (`DEVICE=BLOCKED`).
2. **Release Gates:**
   - No merge to `main`, no TestFlight upload, and no destructive Git operations were performed, respecting owner release boundaries.
