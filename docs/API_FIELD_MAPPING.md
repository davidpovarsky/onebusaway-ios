# MOT API to OneBusAway & OTPKit Field Mapping Reference

This document details the exact field-level translations between the Israeli Ministry of Transport (`api.bus.gov.il`) OpenAPI endpoints and the OneBusAway (`OBAKitCore`) / OpenTripPlanner (`OTPKit`) domain models.

---

## 1. Stop Models: `StopData/GetStopFullData` -> `OBAKitCore.Stop`

| MOT API Field (`StopFullDataResponseDTO`) | MOT Type | OBA REST Envelope Key | `OBAKitCore.Stop` Property | Mapping Notes |
| :--- | :--- | :--- | :--- | :--- |
| `stopcode` | `Int` | `code` | `stop.code` | Public 4-5 digit physical stop identifier (e.g., `5997`). |
| `stopid` | `Int` | `id` | `stop.id` | Scoped as `mot:stop:<stopcode>`. Database internal ID stored in references. |
| `name.he` | `String` | `name` | `stop.name` | Hebrew stop title (e.g., "שרי ישראל/חשמונאים"). |
| `lat` | `Double` | `lat` | `stop.latitude` | WGS84 decimal latitude. |
| `lng` | `Double` | `lon` | `stop.longitude` | WGS84 decimal longitude. |
| `cityName` | `String?` | Custom reference | Extended info | Formatted into subtitle or description. |
| `platformNumber` | `String?` | `direction` | `stop.direction` | Platform or bay index where applicable. |
| `isCanceled` | `Bool?` | N/A | Filter flag | Canceled stops are marked inactive or omitted from nearby lists. |
| `routesInStop` | `[RouteInStopDTO]` | `routeIds` | `stop.routes` | Array of route identifiers linked to stop. |

---

## 2. Route Models: `RouteData/GetRouteFullData` -> `OBAKitCore.Route`

| MOT API Field (`RouteFullDataResponseDTO`) | MOT Type | OBA REST Envelope Key | `OBAKitCore.Route` Property | Mapping Notes |
| :--- | :--- | :--- | :--- | :--- |
| `routeId` | `Int` | `id` | `route.id` | Scoped as `mot:route:<routeId>`. |
| `routeName` | `String` | `shortName` | `route.shortName` | Public bus line number (e.g., "15", "68", "480"). |
| `routeLongName` | `String?` | `longName` | `route.longName` | Terminus destination or corridor description. |
| `routeDesc` | `String?` | `description` | `route.routeDescription` | Technical GTFS key format (`<agency><line>-<dir>-<alt>`). |
| `agencyId` | `Int` | `agencyId` | `route.agencyId` | Scoped as `mot:agency:<agencyId>`. |
| `agencyName` | `String` | Reference agency | `agency.name` | Operator name (e.g. "אגד", "סופרבוס", "דן", "מטרופולין"). |
| `polyline` | `String?` | Encoded polyline | Route geometry | Decoded via `MOTLegGeometryMapper` into coordinates. |

---

## 3. Real-Time Arrivals: `Scheduler/NextStopData` -> `ArrivalDeparture`

| MOT API Field (`NextStopRealTimeDTO`) | MOT Type | OBA REST Envelope Key | `ArrivalDeparture` Property | Mapping Notes |
| :--- | :--- | :--- | :--- | :--- |
| `stopCode` | `Int` | `stopId` | `arrival.stopId` | Target stop code. |
| `routeDesc` | `String?` | `routeId` | Resolved Route | Matched against routes serving the stop. |
| `minutesToArrival` | `Int?` | Delta calculation | `arrival.predictedArrivalTime` | `currentTime + minutesToArrival * 60 * 1000`. |
| `arrivalTime` | `String?` | Timetable string | `arrival.scheduledArrivalTime` | Parsed against current calendar day. |
| `isRealTime` | `Bool?` | `predicted` | `arrival.isPredicted` | `true` when SIRI vehicle tracking is live. |
| `vehicleLocation` | `CoordinateDTO?` | `tripStatus.position` | `arrival.vehicleLocation` | Real-time vehicle latitude/longitude position. |

---

## 4. Trip Planning: `RoutePlanning/GetRoutes` -> `OTPKit.Plan` / `Itinerary` / `Leg`

| MOT API Field (`RouteResponseDTO`) | OTPKit Target | Property | Mapping Logic |
| :--- | :--- | :--- | :--- |
| `routeId` | `Itinerary` | `id` | Synthetic itinerary ID. |
| `sections` | `Itinerary.legs` | `legs` | Array of transit and walking legs. |
| `travelSummary.duration` | `Itinerary` | `duration` | Total travel duration in seconds. |
| `travelSummary.length` | `Itinerary` | `walkDistance` | Walking distance accumulated across walk sections. |
| `travelSummary.price` | `Itinerary.fare` | `fare.regular.cents` | Converted from NIS (Shekels) to cents (NIS * 100). |
| `section.type` | `Leg` | `mode` | `WALK` for walking, `BUS` for bus, `RAIL` for train/light rail. |
| `section.departure.time` | `Leg` | `startTime` | ISO8601 parsed timestamp. |
| `section.arrival.time` | `Leg` | `endTime` | ISO8601 parsed timestamp. |
| `section.polyline` | `Leg` | `legGeometry` | Google polyline format. Straight-line fallback if empty. |
| `section.intermediateStops` | `Leg` | `intermediateStops` | Converted to intermediate `Place` objects. |
