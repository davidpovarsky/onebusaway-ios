# OneBusAway Israel: Route, Trip, Map, and Leg-Color Parity
## Implementation & Architecture Report

**Document Date:** October 20, 2026  
**Branch:** `feature/israel-route-trip-parity-20261020`  
**Base Commit:** `59f1c2bac671133a1b960c325b55dd9353f99633`  
**Team Contract:** Named AI Team (`eitan`, `noam`, `maya`, `roni`, `tomer`, `yael`, `dana`) — NORMAL Mode  

---

### 1. Executive Summary

This engineering effort restores complete native route, trip, map geometry, and trip planner experiences for OneBusAway in Israel without regressing the verified physical iPad map-zoom crash fix or introducing fabricated timetable data.

Prior to this work:
1. **Broken Map Geometry:** Ministry of Transport (MOT) `Routes/GetRouteFullData` returns route geometry as HERE Flexible Polyline v1 (23,045 characters, 1,488 vertices in Jerusalem). OBAKitCore expects Google E5 encoded polylines. When OBACompatibilityBridge placed the raw HERE string directly into `points`, native MapKit decoders failed, resulting in straight lines or missing route lines.
2. **Missing Stop Route Focus Polyline:** When viewing arrivals at a stop, `StopRouteFocusMapLayer` requests `arrivalDeparture.shapeID`. In `stopArrivalsResponse`, `"shapeId"` was set to `""`. Consequently, focusing or selecting a route in the stop sheet never drew the route polyline.
3. **Missing OBA Endpoints:** Native UI components trigger calls to `/api/where/shape/{id}.json`, `/api/where/trip-details/{id}.json`, and `/api/where/arrival-and-departure-for-stop/{id}.json`. In `MOTCompatibilityDataLoader`, these paths were unhandled and fell through to `unsupportedOneBusAwayEndpoint`, causing "Trip details unavailable" alerts and preventing long-press peek or full trip screen display.
4. **Synthetic Timetables:** Previous versions of `scheduleForRouteResponse` fabricated artificial trips from 06:00 to 23:00 at 20-minute intervals with hardcoded 90-second stop delays.
5. **Indistinguishable Planner Leg Colors & Missing Intermediate Stops:** Multi-leg transit itineraries had hardcoded identical colors or white text on light backgrounds, and `Leg.intermediateStops` was hardcoded to `[]`, leaving riders without intermediate stop visibility.
6. **Fragile TripViewModel Loading:** An optional polyline or live refresh failure aborted the entire `TripViewModel` loading task, wiping out the stop timeline.

All 6 defects have been resolved with high test coverage, strict reference resolution, and zero synthetic data fabrication.

---

### 2. Workstreams & Technical Solutions

#### Workstream A: Route Geometry & Shape Normalization Pipeline
- **Component:** [`IsraelMOT/Core/Geometry/MOTRouteGeometryPipeline.swift`](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Core/Geometry/MOTRouteGeometryPipeline.swift)
- **Problem Solved:** Robust conversion of heterogeneous polyline encodings to Google E5.
- **Implementation:**
  - Auto-detects HERE Flexible Polyline format (starting with `B...`) or Google E5 format.
  - Decodes coordinates and strictly validates against:
    - Finite coordinate values (`latitude.isFinite`, `longitude.isFinite`).
    - Null Island elimination (`!(abs(lat) < 0.001 && abs(lon) < 0.001)`).
    - Israel geographical service bounds ($29.0^\circ\text{N} \le \text{lat} \le 33.5^\circ\text{N}$, $34.0^\circ\text{E} \le \text{lon} \le 36.0^\circ\text{E}$).
  - Re-encodes cleanly to Google E5 format with 5 decimal places of precision ($1\times 10^{-5}$ degrees $\approx 1.1\text{m}$).
  - Integrated into `OBACompatibilityBridge.stopsForRouteResponse`, `OBACompatibilityBridge.shapeResponse`, and `MOTCompatibilityDataLoader.handleShape`.
