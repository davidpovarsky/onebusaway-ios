# Israel MOT Adapter Test Report & Verification

## 1. Test Suite Summary

The `IsraelMOT` test suite is written using **Swift Testing** (`import Testing`, Swift 6 native) and integrates into `OBAKitTests`. It covers request encoding contracts, HERE/Google polyline codecs, domain mappers, truthful arrival predictions, HTTP resilience, REST bridge envelopes, and live captured trip planning fixtures.

| Test Suite | File Location | Tests Count | Scope |
| :--- | :--- | :---: | :--- |
| **`MOTGetRoutesEncodingTests`** | `IsraelMOT/Tests/DTO/MOTGetRoutesEncodingTests.swift` | 2 | Wire contract: explicit `stop: null`, `arrivalTime: null`, transportation options, `isFutureSearch`. |
| **`MOTFlexiblePolylineTests`** | `IsraelMOT/Tests/Mappers/MOTFlexiblePolylineTests.swift` | 5 | HERE Flexible Polyline v1 decoding, Google E5 encoding, all 24 polylines / 1,724 vertices verification. |
| **`MOTDTODecodingTests`** | `IsraelMOT/Tests/DTO/MOTDTODecodingTests.swift` | 6 | Verifies decoding of all captured MOT API fixtures & malformed JSON error handling. |
| **`MOTMapperTests`** | `IsraelMOT/Tests/Mappers/MOTMapperTests.swift` | 7 | Tests `MOTStopMapper`, `MOTRouteMapper`, `MOTArrivalsMapper` (truthful arrivals, no `now+600` placeholder). |
| **`MOTHTTPClientTests`** | `IsraelMOT/Tests/HTTP/MOTHTTPClientTests.swift` | 5 | Tests `MOTEndpoints`, `MOTBackoff`, `MOTCache`, `MOTIdentityStore`, WAF error classifications. |
| **`MOTCompatibilityDataLoaderTests`** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | 3 | Verifies OBA REST envelope synthesis and fallback loader delegation. |
| **`MOTTripPlanningTests`** | `IsraelMOT/Tests/Integration/MOTTripPlanningTests.swift` | 5 | Tests live Scriptable fixture mapping (6 routes, 24 sections, 87 actions, transfers, DST local dates). |
| **TOTAL** | | **33** | **100% Deterministic & Passing** |

---

## 2. Captured Real API Fixtures

The tests execute against real captured JSON payloads retrieved from the live MOT servers:
- `ministry_getroutes_live.json`: Live captured trip planning result from `POST /RoutePlanning/GetRoutes` with 6 route alternatives, 24 sections (14 pedestrian, 10 transit), 87 walking actions, 24 HERE polylines.
- `stop_5997_fulldata.json`: Live data for Stop 5997 (Silver / Shechtman, Jerusalem), containing lines 31, 471, etc.
- `route_33285_fulldata.json`: Full route details for Superbus Line 31.
- `route_33285_stops.json`: Ordered stop sequence for Route 33285.
- `search_locations_jerusalem.json`: Autocomplete suggestions for Jerusalem query.
- `route_planning_success_fixture.json`: Synthetic fixture with basic walking and transit legs.

---

## 3. How to Run Tests

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

### In GitHub Actions CI
Automated execution runs on every push and pull request via `.github/workflows/israel-ios-ci.yml`.
Test logs and unsigned `.ipa` build artifacts are automatically uploaded as job artifacts.
There is strictly no `|| true` in the CI test execution.
