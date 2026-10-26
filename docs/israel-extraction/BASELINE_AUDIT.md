# Baseline Audit — Modified Upstream Files Inventory

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Base:** `b81d86928295d4510374573868c388b57f78aab5` (compared against `main` @ `1e6d5e44300ff2efc95edaed23053ca158a789f7` and common ancestor `eeeae021d813fa6d3e1748cabf7b73d3079edaa3`)  
**Total Modified Files:** 82  
**Total Added Files:** 173  

---

## 1. Executive Summary of Audit

This audit reviews every single one of the 82 upstream files modified in the Israel transit repair branches.
Each file is classified according to the mandatory extraction policy:
- **EXTRACT**: Israeli logic currently residing inside upstream files must be extracted into standalone components under `IsraelMOT/` or `OBAKit/Israel/`.
- **HOOK**: Clean, guarded injection or seam point retained in upstream (e.g. `region.regionIdentifier == 972` or capability probe).
- **KEEP**: Generic upstream improvements (bug fixes, accessibility enhancements, cross-region compatibility) that benefit all regions and preserve upstream semantics.
- **REVERT**: Unnecessary changes or regressions that can be returned to clean upstream.
- **REVIEW**: Code requiring verification against tests before finalizing decision.

---

## 2. Complete Inventory of All 82 Modified Files

