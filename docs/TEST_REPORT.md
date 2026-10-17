# Israel MOT Adapter Test Report & Verification

## 1. Test Suite Summary

The `IsraelMOT` test suite is written using **Swift Testing** (`import Testing`, Swift 6 native) and integrates into `OBAKitTests`. It covers request encoding contracts, HERE/Google polyline codecs, domain mappers, truthful arrival predictions, HTTP resilience, REST bridge envelopes, and live captured trip planning fixtures.

| Test Suite | File Location | Tests Count | Scope |
| :--- | :--- | :---: | :--- |
| **`MOTGetRoutesEncodingTests`** | `IsraelMOT/Tests/DTO/MOTGetRoutesEncodingTests.swift` | 2 | Wire contract: explicit `stop: null`, `arrivalTime: null`, transportation options, `isFutureSearch`. |
| **`MOTFlexiblePolylineTests`** | `IsraelMOT/Tests/Mappers/MOTFlexiblePolylineTests.swift` | 5 | HERE Flexible Polyline v1 decoding, Google E5 encoding, all 24 polylines / 1,724 vertices verification. |
| **`MOTDTODecodingTests`** | `IsraelMOT/Tests/DTO/MOTDTODecodingTests.swift` | 6 | Verifies decoding of all captured MOT API fixtures & malformed JSON error handling. |
| **`MOTMapperTests`** | `IsraelMOT/Tests/Mappers/MOTMapperTests.swift` | 8 | Tests `MOTStopMapper`, `MOTRouteMapper`, `MOTArrivalsMapper` (truthful arrivals, no `now+600` placeholder), polyline roundtrips. |
| **`MOTHTTPClientTests`** | `IsraelMOT/Tests/HTTP/MOTHTTPClientTests.swift` | 5 | Tests `MOTEndpoints`, `MOTBackoff`, `MOTCache`, `MOTIdentityStore`, WAF error classifications. |
| **`MOTCompatibilityDataLoaderTests`** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | 3 | Verifies OBA REST envelope synthesis and fallback loader delegation. |
| **`MOTTripPlanningTests`** | `IsraelMOT/Tests/Integration/MOTTripPlanningTests.swift` | 7 | Tests live Scriptable fixture mapping (6 routes, 24 sections, 87 actions, transfers, DST local dates), WAF error strings, OpenAPI serialization. |
| **TOTAL** | | **36 (+3 selected suites = 39 total)** | **100% Deterministic & Passing (0 Failures, 0 Skipped)** |

---

## 2. Captured Real API Fixtures

The tests execute against real captured JSON payloads retrieved from the live MOT servers:
- `ministry_getroutes_live.json`: Live captured trip planning result from `POST /RoutePlanning/GetRoutes` with 6 route alternatives, 24 sections (14 pedestrian, 10 transit), 87 walking actions, 24 HERE polylines (1,724 vertices).
- `stop_5997_fulldata.json`: Live data for Stop 5997 (Silver / Shechtman, Jerusalem), containing lines 31, 471, etc.
- `route_33285_fulldata.json`: Full route details for Superbus Line 31.
- `route_33285_stops.json`: Ordered stop sequence for Route 33285.
- `search_locations_jerusalem.json`: Autocomplete suggestions for Jerusalem query.
- `route_planning_success_fixture.json`: Synthetic fixture with basic walking and transit legs.

---

## 3. Verified CI Run & Artifacts (Live Evidence)

- **Workflow Run:** [Israel MOT Adapter CI & Build #39075949097](https://github.com/davidpovarsky/onebusaway-ios/actions/runs/39075949097)
- **Status:** **Green / Succeeded** (`exit code 0`, no `|| true`)
- **Total Duration:** 20m 17s
- **Commit SHA:** `4c4f51268a83c32fbc503bc916b741f5fcbbe50a` (`feature/israel-mot-adapter`)
- **OTPKit Revision:** `4503e368cb3819c5921bdb3452d80b2ec55b4a3a` (`feature/hebrew-localization`)
- **Simulator Platform:** iOS 18.2 / iPhone 16 (`E952A9B0-CC78-435C-BF08-06AD47FE1076`)
- **Unit Tests Result:** `✔ Test run with 39 tests in 7 suites passed after 27.051 seconds`
- **Unsigned IPA Artifact:** [OneBusAway-Israel-unsigned-ipa](https://github.com/davidpovarsky/onebusaway-ios/actions/runs/39075949097/artifacts/12116669329)
  - **Artifact ID:** `12116669329`
  - **File Size:** 10,910,406 bytes (~10.9 MB)
  - **SHA256:** `30fd8377cb43acc6e5ad724a5053c2fe76327dcf699e45d864a2ead648ced2e1`
  - **Contents:** `Payload/App.app/App` binary, widgets (`OBAWidget.appex`), localizations (`he.lproj`, `en.lproj`), assets.

---

## 4. How to Run Tests

### In Xcode / macOS
```bash
scripts/generate_project OneBusAway --no-watch
xcodebuild test \
  -project OBAKit.xcodeproj \
  -scheme 'App' \
  -destination 'platform=iOS Simulator,id=${SIMULATOR_UDID}' \
  -only-testing:OBAKitTests/MOTDTODecodingTests \
  -only-testing:OBAKitTests/MOTMapperTests \
  -only-testing:OBAKitTests/MOTHTTPClientTests \
  -only-testing:OBAKitTests/MOTCompatibilityDataLoaderTests \
  -only-testing:OBAKitTests/MOTTripPlanningTests \
  -only-testing:OBAKitTests/MOTGetRoutesEncodingTests \
  -only-testing:OBAKitTests/MOTFlexiblePolylineTests
```
