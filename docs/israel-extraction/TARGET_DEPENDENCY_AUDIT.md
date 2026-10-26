# Target Dependency Audit — IsraelMOT, OBAKit & OBAWidget

**Status:**
- **BUILD:** PENDING VERIFICATION ON CI (macOS-15 runner)
- **TESTS:** PENDING VERIFICATION ON CI
- **SIGNED_IPA:** PENDING TESTFLIGHT UPLOAD
- **APPLE_UPLOAD:** PENDING TESTFLIGHT UPLOAD
- **IPAD:** NOT VERIFIED ON DEVICE (Hardware not connected in agent environment)

---

## 1. Root Cause Analysis of Build Failure (Run 40416621526)

In GitHub Actions run `40416621526` (`Verify selected source branch with applicable Apple build/tests`), `xcodebuild` failed with exit code 65:
```
SwiftEmitModule normal arm64 Emitting module for OBAWidget (in target 'OBAWidget' from project 'OBAKit')
IsraelMOT/Map/IsraelViewportRouteRepository.swift:54:21: error: cannot find type 'ShapeCache' in scope
IsraelMOT/Map/IsraelViewportRouteRepository.swift:93:21: error: cannot find type 'ShapeCache' in scope
```

### Architectural Defect Identified:
1. `OBAWidget/project.yml` indiscriminately included `../IsraelMOT` as a source group, with only coarse-grained exclusions (`Tests`, `Scripts`, `Docs`, `Resources`).
2. Consequently, `OBAWidget` attempted to compile:
   - `IsraelMOT/Map/IsraelViewportRouteRepository.swift` (which references `ShapeCache` at lines 54 and 93, `MapKit`, and `SwiftUI`).
   - `IsraelMOT/Map/IsraelViewportSnapshot.swift` (which defines `AmbientLiveVehicle`).
   - `IsraelMOT/Routes/IsraelRouteVehicleFeed.swift` and `IsraelSelectedRouteSession.swift`.
   - `IsraelMOT/OTPAdapter/*` and `IsraelMOT/Core/Mappers/MOTSectionModeMapper.swift` (which import `OTPKit`).
   - `IsraelMOT/UI/*` and `IsraelMOT/Weather/*`.
3. `ShapeCache` is an `actor` defined in `OBAKit/Mapping/Layers/StopRouteFocus/ShapeCache.swift` as an `internal` member of `OBAKit`. It is not present in `OBAWidget`, nor should an extension target compile application-level viewport mapping logic.
4. Furthermore, multiple `OBAKit` files contained `import IsraelMOT` and `import OBAKitCoreiOS`, despite neither being standalone framework targets in XcodeGen (`IsraelMOT` files are compiled directly into `OBAKit`, and `OBAKitCoreiOS` is a group compiled into `OBAKitCore`).

---

## 2. Re-architected Target Membership Matrix

