# Implementation Report — Israel Transit Extraction & Repair

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Base HEAD:** `b81d86928295d4510374573868c388b57f78aab5`  
**Date:** 2026-10-27  

---

## 1. Commit Provenance & Change History

1. `7c6a5dde` — `docs(israel): complete Gate A baseline audit, dependency graph, and extraction map`
2. `657a6390` — `feat(israel): Gate B - extract service contracts, bootstrap factories, and widget-safe shared code`
3. `1c5599f0` — `feat(israel): Gate C - data correctness, route vehicle feed, timeline model, and widget client`
4. `d043e9fb` — `feat(israel): Gate D - P0 viewport retention, route stops timeline, and spatial repository`
5. `51d166e5` — `feat(israel): Gate E - ActivityKit unified lifecycle wiring, diagnostics, and test coverage`
6. `0b9615a9` — `fix(israel): make normalized let constant in IsraelRouteDirectionFormatter`
7. `b553da31` — `docs(israel): complete Gate F implementation report, test evidence, upstream nonregression, and release readiness`
8. **[NEW COMMIT]** — `fix(israel): resolve target boundaries, move app presentation out of widget, and eradicate phantom imports`
   - Relocated `IsraelViewportRouteRepository.swift` and `IsraelViewportSnapshot.swift` from `IsraelMOT/Map/` to `OBAKit/Israel/Map/`.
   - Relocated `IsraelRouteVehicleFeed.swift` and `IsraelSelectedRouteSession.swift` from `IsraelMOT/Routes/` to `OBAKit/Israel/Routes/`.
   - Relocated `MOTSectionModeMapper.swift` from `IsraelMOT/Core/Mappers/` to `IsraelMOT/OTPAdapter/`.
   - Removed obsolete/empty `IsraelMOT/Map/`.
   - Configured strict whitelist/exclusions in `OBAWidget/project.yml` (`Map`, `Routes`, `OTPAdapter`, `UI`, `Weather`, `Search`, `Tests`, `Scripts`, `Docs`, `Resources`) and enforced `APPLICATION_EXTENSION_API_ONLY: true`.
   - Eradicated all `import IsraelMOT` from all 12 `OBAKit` files.
   - Eradicated all `import OBAKitCoreiOS` from `OBAKit` files.
   - Added automated target boundary regression test suite `IsraelTargetMembershipTests` in `IsraelMOT/Tests/Integration/IsraelTargetMembershipTests.swift`.
   - Added `IsraelTargetMembershipTests` to `.github/workflows/israel-ios-ci.yml`.

---

## 2. Target Boundary and Module Architecture

### A. The Core Architectural Problem
In commit `b553da31`, `OBAWidget/project.yml` included `../IsraelMOT` as a source group without excluding map or vehicle presentation files. `IsraelViewportRouteRepository.swift` references `ShapeCache` (lines 54 and 93). `ShapeCache` is an `actor` defined in `OBAKit/Mapping/Layers/StopRouteFocus/ShapeCache.swift` as `internal` to `OBAKit`. It does not and cannot exist in `OBAWidget`.

Additionally:
- `IsraelMOT` was treated as a module via `import IsraelMOT` in several `OBAKit` files, but in XcodeGen it is compiled as source files directly into `OBAKit`.
- `OBAKitCoreiOS` was imported via `import OBAKitCoreiOS`, but it is simply a folder group compiled into `OBAKitCore`.

### B. The Applied Solution
1. **App Presentation Layer (`OBAKit/Israel/`):**
   - Files dependent on MapKit, SwiftUI presentation, `ShapeCache`, or Application lifecycle are placed in `OBAKit/Israel/Map/` and `OBAKit/Israel/Routes/`.
   - Because `OBAKit/project.yml` includes `.` as a synced folder, these files are compiled exclusively in `OBAKit`, where `ShapeCache` is internal and directly accessible.
2. **Widget-Safe Shared Data Layer (`IsraelMOT/`):**
   - Pure Foundation, CoreLocation, SQLite, and network compatibility models remain in `IsraelMOT/Bootstrap/`, `Contracts/`, `Core/`, `OBAAdapter/`, `Presentation/`, and `SharedWidget/`.
   - `OBAWidget/project.yml` explicitly excludes `Map`, `Routes`, `OTPAdapter`, `UI`, `Weather`, `Search`, `Tests`, `Scripts`, `Docs`, and `Resources`.
   - `APPLICATION_EXTENSION_API_ONLY: true` is strictly enforced.
3. **OTP Kit Isolation:**
   - `MOTSectionModeMapper.swift` (which uses `OTPKit`) was moved into `IsraelMOT/OTPAdapter/`, preventing `OBAWidget` from attempting to link `OTPKit`.

---

## 3. Preserved Upstream Invariants
- Upstream region handling remains untouched: regions outside 972 bypass MOT compatibility entirely.
- Original `OBAWidget` bookmarks timeline provider and `RESTAPIService.standalone` for non-972 regions remain unmodified.
- No dummy stubs, no skipped tests, no mock data in release paths.
