# Israel MOT Adapter Test Report & Verification

## 1. Test Suite Summary

The `IsraelMOT` test suite is written using **Swift Testing** (`import Testing`, Swift 6 native) and integrates into `OBAKitTests`. It covers decoding, domain mapping, HTTP resilience, REST bridge envelopes, and trip planning error handling.

| Test Suite | File Location | Tests Count | Scope |
| :--- | :--- | :---: | :--- |
| **`MOTDTODecodingTests`** | `IsraelMOT/Tests/DTO/MOTDTODecodingTests.swift` | 6 | Verifies decoding of all 5 live MOT API fixtures & malformed JSON error handling |
| **`MOTMapperTests`** | `IsraelMOT/Tests/Mappers/MOTMapperTests.swift` | 6 | Tests `MOTStopMapper`, `MOTRouteMapper`, `MOTArrivalsMapper`, polyline encode/decode |
| **`MOTHTTPClientTests`** | `IsraelMOT/Tests/HTTP/MOTHTTPClientTests.swift` | 5 | Tests `MOTEndpoints`, `MOTBackoff`, `MOTCache`, `MOTIdentityStore`, WAF support IDs |
| **`MOTCompatibilityDataLoaderTests`** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | 3 | Verifies OBA REST envelope synthesis and fallback loader delegation |
| **`MOTTripPlanningTests`** | `IsraelMOT/Tests/Integration/MOTTripPlanningTests.swift` | 4 | Tests OTPKit itinerary mapping and truthful F5 WAF error handling |
| **TOTAL** | | **24** | **100% Passing** |

---

## 2. Captured Real API Fixtures

The tests execute against real captured JSON payloads retrieved from the live MOT servers:
- `stop_5997_fulldata.json`: Live data for Stop 5997 (Sarei Yisrael / Hashmonaim, Jerusalem), containing lines 15, 68, etc.
- `route_33285_fulldata.json`: Full route details for Superbus Line 15.
- `route_33285_stops.json`: Ordered stop sequence for Route 33285.
- `search_locations_jerusalem.json`: Autocomplete suggestions for Jerusalem query.
- `route_planning_success_fixture.json`: Valid itinerary solution with walking and transit legs.

---

## 3. How to Run Tests

### In Xcode / macOS
```bash
scripts/generate_project OneBusAway --no-watch
xcodebuild test \
  -project OneBusAway.xcodeproj \
  -scheme 'App' \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OBAKitTests/MOTDTODecodingTests \
  -only-testing:OBAKitTests/MOTMapperTests \
  -only-testing:OBAKitTests/MOTHTTPClientTests \
  -only-testing:OBAKitTests/MOTCompatibilityDataLoaderTests \
  -only-testing:OBAKitTests/MOTTripPlanningTests
```

### In GitHub Actions CI
Automated execution runs on every push and pull request via `.github/workflows/israel-ios-ci.yml`.
Test logs and unsigned `.ipa` build artifacts are automatically uploaded as job artifacts.
