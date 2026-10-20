# MOT-to-OBA Endpoint & Data Transformation Matrix

**Document Date:** October 20, 2026  
**Module:** `IsraelMOT`  
**Compatibility Layer:** `MOTCompatibilityDataLoader` + `OBACompatibilityBridge`  

---

### 1. Endpoint Mapping Matrix

| OneBusAway REST Endpoint | Query Parameters | Dispatched Handler | Underlying MOT API Call | Response Payload Structure | Reference Resolution |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/api/where/stops-for-location.json` | `lat`, `lon`, `latSpan`, `lonSpan`, `query` | `handleStopsForLocation` | Local Spatial R-Tree (fallback `SearchLocations/AutoComplete`) | `RESTAPIResponse<[Stop]>` | None required |
| `/api/where/stop/{id}.json` | Path: `{id}` (`mot:stop:<code>`) | `handleStopDetail` | Local catalog + `Scheduler/GetStopFullData` | `RESTAPIResponse<Stop>` | `routes`, `agencies` |
| `/api/where/arrivals-and-departures-for-stop/{id}.json` | Path: `{id}`, `minutesBefore`, `minutesAfter` | `handleArrivalsAndDepartures` | `Scheduler/GetStopFullData` + `Scheduler/GetNextStopTimesAndLocation` | `RESTAPIResponse<StopArrivals>` | `stops`, `routes`, `agencies`, `trips` |
| `/api/where/arrival-and-departure-for-stop/{id}.json` | Path: `{id}`, `tripId`, `serviceDate`, `vehicleId`, `stopSequence` | `handleSingleArrivalAndDeparture` | `handleArrivalsAndDepartures` (matching trip ID & sequence) | `RESTAPIResponse<ArrivalDeparture>` | `stop`, `trip`, `route`, `agency` |
| `/api/where/route/{id}.json` | Path: `{id}` (`mot:route:<id>`) | `handleRouteDetail` | `Routes/GetRouteFullData` | `RESTAPIResponse<Route>` | `agencies` |
| `/api/where/stops-for-route/{id}.json` | Path: `{id}` (`mot:route:<id>`) | `handleStopsForRoute` | `Routes/GetRouteFullData` + `Routes/GetRouteStops` | `RESTAPIResponse<StopsForRoute>` | `stops`, `routes`, `agencies`, `polylines` |
| `/api/where/schedule-for-route/{id}.json` | Path: `{id}` (`mot:route:<id>`) | `handleScheduleForRoute` | `Routes/GetRouteFullData` + `Scheduler/GetRouteDailyCalendar` | `RESTAPIResponse<ScheduleForRoute>` | `stops`, `routes`, `agencies`, `trips` |
| `/api/where/shape/{id}.json` | Path: `{id}` (`mot:shape:<routeId>`) | `handleShape` | `Routes/GetRouteFullData` | `RESTAPIResponse<PolylineEntity>` | None required |
| `/api/where/trip-details/{id}.json` | Path: `{id}` (`mot:trip:<routeId>_<trip>_<date>`), `serviceDate` | `handleTripDetails` | `Routes/GetRouteFullData` + live arrivals | `RESTAPIResponse<TripDetails>` | `stops`, `routes`, `agencies`, `trips` |
| `/api/where/agencies-with-coverage.json` | None | Direct loader answer | In-memory synthetic definition | `RESTAPIResponse<[AgencyWithCoverage]>` | None required |

---

### 2. Detailed Data Transformation Specifications

#### A. Shape Transformation (`/where/shape/{id}.json`)
- **Input:** `mot:shape:<routeId>`
- **Extracted Route ID:** `MOTIdentityFormatter.parseRouteIDFromShapeID(id)`
- **MOT Source:** `RouteFullDataResponseDTO.polyline` (HERE Flexible Polyline format v1)
- **Pipeline:** `MOTRouteGeometryPipeline.toGoogleE5(herePolyline)`
  1. Decodes variable-length integer deltas with header version byte.
  2. Validates finite numbers, non-zero coordinates, and Israel service bounding box.
  3. Encodes coordinates to Google E5 ASCII format.
- **Output:**
  ```json
  {
    "code": 200,
    "currentTime": 1729437600000,
    "text": "OK",
    "version": 2,
    "data": {
      "entry": {
        "points": "w{fxFa}sW_A..."
      }
    }
  }
  ```

#### B. Trip Details Transformation (`/where/trip-details/{id}.json`)
- **Input:** `mot:trip:33285_12345_20261020`
- **Output Structure:**
  - `entry.tripId`: Scoped ID
  - `entry.serviceDate`: Milliseconds since epoch (`Asia/Jerusalem` day boundary)
  - `entry.timeZone`: `"Asia/Jerusalem"`
  - `entry.schedule.stopTimes`:
    ```json
    {
      "stopId": "mot:stop:5997",
      "tripId": "mot:trip:33285_12345_20261020",
      "arrivalTime": 36000,
      "departureTime": 36000,
      "stopSequence": 1,
      "arrivalEnabled": true,
      "departureEnabled": true
    }
    ```
  - `entry.status`: Real-time vehicle location (if available) with `lastKnownOrientation: 0.0`.
  - `references`: Complete cross-referenced set for safe unwrap:
    - `stops`: Array of all `TransitStop` objects referenced in `stopTimes`.
    - `trips`: Array containing the represented trip.
    - `routes`: Array containing the parent route.
    - `agencies`: Array containing the operating agency.

#### C. Stop Arrivals Transformation (`/where/arrivals-and-departures-for-stop/{id}.json`)
- **Shape ID Field:**
  - Formerly: `"shapeId": ""`
  - Restored: `"shapeId": "mot:shape:\(arrival.routeID.rawValue)"`
- **Single Arrival/Departure:**
  - Directly matches `arrivalAndDeparture.tripID == queryTripId` and returns single `ArrivalDeparture` entry with all references included.
