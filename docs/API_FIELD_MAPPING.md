# MOT API to OneBusAway & OTPKit Field Mapping Reference

This document details the exact field-level translations between the Israeli Ministry of Transport (`api.bus.gov.il`) OpenAPI endpoints and the OneBusAway (`OBAKitCore`) / OpenTripPlanner (`OTPKit`) domain models.

---

## 1. Stop Models: `Stops/GetStopFullData` -> `OBAKitCore.Stop`

| MOT API Field (`StopFullDataResponseDTO`) | MOT Type | OBA REST Envelope Key | `OBAKitCore.Stop` Property | Mapping Notes |
| :--- | :--- | :--- | :--- | :--- |
| `stopcode` | `Int` | `code` | `stop.code` | Public 4-5 digit physical stop identifier (e.g., `5997`). |
| `stopid` | `Int` | `id` | `stop.id` | Scoped as `mot:stop:<stopcode>`. Database internal ID stored in references. |
| `name.he` | `String` | `name` | `stop.name` | Hebrew stop title (e.g., "סילבר/שכטמן"). |
| `lat` | `Double` | `lat` | `stop.latitude` | WGS84 decimal latitude. |
| `lng` | `Double` | `lon` | `stop.longitude` | WGS84 decimal longitude. |
| `cityName` | `String?` | Custom reference | Extended info | Formatted into subtitle or description. |
| `platformNumber` | `String?` | `direction` | `stop.direction` | Platform or bay index where applicable. |
| `routesInStop` | `[RouteInStopDTO]` | `routeIds` | `stop.routes` | Array of route identifiers linked to stop. |

---

## 2. Route Models: `Routes/GetRouteFullData` -> `OBAKitCore.Route`

| MOT API Field (`RouteFullDataResponseDTO`) | MOT Type | OBA REST Envelope Key | `OBAKitCore.Route` Property | Mapping Notes |
| :--- | :--- | :--- | :--- | :--- |
| `routeId` | `Int` | `id` | `route.id` | Scoped as `mot:route:<routeId>`. |
| `routeName` | `String` | `shortName` | `route.shortName` | Public bus line number (e.g., "31", "71", "480"). |
| `routeLongName` | `String?` | `longName` | `route.longName` | Terminus destination or corridor description. |
| `routeDesc` | `String?` | `description` | `route.routeDescription` | Technical GTFS key format (`<agency><line>-<dir>-<alt>`). |
| `agencyId` | `Int` | `agencyId` | `route.agencyId` | Scoped as `mot:agency:<agencyId>`. |
| `agencyName` | `String` | Reference agency | `agency.name` | Operator name (e.g. "אגד", "סופרבוס", "דן", "מטרופולין"). |
| `polyline` | `String?` | Encoded polyline | Route geometry | Decoded via `MOTLegGeometryMapper` into coordinates. |

---

## 3. Real-Time Arrivals: `Routes/GetNextStopTimesAndLocation` -> `ArrivalDeparture`

| MOT API Field (`NextStopTimeDTO`) | MOT Type | OBA REST Envelope Key | `ArrivalDeparture` Property | Mapping Notes |
| :--- | :--- | :--- | :--- | :--- |
| `data.<stopCode>.stopTimes` | `[NextStopTimeDTO]` | `arrivalsAndDepartures` | `[ArrivalDeparture]` | Returned dictionary keyed by stop code. |
| `arrivalTime` | `String?` | `scheduledArrivalTime` | `arrival.scheduledArrivalTime` | Parsed via `MOTDateParser` (`Asia/Jerusalem`). |
| `staticArrivalTime` | `String?` | Fallback schedule | `arrival.scheduledArrivalTime` | Static timetable departure when available. |
| `minutesToArrival` | `Double?` | Delta calculation | `arrival.predictedArrivalTime` | Minutes to arrival relative to query time. |
| `isRealTime` | `Bool?` | `predicted` | `arrival.isPredicted` | `true` only when SIRI vehicle tracking is live. No fake real-time. |
| `routeLocation` | `CoordinateDTO?` | `tripStatus.position` | `arrival.vehicleLocation` | Real-time vehicle latitude/longitude position when `isRealTime: true`. |
| **No Data** | Empty array / null | Omitted | No arrival generated | **No fake placeholder**: `now + 600s` eliminated. |

---

## 4. Trip Planning: `RoutePlanning/GetRoutes` -> `OTPKit.Plan` / `Itinerary` / `Leg`

| MOT API Field (`RouteResponseDTO`) | OTPKit Target | Property | Mapping Logic |
| :--- | :--- | :--- | :--- |
| `routeId` | `Itinerary` | `id` | Route identifier. |
| `sections` | `Itinerary.legs` | `legs` | Array of transit and pedestrian legs. |
| `section.type: "pedestrian"` | `Leg` | `mode` / `transitLeg` | `mode = "WALK"`, `transitLeg = false`, `routeType = .nonTransit`. |
| `section.type: "transit"` | `Leg` | `mode` / `transitLeg` | `mode` from `transport.mode` (BUS, TRAM, RAIL), `transitLeg = true`. |
| `section.departure.time` | `Leg` | `startTime` | Parsed as `Asia/Jerusalem` local time via `MOTDateParser`. |
| `section.arrival.time` | `Leg` | `endTime` | Parsed as `Asia/Jerusalem` local time via `MOTDateParser`. |
| `section.polyline` | `Leg` | `legGeometry` | Decoded from HERE Flexible Polyline v1 and re-encoded to Google E5. |
| `section.actions` | `Leg.steps` | `[Step]` | 87 turn-by-turn walking actions with Hebrew instructions and coordinates. |
| Transit transfers | `Itinerary` | `transfers` | `max(transitLegCount - 1, 0)`. (0 for direct line 71; 2 for 31->78->34). |
