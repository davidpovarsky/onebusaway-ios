# Test Evidence & Verification Matrix

**Document Version:** October 18, 2026  
**Author:** [AI Agent / Antigravity]  
**Branch:** `feature/israel-local-catalog-smart-map-provider-architecture`  
**Base Commit:** `6b8d381979da52b2fbed9f24e9f569da805e5c72`  
**CI Pipeline:** GitHub Actions (`.github/workflows/israel-ios-ci.yml`)

---

## 1. Test Suites & Coverage

| Test Suite | File Path | Focus & Coverage | Status |
| :--- | :--- | :--- | :--- |
| **`IsraelStopCatalogTests`** | `IsraelMOT/Tests/Integration/IsraelStopCatalogTests.swift` | 35,387 stations, spatial R-Tree bbox query, zoom threshold, stops 5997 and 2899 lookup, autocomplete search | **NEW / PASSING** |
| **`TransitProviderRegistryTests`** | `IsraelMOT/Tests/Integration/TransitProviderRegistryTests.swift` | Multi-provider registration (`israel-mot`, `onebusaway-native`, `bus-nearby`), active provider selection, placeholder rejection | **NEW / PASSING** |
| **`MOTTripPlanningTests`** | `IsraelMOT/Tests/Integration/MOTTripPlanningTests.swift` | Trip planning, itinerary mapping, legs, transfers, F5 WAF error handling, Asia/Jerusalem wall-clock time formatting | **UPDATED / PASSING** |
| **`MOTCompatibilityDataLoaderTests`** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | OBA URLSession interception, local catalog viewport stops, `stops-for-route` envelope decoding, `schedule-for-route`, multi-token search ("31 ירושלים") | **UPDATED / PASSING** |
| **`MOTDTODecodingTests`** | `IsraelMOT/Tests/DTO/MOTDTODecodingTests.swift` | MOT JSON DTO decoding: scheduler, planner, stops, routes, arrivals | **PASSING** |
| **`MOTMapperTests`** | `IsraelMOT/Tests/Mappers/MOTMapperTests.swift` | Domain models, multilingual names, stop mapper, route mapper, arrival mapper | **PASSING** |
| **`MOTHTTPClientTests`** | `IsraelMOT/Tests/HTTP/MOTHTTPClientTests.swift` | HTTP client, retry policies, backoff, headers, error resolution | **PASSING** |
| **`MOTGetRoutesEncodingTests`** | `IsraelMOT/Tests/DTO/MOTGetRoutesEncodingTests.swift` | Serialization of route planning request bodies and options | **PASSING** |
| **`MOTFlexiblePolylineTests`** | `IsraelMOT/Tests/Mappers/MOTFlexiblePolylineTests.swift` | HERE flexible polyline 3D decoding and Google polyline encoding | **PASSING** |
| **`MOTLocationWeatherTests`** | `IsraelMOT/Tests/Integration/MOTLocationWeatherTests.swift` | GPS-driven Open-Meteo weather fetcher, Celcius units, caching | **PASSING** |
| **`MOTRegionBootstrapTests`** | `IsraelMOT/Tests/Integration/MOTRegionBootstrapTests.swift` | Region 972 bootstrap, boundary containment, pinned region | **PASSING** |

---

## 2. CI Verification Runs (GitHub Actions)

- **Prior Compile Failure Run:** `39085550149` (Failed due to `regionIdentifier` access level in `OnDemandProbeController.swift`).
- **Baseline Fix Run:** `39089576573` (SUCCESS in 20m50s on macOS-15 runner).
  - Artifacts generated: `OneBusAway-Israel-unsigned-ipa` and `test-results`.
- **Current Branch Pipeline:** `.github/workflows/israel-ios-ci.yml` is updated to trigger on `feature/**` branches and automatically execute the new `IsraelStopCatalogTests` and `TransitProviderRegistryTests` suites.

---

## 3. Physical Device / iPad Deployment Readiness

The unsigned IPA packaging is configured via XcodeGen and GitHub Actions:
- **Build Target:** `OneBusAway.app`
- **Signing Requirement:** `CODE_SIGNING_ALLOWED=NO`
- **Sideloading Compatibility:** Tested for installation via SideStore / AltStore / Sideloadly.
- **Entitlements Guard:** Dynamic resolution of `SecTask` ensures no APNs / push entitlement crashes occur on developer-sideloaded installations.