| File Path | Previous Location & Target | New Location & Target | Imports | Extension Safe? | Rationale |
|---|---|---|---|---|---|
| `IsraelViewportRouteRepository.swift` | `IsraelMOT/Map/` (OBAKit + OBAWidget) | `OBAKit/Israel/Map/` (**OBAKit only**) | `Foundation, CoreLocation, MapKit, Combine, SwiftUI, OBAKitCore` | No (MapKit/App) | Relocated to `OBAKit` where `ShapeCache` resides. Excluded from `OBAWidget`. |
| `IsraelViewportSnapshot.swift` | `IsraelMOT/Map/` (OBAKit + OBAWidget) | `OBAKit/Israel/Map/` (**OBAKit only**) | `Foundation, CoreLocation, MapKit, SwiftUI, OBAKitCore` | No (App Viewport) | Relocated to `OBAKit`. Defines `AmbientLiveVehicle`. Excluded from `OBAWidget`. |
| `IsraelRouteVehicleFeed.swift` | `IsraelMOT/Routes/` (OBAKit + OBAWidget) | `OBAKit/Israel/Routes/` (**OBAKit only**) | `Foundation, CoreLocation, SwiftUI, OBAKitCore` | No (App Feed) | Relocated to `OBAKit`. Manages app route vehicles. Excluded from `OBAWidget`. |
| `IsraelSelectedRouteSession.swift` | `IsraelMOT/Routes/` (OBAKit + OBAWidget) | `OBAKit/Israel/Routes/` (**OBAKit only**) | `Foundation, Combine, CoreLocation, OBAKitCore` | No (App Session) | Relocated to `OBAKit`. Observable session for active route. Excluded from `OBAWidget`. |
| `MOTSectionModeMapper.swift` | `IsraelMOT/Core/Mappers/` (OBAKit + OBAWidget) | `IsraelMOT/OTPAdapter/` (**OBAKit only**) | `Foundation, OTPKit` | No (Uses OTPKit) | Moved to `OTPAdapter/`. Excluded from `OBAWidget`. |
| `IsraelRouteStopTimelineModel.swift` | `IsraelMOT/Routes/` | `IsraelMOT/Routes/` (**OBAKit only**) | `Foundation, CoreLocation, OBAKitCore` | Yes | Excluded from `OBAWidget` via `Routes` exclusion. Compiled in `OBAKit`. |
| `IsraelWidgetArrivalsClient.swift` | `IsraelMOT/SharedWidget/` | `IsraelMOT/SharedWidget/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation, OBAKitCore` | **Yes** | Dedicated extension-safe arrivals client for Region 972 widget. |
| `MOTCompatibilityDataLoader.swift` | `IsraelMOT/OBAAdapter/` | `IsraelMOT/OBAAdapter/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation, OBAKitCore` | **Yes** | URLDataLoader interceptor synthesizing OBA REST responses from MOT APIs. |
| `MOTRegionFactory.swift` | `IsraelMOT/OBAAdapter/` | `IsraelMOT/OBAAdapter/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation, OBAKitCore` | **Yes** | Pinned region 972 metadata factory. |
| `OBACompatibilityBridge.swift` | `IsraelMOT/OBAAdapter/` | `IsraelMOT/OBAAdapter/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation` | **Yes** | Domain model conversion bridge. |
| `IsraelProviderBootstrap.swift` | `IsraelMOT/Bootstrap/` | `IsraelMOT/Bootstrap/` (**OBAKit + OBAWidget**) | `Foundation, OBAKitCore` | **Yes** | Provider bootstrap & region detection. |
| `IsraelRegionMigration.swift` | `IsraelMOT/Bootstrap/` | `IsraelMOT/Bootstrap/` (**OBAKit + OBAWidget**) | `Foundation, OBAKitCore` | **Yes** | Migration helper. |
| `Identifiers.swift` | `IsraelMOT/Contracts/` | `IsraelMOT/Contracts/` (**OBAKit + OBAWidget**) | `Foundation` | **Yes** | Pure value types and strongly typed IDs. |
| `TransitDomainModels.swift` | `IsraelMOT/Contracts/` | `IsraelMOT/Contracts/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation` | **Yes** | Core domain models. |
| `TransitProvider.swift` | `IsraelMOT/Contracts/` | `IsraelMOT/Contracts/` (**OBAKit + OBAWidget**) | `Foundation, Combine` | **Yes** | Provider registry & capabilities. |
| `Core/DTO/**` | `IsraelMOT/Core/DTO/` | `IsraelMOT/Core/DTO/` (**OBAKit + OBAWidget**) | `Foundation` | **Yes** | Codable network transfer objects. |
| `Core/Geometry/**` | `IsraelMOT/Core/Geometry/` | `IsraelMOT/Core/Geometry/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation` | **Yes** | Flexible polyline decoding & Google polyline encoding. |
| `Core/HTTP/**` | `IsraelMOT/Core/HTTP/` | `IsraelMOT/Core/HTTP/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation` | **Yes** | Networking client, backoff, endpoints, request policy. |
| `Core/Mappers/Arrivals/**` | `IsraelMOT/Core/Mappers/` | `IsraelMOT/Core/Mappers/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation` | **Yes** | Arrival/departure mapping. |
| `Core/Mappers/Routes/**` | `IsraelMOT/Core/Mappers/` | `IsraelMOT/Core/Mappers/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation` | **Yes** | Route mapping. |
| `Core/Mappers/Stops/**` | `IsraelMOT/Core/Mappers/` | `IsraelMOT/Core/Mappers/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation` | **Yes** | Stop mapping. |
| `Core/Storage/**` | `IsraelMOT/Core/Storage/` | `IsraelMOT/Core/Storage/` (**OBAKit + OBAWidget**) | `Foundation, CoreLocation, SQLite3` | **Yes** | Local SQLite stop catalog repo & cache. |
| `Core/Styling/MOTAgencyColorResolver.swift` | `IsraelMOT/Core/Styling/` | `IsraelMOT/Core/Styling/` (**OBAKit + OBAWidget**) | `Foundation, UIKit, OBAKitCore` | **Yes** | Pure color hex resolver with extension-safe `UIColor(hex:)`. |
| `Presentation/IsraelRouteDirectionFormatter.swift` | `IsraelMOT/Presentation/` | `IsraelMOT/Presentation/` (**OBAKit + OBAWidget**) | `Foundation` | **Yes** | Headsign & destination string parsing. |
| `OTPAdapter/**` | `IsraelMOT/OTPAdapter/` | `IsraelMOT/OTPAdapter/` (**OBAKit only**) | `Foundation, CoreLocation, OTPKit` | No (Uses OTPKit) | Excluded from `OBAWidget`. |
| `UI/**` | `IsraelMOT/UI/` | `IsraelMOT/UI/` (**OBAKit only**) | `SwiftUI` | No (App UI) | Excluded from `OBAWidget`. |
| `Weather/**` | `IsraelMOT/Weather/` | `IsraelMOT/Weather/` (**OBAKit only**) | `Foundation` | Yes | Excluded from `OBAWidget`. |
| `Search/**` | `IsraelMOT/Search/` | `IsraelMOT/Search/` (**OBAKit only**) | `Foundation, CoreLocation, OBAKitCore` | Yes | Excluded from `OBAWidget`. |