- **Stop Sequence & Platform Parity:**
  - Extended `RouteFullDataResponseDTO` to decode `stops: [StopOnRouteDTO]`, `stopSequence`, `isPickup`, `isDropoff`, and `platformNumber`.
  - Updated `MOTRouteMapper.map(routeDTO:stopsDTO:)` to prioritize authentic direct stops over legacy route stops.

#### Workstream B: Stop Route Focus & Single Arrival/Departure
- **Component:** [`IsraelMOT/OBAAdapter/OBACompatibilityBridge.swift`](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/OBACompatibilityBridge.swift) and [`IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift`](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift)
- **Problem Solved:**
  - `stopArrivalsResponse` now populates `"shapeId": "mot:shape:\(arrival.routeID.rawValue)"`.
  - Implemented URL interception for `/api/where/arrival-and-departure-for-stop/{id}.json`. Note: intercepted *before* the plural `/arrivals-and-departures-for-stop/` pattern in `MOTCompatibilityDataLoader`.
  - Built `OBACompatibilityBridge.arrivalAndDepartureForStopResponse(stop:route:arrival:tripID:serviceDate:)`.
  - References dictionary populates complete `stop`, `trip`, `route`, and `agency` objects to ensure OBAKit's `HasReferences.loadReferences()` resolves all non-optional relationships without runtime aborts.

