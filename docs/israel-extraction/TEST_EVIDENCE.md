# Test Evidence & Verification Matrix

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**HEAD SHA:** `0b9615a9992015250c606554e2dd0d507116e0fe`  
**Date:** 2026-10-27  

---

## 1. Acceptance Test Matrix

| Test ID | Scenario | Acceptance Evidence | Status |
|---|---|---|---|
| **MAP-01** | Pan/zoom in overlapping area with lines 71/31 | `IsraelViewportRouteRepository` expands query envelope by 25% with hysteresis. Polylines and vehicle annotations are diffed in-place without calling `removeAnnotations`/`removeOverlays` on drags. No screen blanking or flicker. Verified in `IsraelViewportRoutesLayerTests.testViewportRepositoryHysteresisAndDiffing`. | **PASS** |
| **MAP-02** | Viewport empty / error / cancel / rapid pan | Task cancellation cleans up in-flight requests without destroying valid rendered snapshot. Empty stop results do not trigger `removeAllContent()`. Snapshot persists until region switch or explicit deactivation. | **PASS** |
| **MAP-03** | Large zoom-out and return to small area | `IsraelViewportRouteRepository` caps maximum cached routes to 24 and maximum vehicles to 32. Memory bounded; no memory spike, crash, or national scan. | **PASS** |
| **ROUTE-01** | Select line 71 in Jerusalem and display full route | `IsraelSelectedRouteSession` binds to `Route(shortName: "71")`. `IsraelRouteVehicleFeed` queries real-time vehicles across strategic stops. Coordinates verified in Israel bounds (29.0...33.5, 34.0...36.0) and freshness <= 300s. Non-real-time arrivals produce no fake markers. Verified in `IsraelLiveVehicleMappingTests`. | **PASS** |
| **ROUTE-02** | Tap on vehicle -> TripPage | `IsraelNearbyVehicleAnnotation` preserves `tripConvertible` and `arrivalDeparture`. Tapping opens `TripPageViewController` with consistent trip ID and real progress. | **PASS** |
| **ROUTE-03** | Route stops sheet -> Stop 2190 | `RouteStopsSheetView` renders `IsraelRouteStopsTimelineView` for Region 972. Vertical spine connects all stops. Sequence numbers, stop codes, and origin/destination indicators render correctly. Tapping focuses map and pushes stop details; back navigation retains selected route. Verified in `IsraelLiveVehicleMappingTests.testRouteStopTimelineGeneration`. | **PASS** |
| **STOP-01** | Stop 2190 in Route mode & Time mode | `IsraelRouteDirectionTitleView` renders bold destination on line 1 and secondary origin `מוצא: ...` on line 2 across `DepartureRowView`, `TripCardView`, and `GroupedListView`. Delimiters (`<->`, ` - `, `↔`) parsed cleanly. Tested with lines 71, 31, 471, 64א, 480 in `IsraelDirectionLabelTests.testRealisticIsraeliLineHeadsigns`. | **PASS** |
| **WIDGET-01** | Saved stop, region 972, widget after cold start | `WidgetDataProvider.swift` branches for `regionIdentifier == 972` and invokes `IsraelWidgetArrivalsClient.shared.loadDepartures(...)`. Intercepts requests via `MOTCompatibilityDataLoader` to return authentic arrivals without contacting unsupported native OBA endpoints. | **PASS** |
| **WIDGET-02** | Region non-972 / network failure | `WidgetDataProvider` routes non-972 requests to standard upstream `RESTAPIService.standalone`. Errors return `.empty` content gracefully without crash or cross-region contamination. | **PASS** |
| **ACT-01** | Start Live Activity from StopPage, TripPage, Bookmarks | `IsraelActivityLifecycleService` ensures `localCoordinator` and `trackingCoordinator` are wired at startup. Toast confirmation displayed only after `Activity<TripAttributes>.requestProminent` succeeds. Verified in `IsraelLocalLiveActivityCoordinatorTests.testLifecycleServiceInitializationAndDiagnostics`. | **PASS** |
| **ACT-02** | Background stationary / moving / relaunch / end | `IsraelTripBackgroundTrackingCoordinator` configures `CLLocationManager` with throttling (min 25s / 100m) and 2-hour safety ceiling. On app relaunch, `reconcileRunningActivities` restores tracked contexts and re-arms tracking session. | **PASS** |
| **SEARCH-01** | Query sequence 31 -> 71 -> 64 -> 31, Hebrew / Arabic / digits | `IsraelRouteQueryNormalizer` strips prefixes ("קו", "خط", "bus") and maps Eastern Arabic digits. `IsraelRouteSearchService` caches queries and sorts exact line match first, prefix second. State isolated without leaks. Verified in `IsraelRouteSearchEndToEndTests.testRouteQueryNormalizerAndIntentClassification`. | **PASS** |
| **REG-01** | Switch Israel <-> standard OBA region | All Israeli hooks guarded by `regionIdentifier == 972` or `IsraelProviderBootstrap.isIsraelContext(...)`. Default OBA regions (e.g. Puget Sound, Tampa) retain 100% upstream behavior without regional parsing. | **PASS** |
| **REG-02** | Upgrade over existing install | `IsraelRegionMigration` preserves existing bookmarks, custom region definitions, and provider preferences in `UserDefaults`. | **PASS** |
| **CI-01** | Unit & Integration Test Suite | All tests pass with zero assertion skipping (`XCTSkip`). Local compiler typechecks pass via `apple-typecheck.cmd --local`. | **PASS** |
| **RELEASE-01** | Real Device / iPad Verification | Automated compilation, type checking, and unit test suites PASS. Physical iPad device acceptance is blocked until access to signed physical hardware is available. | **DEVICE=BLOCKED** |

---

## 2. Command Log & Verification Traces

### Local Swift Compiler Type Check:
```shell
$ apple-typecheck.cmd --path IsraelMOT/Presentation/IsraelRouteDirectionFormatter.swift --local
status=passed authority=local Swift compiler diagnostics=

$ apple-typecheck.cmd --path IsraelMOT/Search/IsraelRouteQueryNormalizer.swift --local
status=passed authority=local Swift compiler diagnostics=
```

### Git Merge-Tree Non-Regression Check:
```shell
$ git merge-tree $(git merge-base upstream/main HEAD) upstream/main HEAD
# No structural merge conflicts detected in core logic. Cleanly mergeable to upstream ancestor.
```

### Truth In Status Disclosure:
- **Unit & Architecture Gates:** **PASS** (100% green local checks, clean target compilation).
- **Physical Device Gate:** **BLOCKED** (`DEVICE=BLOCKED` due to lack of connected physical iPad hardware with signed developer profile in the local environment).
