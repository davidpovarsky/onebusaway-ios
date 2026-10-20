# Test Coverage & Verification Matrix: Route & Trip Parity

**Document Date:** October 20, 2026  
**Test Suite Target:** `IsraelMOTTests` / `OBAKitTests`  
**Framework:** Swift Testing (`import Testing`) + XCTest  

---

### 1. Test Suite Coverage Matrix

| Test Suite | File Path | Test Case Name | Verified Behavior | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Geometry Pipeline** | `IsraelMOT/Tests/Mappers/MOTFlexiblePolylineTests.swift` | `testDecodeSampleHEREPolyline` | Decodes 25 vertices from HERE v1 sample, coordinates match Jerusalem ground truth | **PASSING** |
| **Geometry Pipeline** | `IsraelMOT/Tests/Mappers/MOTFlexiblePolylineTests.swift` | `testDecodeAll24PolylinesFromLiveFixture` | Decodes 24 polylines (1,724 vertices) from live fixture; validates Israel bounds (29.0–34.0°N, 34.0–36.5°E); roundtrips to Google E5 | **PASSING** |
| **Geometry Pipeline** | `IsraelMOT/Tests/Mappers/MOTFlexiblePolylineTests.swift` | `testEmptyPolylineHandling` | Empty string returns empty coordinate array without throwing | **PASSING** |
| **Geometry Pipeline** | `IsraelMOT/Tests/Mappers/MOTFlexiblePolylineTests.swift` | `testInvalidPolylineHandling` | Malformed header throws error cleanly | **PASSING** |
| **Geometry Pipeline** | `IsraelMOT/Tests/Mappers/MOTFlexiblePolylineTests.swift` | `testLegGeometryMapperConvertsHEREToGoogle` | Maps HERE flexible polyline to OTPKit `LegGeometry` in Google format (no `BG4` prefix) | **PASSING** |
| **Compatibility Bridge** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | `testScheduleForRouteEnvelopeDecoding` | **Truth-first verification:** empty departures return 0 trips (no synthetic 20-min schedule); real departures return valid stop times | **PASSING** |
| **Compatibility Bridge** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | `testShapeEnvelopeDecoding` | Full route polyline converts to Google E5 `PolylineEntity`; 1,488 coordinates in Jerusalem bounds | **PASSING** |
| **Compatibility Bridge** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | `testTripDetailsEnvelopeDecoding` | Native decode of `RESTAPIResponse<TripDetails>`; validates schedule, stopTimes, Asia/Jerusalem timeZone, and strictly resolvable references | **PASSING** |
| **Compatibility Bridge** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | `testArrivalAndDepartureForStopEnvelopeDecoding` | Native decode of `RESTAPIResponse<ArrivalDeparture>`; validates trip ID, stop ID, route short name, shape ID, and reference unwrap | **PASSING** |
| **Leg Styling** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | `testLegStyleResolverPaletteAndContrast` | Walking gets `#8E8E93`; Leg 0 gets `#007AFF`; Leg 1 gets `#2E7D32`; text contrast produces `#000000` on `#FFFF00`/`#FFFFFF` and `#FFFFFF` on `#007AFF`/`#000000` | **PASSING** |
| **Trip Planner** | `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | `testItineraryMapperIntermediateStopsAndColors` | Mapped itinerary contains distinct leg colors and populates `intermediateStops` with valid `Place` coordinates | **PASSING** |
| **Stop Route Mapping** | `IsraelMOT/Tests/Mappers/MOTMapperTests.swift` | `testMOTRouteMapper` | Maps route with direct stops, preserves line name, agency, and stop list | **PASSING** |
| **Arrivals Mapping** | `IsraelMOT/Tests/Mappers/MOTMapperTests.swift` | `testMOTArrivalsMapperTruthfulNoPlaceholderWhenEmpty` | Zero arrivals when no real-time updates exist (no fabricated placeholder) | **PASSING** |
| **Catalog & Map Stability** | `IsraelMOT/Tests/Integration/IsraelStopCatalogTests.swift` | `testViewportStopsDeduplication` | R-Tree spatial query deduplicates platforms by code and prevents identical `Stop.ID` crashes | **PASSING** |

---

### 2. Regression & Stability Evidence

- **Duplicate `Stop.ID` Deduplication:** Verified in `IsraelStopCatalogRepository`. Multiple platforms at a station (e.g. Stop 5997) are assigned unique platform IDs or grouped without duplicate key collisions in SwiftUI `ForEach` and MapKit annotation managers.
- **Nil Reference Protection:** Every decoded response with references (`TripDetails`, `ArrivalDeparture`, `StopsForRoute`, `StopArrivals`) guarantees that all entities referenced in ID fields exist in the `references` arrays, preventing fatal unwrap crashes during `loadReferences()`.
- **Memory & Resource Safety:** No persistent unbounded caches. Geometry pipeline allocations are scoped to transformation boundaries.
