# Upstream Touchpoints Audit & Rationale

This document lists every file in the upstream OneBusAway repository that has been modified, explaining the exact rationale, safety considerations, and proof of non-regression.

---

## 1. Summary of Modifications

| File | Change Scope | Rationale | Impact on Other Regions |
| :--- | :--- | :--- | :--- |
| `Apps/OneBusAway/Resources/regions.json` | Added 1 region entry | Registers Region 972 (Israel) with geographic bounding box | **Zero**: Other region definitions untouched |
| `OBAWidget/Resources/regions.json` | Added 1 region entry | Registers Region 972 in the widget bundle | **Zero**: Widget logic unchanged |
| `Apps/Shared/app_shared.yml` | Added `he` localization & OTPKit fork URL | Enables Hebrew bundle generation & links Hebrew-localized OTPKit | **Zero**: Adds Hebrew without altering existing English/Spanish |
| `OBAKit/project.yml` | Added source reference | Compiles `IsraelMOT` source group into `OBAKit` target | **Zero**: Existing sources untouched |
| `OBAKitTests/project.yml` | Added test source reference | Compiles `IsraelMOT/Tests` into `OBAKitTests` | **Zero**: Existing tests run normally |
| `OBAKitCore/Orchestration/CoreApplication.swift` | Added `dataLoader(for:)` open method | Provides a customizable extension hook for region-specific data loaders | **Zero**: Default implementation returns `config.dataLoader` |
| `OBAKit/Orchestration/Application.swift` | Overrode `dataLoader(for:)` | Returns `MOTCompatibilityDataLoader` if `region.regionIdentifier == 972` | **Zero**: Returns `super.dataLoader(for: region)` for all other regions |
| `OBAKit/Sheet/Content/TripPlanner/TripPlannerSheetView.swift` | Injected service branch | Injects `MOTTripPlanningAPIService` if region is 972 | **Zero**: Uses standard OTP API service for all other regions |
| `OBAKit/Mapping/MapViewController+TripPlanner.swift` | Injected service branch | Injects `MOTTripPlanningAPIService` if region is 972 | **Zero**: Uses standard OTP API service for all other regions |

---

## 2. Detailed Seam Inspection

### 2.1 `CoreApplication.swift` Hook
```swift
// Added in CoreApplication.swift:
open func dataLoader(for region: Region) -> URLDataLoader {
    return config.dataLoader
}

// In refreshRESTAPIService:
let loader = dataLoader(for: currentRegion)
restService = RESTAPIService(dataLoader: loader, ...)
```
**Why this is safe**:
- `CoreApplication` has no compile-time dependency on `IsraelMOT` or `OTPKit`.
- For every non-Israel region, `dataLoader(for:)` returns `config.dataLoader`, preserving 100% existing network behavior.

### 2.2 `Application.swift` Override
```swift
// In Application.swift:
open override func dataLoader(for region: Region) -> URLDataLoader {
    if region.regionIdentifier == 972 {
        return MOTCompatibilityDataLoader(fallbackLoader: super.dataLoader(for: region))
    }
    return super.dataLoader(for: region)
}
```
**Why this is safe**:
- Active strictly when `regionIdentifier == 972`.
- When switching between regions, `CoreApplication.refreshRESTAPIService` re-evaluates the loader cleanly.
