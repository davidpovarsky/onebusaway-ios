# Israel MOT API Reliability, WAF Analysis & Resilience Strategy

## 1. Overview

Integrating with public sector transit APIs in Israel requires understanding both live operational capabilities and defensive security infrastructure. This document provides a transparent engineering analysis of the MOT API (`api.bus.gov.il`), its security controls, and our reliability policies.

---

## 2. API Endpoint Operational Matrix

| Endpoint Group | Method | Endpoint Path | Live Operational Status | Security / WAF Posture |
| :--- | :---: | :--- | :---: | :--- |
| **Stop Data** | `GET` | `/prod/scheduler-prod/api/he/StopData/GetStopFullData` | **Operational** | Open, standard CORS/JSON |
| **Nearby Stops** | `GET` | `/prod/scheduler-prod/api/he/StopData/GetCloseToLocation` | **Operational** | Open, standard CORS/JSON |
| **Route Data** | `GET` | `/prod/scheduler-prod/api/he/RouteData/GetRouteFullData` | **Operational** | Open, standard CORS/JSON |
| **Route Stops** | `GET` | `/prod/scheduler-prod/api/he/RouteData/GetRouteStops` | **Operational** | Open, standard CORS/JSON |
| **Autocomplete** | `GET` | `/prod/route-planner-prod/api/he/AutoComplete/SearchLocations` | **Operational** | Open, standard CORS/JSON |
| **Route Planning** | `POST` | `/prod/route-planner-prod/api/he/RoutePlanning/GetRoutes` | **WAF Blocked** | Protected by F5 Volt ADC WAF (HTTP 403) |

---

## 3. F5 Distributed Cloud (Volt ADC) WAF Analysis

### 3.1 Observed Behavior
When querying `POST https://api.bus.gov.il/prod/route-planner-prod/api/he/RoutePlanning/GetRoutes`, the server returns:
```http
HTTP/1.1 403 Forbidden
Content-Type: text/html
Connection: keep-alive

<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>Your support ID is: 1234567890abcdef</center>
</body>
</html>
```

### 3.2 Root Cause Analysis
1. **Device Fingerprinting**: F5 Volt ADC inspects incoming HTTP connections for browser-like TLS Client Hello cipher suites, HTTP/2 SETTINGS frames, header order, and JavaScript challenge execution.
2. **Automated Request Classification**: Native client requests (`URLSession`, `cURL`, Python `requests`, Node.js `fetch`) lacking browser execution contexts are classified as automated scripts and rejected at the edge.

### 3.3 Engineering Posture & Non-Circumvention
In strict compliance with security standards and project requirements:
- **No Spoofing**: We do not forge browser signatures, inject headless Chrome runtimes, or attempt to bypass WAF challenges.
- **Truthful Error Surfacing**: `MOTHTTPClient` parses the HTML error, extracts the `support ID`, and raises `MOTHTTPError.wafBlocked(supportID:)`.
- **User Experience**: The UI displays `MOTCapabilityNoticeView` in Hebrew, explaining that direct in-app route planning is temporarily restricted by the MOT firewall, with clear guidance.
- **Test Mode**: In development and automated test environments, `MOTTripPlanningAPIService` supports fixture-based playback using captured OpenAPI response fixtures.

---

## 4. Rate Limiting, Backoff & Caching

### 4.1 Exponential Backoff & Jitter (`MOTBackoff`)
To protect government infrastructure and prevent cascading retries:
- **Base Delay**: 0.5 seconds.
- **Multiplier**: 2.0.
- **Decorrelated Jitter**: Full random uniform distribution `[0, min(maxDelay, base * 2^attempt)]`.
- **Maximum Delay**: 5.0 seconds.
- **Max Retry Attempts**: 3 attempts. Only transient errors (HTTP 429, 503, network timeouts) are retried. Non-transient errors (HTTP 400, 403, 404) fail immediately.

### 4.2 In-Memory TTL Caching (`MOTCache`)
Static and slowly-changing data is cached to minimize API queries:
- **Stop Metadata (`GetStopFullData`)**: Cached with 24-hour TTL.
- **Route Line Info (`GetRouteFullData`)**: Cached with 24-hour TTL.
- **Route Stop Sequences (`GetRouteStops`)**: Cached with 12-hour TTL.
- **Real-Time Arrivals**: Cached with 15-second TTL to avoid duplicate bursts while refreshing screens.