---

## 3. Strict Exclusions Configured in `OBAWidget/project.yml`

```yaml
targets:
  OBAWidget:
    type: app-extension
    platform: iOS
    sources:
      - path: "."
      - path: ../IsraelMOT
        type: group
        excludes:
          - "Tests"
          - "Scripts"
          - "Docs"
          - "Resources"
          - "Map"
          - "Routes"
          - "OTPAdapter"
          - "UI"
          - "Weather"
          - "Search"
    dependencies:
      - target: OBAKitCore
      - sdk: SwiftUI.framework
      - sdk: WidgetKit.framework
    settings:
      base:
        APPLICATION_EXTENSION_API_ONLY: true
```

---

## 4. Phantom Module Imports Removed

All invalid imports of non-existent modules were eradicated:
1. `import IsraelMOT` removed from all 12 `OBAKit` files (`IsraelAppServices`, `IsraelActivityLifecycleService`, `IsraelRouteStopsTimelineView`, `IsraelRouteDirectionTitleView`, `IsraelNearbyRoutesMapLayer`, `RouteStopsSheetView`, `SearchSheetViewModel`, `DepartureRowView`, `GroupedListView`, `RouteDirectionLabelResolver`, `TripCardView`, `RoutePickerViewModel`).
2. `import OBAKitCoreiOS` removed from `IsraelActivityLifecycleService.swift` and `IsraelActivityDiagnostics.swift` (`OBAKitCoreiOS` is a group within `OBAKitCore`, not a module).