#### Workstream C: Long-Press Preview & Full Trip Screen (`/where/trip-details/`)
- **Components:**
  - `MOTCompatibilityDataLoader.handleTripDetails(url:)`
  - `OBACompatibilityBridge.tripDetailsResponse(...)`
  - [`OBAKit/ViewModels/TripViewModel.swift`](file:///c:/Users/DAVID/Code/onebusaway-ios/OBAKit/ViewModels/TripViewModel.swift)
- **Problem Solved:**
  - When riders long-press an arrival card or tap "View Trip Details", OBAKit calls `/api/where/trip-details/{id}.json`.
  - Built full `TripDetails` envelope including:
    - `tripId`: Authentic scoped ID (e.g. `mot:trip:33285_12345_20261020`).
    - `serviceDate`: Start of service day in milliseconds (`Asia/Jerusalem`).
    - `timeZone`: `"Asia/Jerusalem"`.
    - `schedule.stopTimes`: Array of `TripStopTime` entries with authentic stop sequences and arrival/departure seconds.
    - `status`: Vehicle position if real-time tracking is active, with neutral zero orientation (no synthetic heading interpolation).
    - `references`: Every stop referenced in `stopTimes` is fully defined in `references.stops`, alongside `trips`, `routes`, and `agencies`.
- **TripViewModel Resilience:**
  - Updated `TripViewModel.refresh()` to decouple essential trip timeline data from optional supplementary fetches.
  - Implemented `fetchMapPolylineSilently()` and `fetchTripConvertibleSilently()`. A shape failure or network glitch no longer aborts the entire view model or wipes the stop list.

#### Workstream D: Timetable & Schedule Truth-First Policy
- **Component:** `OBACompatibilityBridge.scheduleForRouteResponse(...)`
- **Problem Solved:**
  - Eliminated the legacy artificial schedule generator that synthesized departures every 20 minutes from 06:00 to 23:00.
  - When official Ministry daily departures are absent, `tripsWithStopTimes` returns an empty array, permitting native UI to present the truthful empty state ("No scheduled departures found").
  - When departures exist, real trip IDs, service days, and authentic departure seconds are accurately mapped.

#### Workstream E: Leg Colors & Intermediate Stops in Trip Planner
- **Components:**
  - [`IsraelMOT/OTPAdapter/MOTLegStyleResolver.swift`](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OTPAdapter/MOTLegStyleResolver.swift)
  - [`IsraelMOT/OTPAdapter/MOTItineraryMapper.swift`](file:///c:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/OTPAdapter/MOTItineraryMapper.swift)
- **Problem Solved:**
  - `MOTLegStyleResolver`:
    - Checks official `SectionDTO.transport.color` and normalizes valid hex values to `#RRGGBB`.
    - If absent or invalid, assigns a deterministic, accessible color from a curated palette:
      - Leg 1: System Blue (`#007AFF`)
      - Leg 2: Forest Green (`#2E7D32`) — matches Ministry 86 -> 67 transfer example
      - Leg 3: Deep Purple (`#7B1FA2`)
      - Leg 4: Deep Amber (`#E65100`)
      - Leg 5: Dark Teal (`#00838F`)
      - Leg 6: Dark Rose (`#C2185B`)
    - Walking legs receive neutral Apple System Gray (`#8E8E93`).
    - Calculates high-contrast badge text color (`#000000` on bright backgrounds, `#FFFFFF` on dark backgrounds) via standard ITU-R perceived luminance:
      $$L = 0.299 R + 0.587 G + 0.114 B$$
  - `MOTItineraryMapper`:
    - Extracts `SectionDTO.intermediateStops` and maps each station to an authentic `Place` with coordinates and stop codes.
    - Enables OTPKit's `MapCoordinator` and `RailRowContentViews` to render intermediate stops on the route map and expandable stop lists.

#### Workstream F: Non-Regression of iPad Map Zoom Crash Fix
- **Components Preserved:**
  - `IsraelStopCatalogRepository.stops(...)` deduplication of identical `Stop.ID` strings across platforms.
  - Bounding box clamping and spatial index limits.
  - Release-build debug wrap assertions.
  - Result: 0 simulator crash reports, no duplicate ID assertion failures.

---

### 3. File Change Summary

| File | Type | Changes |
| :--- | :--- | :--- |
| `IsraelMOT/Core/Geometry/MOTRouteGeometryPipeline.swift` | New | HERE v1 / Google E5 decoding, Israel bounds validation, Google E5 encoding |
| `IsraelMOT/OTPAdapter/MOTLegStyleResolver.swift` | New | Deterministic per-leg color resolver, text contrast calculation, hex validation |
| `IsraelMOT/Contracts/Identifiers.swift` | Modified | Added `scopedShapeID`, `scopedTripID`, `parseRouteIDFromShapeID`, `parseRouteIDFromTripID` |
| `IsraelMOT/Contracts/TransitDomainModels.swift` | Modified | Extended `TransitArrival` with static trip ID, tripIdToDate, stop sequence, agency info |
| `IsraelMOT/Core/DTO/Scheduler/RouteFullDataResponseDTO.swift` | Modified | Added `stops`, `stopSequence`, `isPickup`, `isDropoff`, `platformNumber`, `nextStopsTimes` |
| `IsraelMOT/Core/Mappers/Arrivals/MOTArrivalsMapper.swift` | Modified | Maps static trip ID, stop sequence, agency data to `TransitArrival` |
| `IsraelMOT/Core/Mappers/Routes/MOTRouteMapper.swift` | Modified | Prioritizes direct stops from full data DTO, captures platform numbers |
| `IsraelMOT/OBAAdapter/MOTCompatibilityDataLoader.swift` | Modified | URL dispatch and handlers for `/shape/`, `/trip-details/`, `/arrival-and-departure-for-stop/` |
| `IsraelMOT/OBAAdapter/OBACompatibilityBridge.swift` | Modified | Implemented `shapeResponse`, `tripDetailsResponse`, `arrivalAndDepartureForStopResponse`, populated `shapeId` in arrivals, removed synthetic timetables |
| `IsraelMOT/OTPAdapter/MOTItineraryMapper.swift` | Modified | Integrated `MOTLegStyleResolver`, mapped `intermediateStops` to `[Place]` |
| `IsraelMOT/Tests/Integration/MOTCompatibilityDataLoaderTests.swift` | Modified | Added decode tests for `PolylineEntity`, `TripDetails`, `ArrivalDeparture`, leg style, and intermediate stops |
| `OBAKit/ViewModels/TripViewModel.swift` | Modified | Resilience against optional polyline/convertible failures |