| # | File Path | Lines +/- | Category | Classification | Rationale & Action Plan |
|---|---|---|---|---|---|
| 1 | `Apps/OneBusAway/AppDelegate.m` | +50 / -2 | Push / APNs Safeguard | **KEEP** | Safeguards against APNs crash on unsigned simulator / local builds. Useful for all developers running without Apple Developer signing. |
| 2 | `Apps/OneBusAway/Package.resolved` | +3 / -3 | Build / Dependency | **KEEP** | Pin synchronization for SPM dependencies. |
| 3 | `Apps/OneBusAway/Resources/regions.json` | +463 / -1 | Config / Region Catalog | **KEEP** | Official bundled definition of Region 972 (Israel MOT), including bounds and agencies. Required for app offline bootstrap. |
| 4 | `Apps/OneBusAway/project.yml` | +4 / -0 | Build / XcodeGen | **HOOK** | Includes `IsraelStopCatalog.sqlite` resource and widget bundle configuration. Keep minimal. |
| 5 | `Apps/Shared/CommonClient/SceneDelegate.m` | +7 / -0 | Lifecycle | **KEEP** | Generic logging & scene lifecycle instrumentation. |
| 6 | `Apps/Shared/analytics_fx_config.yml` | +6 / -0 | Config / Analytics | **KEEP** | Build configuration for analytics flags. |
| 7 | `Apps/Shared/app_shared.yml` | +5 / -5 | Build / XcodeGen | **KEEP** | Shared target settings and compiler definitions. |
| 8 | `Apps/Shared/push_config.yml` | +1 / -0 | Config / Push | **KEEP** | Entitlement configuration for push notifications. |
| 9 | `OBAKit/Bookmarks/BookmarkActions.swift` | +20 / -9 | Live Activity Trigger | **HOOK** | Unified dispatch to `IsraelActivityLifecycleService.shared.startTracking(...)` when `regionIdentifier == 972`; retains upstream `LiveActivityTracker` for other regions. |
| 10 | `OBAKit/Bookmarks/BookmarksViewController.swift` | +12 / -1 | UI / Bookmarks | **KEEP** | Generic refresh & bookmark arrival update reliability fix. |
| 11 | `OBAKit/Controls/SwiftUI/KeepsScreenAwake.swift` | +7 / -0 | UX / Screen Idle | **KEEP** | Generic SwiftUI modifier keeping screen awake during trip navigation. |
| 12 | `OBAKit/LiveActivities/Activity+RequestProminent.swift` | +9 / -2 | Live Activity | **EXTRACT** | Move Israeli prominence/relevance logic into `OBAKit/Israel/LiveActivities/IsraelActivityLifecycleService.swift`. Retain generic helper in upstream if clean. |
| 13 | `OBAKit/LiveActivities/TrackBookmarkIntent.swift` | +2 / -2 | App Intent | **KEEP** | Target intent parameter resolution. |
| 14 | `OBAKit/Mapping/Layers/MapLayerRegistrar.swift` | +33 / -0 | Mapping / Architecture | **HOOK** | Registers Israeli ambient map layer dynamically when available. Keep clean capability check. |
| 15 | `OBAKit/Mapping/Layers/MapSheetView.swift` | +18 / -2 | Mapping / Layer UI | **HOOK** | Layer visibility toggle seam point. |
| 16 | `OBAKit/Mapping/Layers/PolylineDirectionArrows.swift` | +2 / -2 | Mapping / Geometry | **KEEP** | Generic direction chevron placement math along polylines. |
| 17 | `OBAKit/Mapping/Layers/RentalDeepLink.swift` | +1 / -1 | Micromobility | **KEEP** | URL encoding fix for rental partner deep links. |
| 18 | `OBAKit/Mapping/Layers/StopRouteFocus/StopMapFocus.swift` | +5 / -5 | Mapping / Focus | **KEEP** | Generic bounding box calculation when focusing on a stop and its routes. |
| 19 | `OBAKit/Mapping/Layers/StopRouteFocus/StopRouteFocusMapLayer.swift` | +1 / -1 | Mapping / Focus | **KEEP** | Minor parameter alignment. |
| 20 | `OBAKit/Mapping/Layers/StopRouteFocus/StopRouteFocusModel.swift` | +15 / -2 | Mapping / Focus | **KEEP** | Generic route polyline visibility during stop selection. |
| 21 | `OBAKit/Mapping/MapFloatingPanelController.swift` | +23 / -0 | UX / Layout | **KEEP** | Generic layout adjustment for floating panel safe area on iPhone/iPad. |
| 22 | `OBAKit/Mapping/MapViewController+MapLayers.swift` | +10 / -0 | Mapping / Integration | **HOOK** | Minimal hook to register and reload ambient transit layers. |
| 23 | `OBAKit/Mapping/MapViewController+OnDemandDock.swift` | +3 / -0 | Mapping / Capability | **HOOK** | Capability guard suppressing on-demand dock when unsupported by current region. |
| 24 | `OBAKit/Mapping/MapViewController+TripPlanner.swift` | +4 / -1 | Trip Planner | **HOOK** | Injects Israeli OTP planning service factory when active. |
| 25 | `OBAKit/Mapping/MapViewController.swift` | +92 / -1 | Map Lifecycle & Selection | **EXTRACT / HOOK** | Extract Israeli annotation selection & custom callouts into `OBAKit/Israel/Map/`; retain clean selection hooks in `MapViewController`. |
| 26 | `OBAKit/Mapping/NearbyStopsListViewController.swift` | +15 / -1 | Stops UI | **KEEP** | Generic list styling and stop subtitle formatting. |
| 27 | `OBAKit/Mapping/PulsingAnnotationView.swift` | +16 / -0 | MapKit Views | **KEEP** | Generic pulsing vehicle annotation view for real-time vehicles. |
| 28 | `OBAKit/OnDemand/Picker/OnDemandLocalityResolver.swift` | +7 / -3 | OnDemand | **KEEP** | Generic nil-coalescing fix for locality resolver. |
| 29 | `OBAKit/OnDemand/Probe/OnDemandProbeController.swift` | +3 / -0 | OnDemand | **HOOK** | Capability check preventing unnecessary HTTP probes in unsupported regions. |
| 30 | `OBAKit/Orchestration/Application.swift` | +35 / -0 | Application Bootstrap | **EXTRACT / HOOK** | Extract direct initialization of coordinators to `OBAKit/Israel/Bootstrap/IsraelAppServices.swift`. Retain `dataLoader(for:)` override calling `IsraelProviderBootstrap`. |
| 31 | `OBAKit/Schedules/ScheduleForRouteViewModel.swift` | +1 / -1 | Schedules | **KEEP** | Generic date formatting fix. |
| 32 | `OBAKit/Schedules/ScheduleForStopViewModel.swift` | +3 / -2 | Schedules | **KEEP** | Generic schedule departure time comparison fix. |
| 33 | `OBAKit/Search/SearchRequest.swift` | +24 / -5 | Search Routing | **EXTRACT / HOOK** | Extract Israeli national line search routing into `IsraelRouteSearchService`. Upstream retains search provider delegation. |
| 34 | `OBAKit/Search/SearchResultsController.swift` | +2 / -1 | Search UI | **KEEP** | Generic keyboard dismissal on search row selection. |
| 35 | `OBAKit/Settings/SettingsView.swift` | +17 / -0 | Settings UI | **EXTRACT / HOOK** | Extract Israel provider selection UI into `OBAKit/Israel/Settings/IsraelProviderSettingsSection.swift`; inject as a conditional section. |
| 36 | `OBAKit/Sheet/Content/Home/HomeSheetView.swift` | +1 / -0 | Sheet UI | **KEEP** | Minor sheet detent layout tweak. |
| 37 | `OBAKit/Sheet/Content/RoutePicker/RoutePickerView.swift` | +52 / -16 | Route Picker UI | **EXTRACT / HOOK** | Extract Hebrew/Arabic search field behavior and custom operator badges to `OBAKit/Israel/Search/`; retain clean search UI bindings. |
| 38 | `OBAKit/Sheet/Content/Search/SearchResultRow.swift` | +1 / -1 | Search UI | **KEEP** | Subtitle layout alignment. |
| 39 | `OBAKit/Sheet/Content/Search/SearchResultsSheetView.swift` | +3 / -0 | Search UI | **KEEP** | Generic keyboard dismissal on results appearance. |
| 40 | `OBAKit/Sheet/Content/Search/SearchSheetView.swift` | +5 / -1 | Search UI | **KEEP** | Generic search input styling. |
| 41 | `OBAKit/Sheet/Content/Search/SearchSheetViewModel.swift` | +40 / -3 | Search State | **EXTRACT / HOOK** | Extract Israeli national route search provider to `IsraelRouteSearchService`; retain upstream search pipeline. |
| 42 | `OBAKit/Sheet/Content/TripPlanner/TripPlannerSheetView.swift` | +4 / -1 | Trip Planner | **HOOK** | Minimal seam injecting regional trip planner capabilities. |
| 43 | `OBAKit/Sheet/DI/AppSheetViewFactory.swift` | +13 / -1 | DI Factory | **HOOK** | Injects `IsraelRouteStopsTimelineView` for region 972 in `routeStops` sheet; non-972 uses standard list. |
| 44 | `OBAKit/Sheet/Root/MapPanelLayersModel.swift` | +24 / -1 | SwiftUI Map Model | **EXTRACT / HOOK** | Extract direct layer state to `IsraelViewportRouteRepository`; expose clean ambient observable in upstream model. |
| 45 | `OBAKit/Sheet/Root/MapPanelRootView.swift` | +442 / -285 | SwiftUI Map Content | **EXTRACT / HOOK** | Major extraction: extract `israelNearbyRoutesContent` and associated overlays to `OBAKit/Israel/Map/IsraelMapSwiftUIOverlay.swift`. Retain minimal SwiftUI overlay hook. |
| 46 | `OBAKit/Sheet/Root/MapStopsObserver.swift` | +8 / -0 | Stops Observer | **KEEP** | Generic listener on stop updates. |
| 47 | `OBAKit/Sheet/Root/TripFocusMapOverlays.swift` | +33 / -1 | Trip Overlays | **EXTRACT / HOOK** | Extract Israel vehicle callout card to `OBAKit/Israel/Map/`; retain upstream trip focus overlays. |
| 48 | `OBAKit/Sheet/Root/WeatherDetailPopup.swift` | +8 / -0 | Weather UI | **EXTRACT / HOOK** | Extract Israeli weather provider view to `OBAKit/Israel/Weather/`; retain popup container. |
| 49 | `OBAKit/Stops/StopPage/Departures/DepartureRowView.swift` | +12 / -3 | Departures UI | **EXTRACT / HOOK** | Extract Israeli direction parsing to `IsraelRouteDirectionFormatter` & `IsraelRouteDirectionTitleView`. Use ONLY when region is 972; retain exact upstream headsign otherwise. |
| 50 | `OBAKit/Stops/StopPage/StopPageActionPresenter.swift` | +8 / -1 | Stop Actions | **HOOK** | Route live activity trigger to `IsraelActivityLifecycleService.shared.startTracking(...)` when region is 972. |
| 51 | `OBAKit/Strings/en.lproj/Localizable.strings` | +16 / -0 | Localization | **KEEP** | English strings for live activity, weather, and operator details. |
| 52 | `OBAKit/Trip/DestinationStopPickerController.swift` | +1 / -1 | Trip Picker | **KEEP** | Generic picker dismissal fix. |
| 53 | `OBAKit/Trip/RoutePickerViewController.swift` | +4 / -1 | Route Picker | **HOOK** | Injects Israeli route search service when region is 972. |
| 54 | `OBAKit/Trip/TripFloatingPanelController.swift` | +3 / -2 | UX / Panel | **KEEP** | Generic panel positioning fix. |
| 55 | `OBAKit/Trip/TripPage/TripCardView.swift` | +15 / -3 | Trip Card UI | **EXTRACT / HOOK** | Use `IsraelRouteDirectionTitleView` for region 972; retain upstream layout for other regions. |
| 56 | `OBAKit/Trip/TripPage/TripPageView.swift` | +1 / -0 | Trip UI | **KEEP** | Generic scroll padding modifier. |
| 57 | `OBAKit/Trip/TripPage/TripPageViewController.swift` | +34 / -2 | Trip Controller | **HOOK** | Replace scattered background tracking start with single call to `IsraelActivityLifecycleService.shared.startTracking(...)`. |
| 58 | `OBAKit/Trip/TripPage/TripStopListView.swift` | +6 / -0 | Stop List UI | **KEEP** | Generic rail line padding and accessibility styling. |
| 59 | `OBAKit/Trip/TripStopListItem.swift` | +9 / -4 | Stop Progress | **KEEP** | Generic progress calculation along stop sequence. |
| 60 | `OBAKit/Trip/TripViewController.swift` | +3 / -2 | Trip Controller | **KEEP** | Generic view frame layout update. |
| 61 | `OBAKit/ViewModels/MapViewModel/MapViewModel.swift` | +74 / -16 | Map View Model | **EXTRACT / HOOK** | Extract Israeli weather and viewport tracking hooks to `IsraelViewportRouteRepository` and `IsraelWeatherPresentation`. Keep clean delegate in `MapViewModel`. |
| 62 | `OBAKit/ViewModels/MapViewModel/WeatherDisplay.swift` | +72 / -0 | Weather Model | **EXTRACT** | Move to `OBAKit/Israel/Weather/IsraelWeatherDisplay.swift`. |
| 63 | `OBAKit/ViewModels/RoutePickerViewModel.swift` | +161 / -17 | Route Picker VM | **EXTRACT / HOOK** | Extract Israeli query normalization, debounce, SearchLines, operator groupings to `IsraelRouteSearchService`. Retain generic search binding. |
| 64 | `OBAKit/ViewModels/TripViewModel.swift` | +34 / -24 | Trip View Model | **KEEP** | Generic adherence calculation and stop arrival interpolation. |
| 65 | `OBAKit/ViewRouting/Router.swift` | +11 / -0 | Routing | **HOOK** | Route stop details and vehicle callouts navigation handler. |
| 66 | `OBAKit/project.yml` | +7 / -0 | Build / XcodeGen | **HOOK** | Register `IsraelMOT` source folder and `OBAKit/Israel` sources. |
| 67 | `OBAKitCore/Location/Regions/RegionsService.swift` | +59 / -13 | Regions Service | **EXTRACT / HOOK** | Extract Region 972 migration rules to `IsraelRegionMigration.swift`; retain upstream custom region resolution. |
| 68 | `OBAKitCore/Models/REST/ScheduleForRoute.swift` | +21 / -12 | REST Models | **KEEP** | Robust optional decoding for schedule stop times (fixes crashes when schedules lack explicit days). Upstream improvement. |
| 69 | `OBAKitCore/Models/REST/TripStopTime.swift` | +24 / -9 | REST Models | **KEEP** | Robust optional decoding for departure times. Upstream improvement. |
| 70 | `OBAKitCore/Network/APIService/APIService.swift` | +1 / -1 | Network | **KEEP** | Generic capability guard. |
| 71 | `OBAKitCore/Network/RESTAPIService/RESTAPIService.swift` | +5 / -1 | Network | **KEEP** | Clean header/user agent parameter forwarding. |
| 72 | `OBAKitCore/Orchestration/CoreApplication.swift` | +11 / -2 | Orchestration | **HOOK** | Defines `open func dataLoader(for region: Region) -> URLDataLoader` allowing subclass injection. Architectural hook. |
| 73 | `OBAKitCore/Surveys/Service/SurveyService.swift` | +9 / -0 | Surveys | **HOOK** | Suppresses survey checks when unsupported by region configuration. |
| 74 | `OBAKitCoreiOS/LiveActivities/TripAttributes.swift` | +9 / -2 | Live Activities | **KEEP** | Adds `regionIdentifier` and optional vehicle fields to `TripAttributes`. Safe for all regions. |
| 75 | `OBAKitCoreiOS/LiveActivities/TripLiveActivityCardView.swift` | +16 / -1 | Live Activities UI | **KEEP** | RTL and layout padding improvements for Live Activity card. |
| 76 | `OBAKitTests/Application/TimeZoneScheduleBadgeTests.swift` | +1 / -1 | Tests | **KEEP** | Time zone assertion fix. |
| 77 | `OBAKitTests/Controls/ScreenAwakeCoordinatorTests.swift` | +24 / -0 | Tests | **KEEP** | Unit tests for screen awake coordinator. |
| 78 | `OBAKitTests/Modeling/REST Model Service Tests/TripDetailsModelOperationTests.swift` | +2 / -2 | Tests | **KEEP** | Generic test assertion alignment. |
| 79 | `OBAKitTests/project.yml` | +4 / -1 | Build / XcodeGen | **HOOK** | Includes `IsraelMOT/Tests` in test target. |
| 80 | `OBAKitUITests/project.yml` | +1 / -0 | Build / XcodeGen | **HOOK** | Includes Israeli UI tests. |
| 81 | `OBAWidget/Resources/regions.json` | +864 / -1 | Config / Region Catalog | **KEEP** | Synced regions catalog for Widget extension. |
| 82 | `OBAWidget/Widgets/TripLiveActivity.swift` | +11 / -1 | Live Activities UI | **KEEP** | Live activity layout and alignment fixes. |

