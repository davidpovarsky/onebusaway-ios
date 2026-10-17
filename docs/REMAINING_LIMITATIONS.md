# Remaining Limitations & API Terms Status

## 1. Terms of Service & Authorization Status
- **Current Operational Status**: Technical compatibility is verified. Native Swift `URLSession` calls with `Origin: https://route.bus.gov.il` and `Origin: https://bus.gov.il` successfully return HTTP 200 with full routing and scheduler data.
- **Production Distribution & Terms**: The MOT endpoints (`api.bus.gov.il`) do not currently have a publicly documented commercial API key system. Use in a widely distributed public App Store release requires formal agreement with the Ministry of Transport or adherence to Gov.il Open Data licensing guidelines.
- **Privacy & Telemetry**: No personal coordinates, device identifiers, or session tokens are stored, transmitted to third parties, or logged in public telemetry.

---

## 2. API Capabilities & Fallback Behavior

| Capability | Current State | Fallback / Limitation Handling |
|---|---|---|
| **Trip Planning** | Operational (HTTP 200) | Full options payload; 6 alternatives returned; decoded into OTPKit `Itinerary` objects. |
| **Real-Time GPS Predictions** | Operational | Uses `Routes/GetNextStopTimesAndLocation`. When no active bus is tracked, returns static schedule with `isRealTime: false`. |
| **Arrival Placeholders** | Eliminated | Artificial `now + 10 min` placeholder removed. If no departure data exists, no fake arrival is shown. |
| **Polyline Formats** | Fully Handled | HERE Flexible Polyline v1 decoded dynamically and converted to Google E5 polyline for MapKit/OTPKit. |
| **Intermediate Stops** | Partially Provided | Station data decoded when present in transit sections; stops without intermediate lists display direct line segments. |
| **Station Schedule Refresh** | Bounded | `RefreshStopTimesAtStop` may encounter 503; system gracefully relies on `GetNextStopTimesAndLocation` per serving line. |
| **Accessibility (Wheelchair)** | Conditional | Surfaces `isAccessible` from route options and station metadata when provided; never assumes accessibility without explicit server flag. |
