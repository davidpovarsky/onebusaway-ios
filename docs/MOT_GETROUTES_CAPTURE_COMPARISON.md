# MOT GetRoutes Capture Comparison

## Executive Summary
This document analyzes the differences between the official Ministry of Transport (MOT) `RoutePlanning/GetRoutes` API response and the third-party Bus Nearby `api.busnearby.co.il/directions` response, based on live traces captured in October 2026.

---

## 1. Metric Comparison Matrix

| Metric | Ministry of Transport (`api.bus.gov.il`) | Bus Nearby (`api.busnearby.co.il`) | Architectural Decision |
|---|---|---|---|
| **Protocol / Method** | `POST /RoutePlanning/GetRoutes` | `GET /directions` | Use MOT API directly via `MOTTripPlanningAPIService` |
| **Response Format** | JSON ServiceResponse (`data`, `success`) | Custom nested JSON | Decode MOT contract directly into `RouteResponseDTO` |
| **Alternatives Count** | 6 alternatives | 6 alternatives | Distinct route solutions; cannot be indexed interchangeably |
| **Alternative 1 (Line 71)** | Depart 09:32, Arrive 10:10 (38 min) | Depart 09:26, Arrive 10:12 (46 min) | Keep MOT timestamps; do not mix schedules |
| **Sections Breakdown** | 24 sections: 14 `pedestrian`, 10 `transit` | N/A | Map `pedestrian` -> `WALK` (`transitLeg: false`) |
| **Turn-by-Turn Actions** | 87 walking actions (`depart`, `turn`, etc.) | Text summaries | Decode `MOTActionDTO` into OTPKit `Step` array |
| **Geometry Encoding** | HERE Flexible Polyline v1 (`BG4...`) | Standard Polyline / Coordinates | Decode HERE v1 -> Convert to Google Encoded Polyline (E5) |
| **Decoded Vertices** | Exactly 1,724 vertices across 24 polylines | N/A | Verified via `MOTFlexiblePolylineTests` |
| **Real-time Status** | `isRealTime: false` across captured plan | Estimated | Truthfully display schedule; do not assert live GPS |
| **Timestamps** | Wall-clock Israel (`2026-10-18T09:32:00`) | Mixed | Parse with `MOTDateParser` (`Asia/Jerusalem`) |

---

## 2. Geometry Details: HERE Flexible Polyline v1
The MOT route planning API returns polylines formatted with HERE Flexible Polyline v1:
- Header specifies precision: 6 decimals for walking segments, 7 decimals for transit segments.
- Signed varint encoding with delta differences between successive coordinate vertices.
- `HEREFlexiblePolylineDecoder` safely decodes these into `[CLLocationCoordinate2D]`.
- `GooglePolylineEncoder` then encodes them into standard Google 5-decimal encoded polylines (E5) required by OTPKit.
- Total decoded vertices across all 24 sections in the verified capture: **1,724 vertices**.
