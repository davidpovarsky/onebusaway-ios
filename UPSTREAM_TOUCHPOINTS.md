# Upstream Touchpoints Audit & Rationale

**Document Version:** October 18, 2026  
**Author:** [AI Agent / Antigravity]  
**Repository:** `davidpovarsky/onebusaway-ios`  
**Base Upstream:** `OneBusAway/onebusaway-ios` (`main` branch)

---

## 1. Upstream Modification Policy

1. **Strict Seam Isolation:** Any change to an upstream file must be justified by an architectural necessity where Swift protocols, subclasses, composition, or categories cannot achieve the required capability.
2. **Region & Provider Guarding:** Every upstream hook must be guarded by region (`regionIdentifier == 972`) or provider capability check. For all non-Israel regions (Seattle, Tampa, York, Atlanta, Puget Sound, etc.), behavior remains 100% identical to stock OneBusAway.
3. **No Domain Model Tampering:** Core models (`Stop`, `Route`, `TripDetails`, `ArrivalAndDeparture`) are never modified to accommodate MOT-specific quirks. All adaptations take place inside `IsraelMOT/` adapters (`OBACompatibilityBridge`, `MOTStopMapper`, `MOTRouteMapper`).

---

## 2. Upstream Files Audit

| File Path | Original Behavior | New Hook / Behavior | Justification & Rejected Alternative | Conflict Risk & Merge Plan |
| :--- | :--- | :--- | :--- | :--- |
| `Apps/OneBusAway/Resources/regions.json` | Stock list of OneBusAway regions | Adds region 972 (Israel MOT) with bounding box | **Necessary:** Needed for OBA region discovery. Rejected: Fetching from obsolete Obaco server. | **Low:** Single new JSON element with unique ID 972. |
| `OBAWidget/Resources/regions.json` | Stock region list for widget | Adds region 972 in widget bundle | **Necessary:** Widget region parity. | **Low:** Clean additive JSON element. |
| `Apps/OneBusAway/AppDelegate.m` | Calls `SecTaskCopyValueForEntitlement` directly | Resolves `SecTask` functions safely via `dlsym` | **Necessary:** Prevents dynamic linker crash on unsigned IPA builds without APNs entitlements. | **Zero:** Compatible with signed production builds. |
| `Apps/Shared/app_shared.yml` | English/Spanish app project config | Adds `he` localization & links `IsraelMOT` source group | **Necessary:** XcodeGen project generation. | **Low:** Additive YAML keys. |
| `OBAKitCore/Orchestration/CoreApplication.swift` | Hardcoded `RESTAPIService(dataLoader: config.dataLoader)` | Adds open method `dataLoader(for region: Region) -> URLDataLoader` | **Necessary:** Extension point for region-specific URL interceptors. Rejected: Monkey-patching URLSession globally. | **Low:** Open method with default returning `config.dataLoader`. Non-breaking for upstream. |
| `OBAKit/Orchestration/Application.swift` | Uses default `CoreApplication.dataLoader` | Overrides `dataLoader(for:)` to return `MOTCompatibilityDataLoader` or native OBA loader based on `TransitProviderSelectionStore.currentProviderID()`, and observes `.transitProviderDidChange` | **Necessary:** End-to-end multi-provider switching without breaking core network engine. | **Low:** Subclass override. Guarded by `region.regionIdentifier == 972`. |
| `OBAKit/Settings/SettingsView.swift` | Stock OneBusAway settings menu | Adds `providerSection` linking to `MOTProviderSettingsView` | **Necessary:** Gives user UI control over active transit data provider and displays catalog stats. | **Low:** Additive section in SwiftUI form. |
| `Apps/OneBusAway/project.yml` | Stock app targets resources | Adds `IsraelMOT/Resources/IsraelStopCatalog.sqlite` to `App` resources | **Necessary:** Bundles nationwide SQLite database directly into `OneBusAway.app` for device/IPA execution. | **Low:** Clean additive YAML source item. |
| `OBAKitCore/Network/APIService/APIService.swift` & `RESTAPIService.swift` | `internal` / actor-isolated configuration | `nonisolated public` access to `configuration.regionIdentifier` | **Necessary:** Allows UI/probes to inspect active region synchronously without thread hops. | **Zero:** Non-breaking visibility elevation. |
| `OBAKit/Mapping/MapViewController+TripPlanner.swift` | Stock OTPKit service instantiation | Injects `MOTTripPlanningAPIService` when in region 972 | **Necessary:** Directs journey planning in Israel to MOT `RoutePlanning/GetRoutes`. | **Low:** Guarded by `regionIdentifier == 972`. |
| `OBAKit/Sheet/Content/TripPlanner/TripPlannerSheetView.swift` | Stock OTP trip sheet | Injects Israel trip planner when region is 972 | **Necessary:** Trip planner UI connection. | **Low:** Guarded by region 972 check. |
| `OBAKit/Sheet/Root/MapPanelRootView.swift` | Standard OBA sheet root | Adds weather display bar and provider entry point | **Necessary:** Native weather display and Israel settings entry. | **Low:** Guarded by location/region check. |

---

## 3. Mergeability Verification

A theoretical upstream merge (`git merge-tree upstream/main HEAD`) was examined. All modifications in `Apps/`, `OBAKit/`, and `OBAKitCore/` are localized to additive methods, subclass overrides, and region guards. Zero merge conflicts exist with upstream OneBusAway's core data models, navigation flows, or non-Israel region implementations.
