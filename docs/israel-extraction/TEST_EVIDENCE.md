# Test Evidence & Verification Matrix

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Date:** 2026-10-27  

---

## 1. Automated Status Tracking (Truth-First)

| Component | Status | Evidence / Notes |
|---|---|---|
| **Local Code & Target Boundaries** | **FIXED** | Target boundaries corrected: `IsraelViewportRouteRepository`, `IsraelViewportSnapshot`, `IsraelRouteVehicleFeed`, `IsraelSelectedRouteSession` moved to `OBAKit/Israel/`. `MOTSectionModeMapper` moved to `OTPAdapter/`. Strict exclusions in `OBAWidget/project.yml`. Zero phantom imports. |
| **macOS xcodebuild Build & Unit Tests** | **PENDING CI RUN** | Prior run `40416621526` failed on `ShapeCache` in `OBAWidget`. Next verification will run on GitHub Actions `israel-ios-ci.yml`. |
| **macOS UI Tests** | **PENDING CI RUN** | Part of `israel-ios-ci.yml` (`OBAKitUITests/IsraelTransitRepairUITests`). |
| **Unsigned IPA Archive** | **PENDING CI RUN** | Part of `israel-ios-ci.yml`. |
| **Signed TestFlight Archive & Upload** | **PENDING TESTFLIGHT WORKFLOW** | Prior run `40416553121` failed on SHA mismatch. Prior run `40416621526` failed on widget compile. Will be triggered with exact new SHA once CI is green. |
| **Physical iPad Acceptance** | **NOT VERIFIED ON DEVICE** | Physical hardware not connected in CI/agent environment. |

---

## 2. GitHub Actions CI & Release Runs

| Run ID | Workflow | Trigger / Event | Branch / SHA | Status / Conclusion | Notes |
|---|---|---|---|---|---|
| `40416553121` | `israel-testflight.yml` | workflow_dispatch | `main` / `b553da31...` (expected SHA mismatch) | **failure** | Failed at `Enforce immutable SHA` gate due to non-existent SHA input. |
| `40416621526` | `israel-testflight.yml` | workflow_dispatch | `main` / `b553da31...` | **failure** | SHA gate passed. Failed at `Verify selected source branch` with exit 65 (`Cannot find type 'ShapeCache' in scope` in `OBAWidget`). |
| **[PENDING]** | `israel-ios-ci.yml` | push / workflow_dispatch | `fix/...` / `[NEW SHA]` | **PENDING** | To be executed upon push. |
| **[PENDING]** | `israel-testflight.yml` | workflow_dispatch | `main` / `[NEW SHA]` | **PENDING** | To be executed upon CI green. |

---

## 3. Targeted Test Suites Configured

The following 23 unit test suites and 1 UI test suite are configured for execution in `.github/workflows/israel-ios-ci.yml`:
1. `OBAKitTests/MOTDTODecodingTests`
2. `OBAKitTests/MOTMapperTests`
3. `OBAKitTests/MOTHTTPClientTests`
4. `OBAKitTests/MOTCompatibilityDataLoaderTests`
5. `OBAKitTests/MOTTripPlanningTests`
6. `OBAKitTests/MOTGetRoutesEncodingTests`
7. `OBAKitTests/MOTFlexiblePolylineTests`
8. `OBAKitTests/MOTLocationWeatherTests`
9. `OBAKitTests/MOTRegionBootstrapTests`
10. `OBAKitTests/IsraelStopCatalogTests`
11. `OBAKitTests/TransitProviderRegistryTests`
12. `OBAKitTests/IsraelRouteSearchEndToEndTests`
13. `OBAKitTests/IsraelTripIdentityAndTimesTests`
14. `OBAKitTests/IsraelRouteScheduleTruthTests`
15. `OBAKitTests/IsraelLiveVehicleMappingTests`
16. `OBAKitTests/IsraelOperatorColorsTests`
17. `OBAKitTests/IsraelArrivalLoadAndCacheTests`
18. `OBAKitTests/IsraelViewportRoutesLayerTests`
19. `OBAKitTests/IsraelDirectionLabelTests`
20. `OBAKitTests/IsraelLocalLiveActivityCoordinatorTests`
21. `OBAKitTests/IsraelTripBackgroundTrackingCoordinatorTests`
22. `OBAKitTests/IsraelTargetMembershipTests` *(NEW)*
23. `OBAKitTests/ScreenAwakeCoordinatorTests`
24. `OBAKitUITests/IsraelTransitRepairUITests`