---

## 3. Relocation Plan for Misplaced Added Files in `OBAKit/`

The audit revealed 10 newly added files currently placed directly in `OBAKit` root or general directories. They will be relocated as follows:

| Current Path | Target Destination | Classification |
|---|---|---|
| `OBAKit/Diagnostics/IsraelMapStressProbe.swift` | `OBAKit/Israel/Diagnostics/IsraelMapStressProbe.swift` | Namespace isolation |
| `OBAKit/LiveActivities/IsraelLocalLiveActivityCoordinator.swift` | `OBAKit/Israel/LiveActivities/IsraelLocalLiveActivityCoordinator.swift` | Unified into `IsraelActivityLifecycleService` |
| `OBAKit/Location/IsraelTripBackgroundTrackingCoordinator.swift` | `OBAKit/Israel/LiveActivities/IsraelTripBackgroundTrackingCoordinator.swift` | Background location tracking service |
| `OBAKit/Mapping/Layers/IsraelNearbyRoutesMapLayer.swift` | `IsraelMOT/Map/IsraelViewportRouteRepository.swift` + `OBAKit/Israel/Map/IsraelNearbyRoutesMapLayer.swift` | Clean split: Repository vs UI layer |
| `OBAKit/Trip/RouteDirectionLabelResolver.swift` | `IsraelMOT/Presentation/IsraelRouteDirectionFormatter.swift` | Core formatting logic without UIKit |
| `OBAKit/Vehicles/AmbientVehicleDetailCard.swift` | `OBAKit/Israel/Vehicles/AmbientVehicleDetailCard.swift` | Namespace isolation |
| `OBAKit/Strings/he.lproj/AppIntents.strings` | Retain in `OBAKit/Strings/he.lproj/` | Standard bundle localization |
| `OBAKit/Strings/he.lproj/AppShortcuts.strings` | Retain in `OBAKit/Strings/he.lproj/` | Standard bundle localization |
| `OBAKit/Strings/he.lproj/Localizable.strings` | Retain in `OBAKit/Strings/he.lproj/` | Standard bundle localization |
| `OBAKit/Strings/he.lproj/Localizable.stringsdict` | Retain in `OBAKit/Strings/he.lproj/` | Standard bundle localization |
