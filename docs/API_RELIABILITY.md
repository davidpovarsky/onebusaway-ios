# Israel MOT API Reliability, Security & Resilience Strategy

## 1. Overview

Integrating with public sector transit APIs in Israel (`api.bus.gov.il`) requires understanding both live operational capabilities and gateway policies. This document details the engineering analysis of the MOT API, header policies, and our resilience architecture.

---

## 2. API Endpoint Operational Matrix

| Endpoint Group | Method | Endpoint Path | Live Operational Status | Gateway Policy / Profile Requirements |
| :--- | :---: | :--- | :---: | :--- |
| **Stop Data** | `GET` | `/prod/mot-scheduler-prod/api/he/Stops/GetStopFullData` | **Operational** | Open, standard CORS/JSON |
| **Nearby Stops** | `GET` | `/prod/mot-scheduler-prod/api/he/Stops/GetStopsCloseToLocation` | **Operational** | Open, standard CORS/JSON |
| **Route Data** | `GET` | `/prod/mot-scheduler-prod/api/he/Routes/GetRouteFullData` | **Operational** | Open, standard CORS/JSON |
| **Route Stops** | `GET` | `/prod/mot-scheduler-prod/api/he/Routes/GetRouteStops` | **Operational** | Open, standard CORS/JSON |
| **Autocomplete** | `GET` | `/prod/route-planner-prod/api/he/AutoComplete/SearchLocations` | **Operational** | Open, standard CORS/JSON |
| **Route Planning** | `POST` | `/prod/route-planner-prod/api/he/RoutePlanning/GetRoutes` | **Operational** (HTTP 200) | Requires complete payload & `Origin: https://route.bus.gov.il` |
| **Stop Real-Time & Schedule** | `POST` | `/prod/mot-scheduler-prod/api/he/Routes/GetNextStopTimesAndLocation` | **Operational** (HTTP 200) | Requires `routeDesc`, `stopCodes` & `Origin: https://bus.gov.il` |

---

## 3. Gateway & Header Policy Analysis

### 3.1 Refutation of Blanket WAF POST Blocking
Previous assumptions held that POST requests were blocked by F5/Volt-ADC edge policies due to browser fingerprinting. Rigorous empirical verification across iPadOS, Linux, and Windows Native Swift disproved this:
- **Header Profile**: When `Origin: https://route.bus.gov.il` and `Referer: https://route.bus.gov.il/` are sent with the complete JSON payload, the server returns **HTTP 200 OK** in 2.8–3.1s with 6 route alternatives.
- **Scheduler Profile**: `Routes/GetNextStopTimesAndLocation` returns **HTTP 200 OK** in 240–320ms with timetable and SIRI tracking when called with `Origin: https://bus.gov.il`.
- **Browser Spoofing Not Needed**: Verified that standard Foundation `URLSession` user-agent strings succeed; fake Chrome UA strings are unnecessary.

### 3.2 Robust Error Classification in `MOTHTTPClient`
- **HTTP 403 (Policy Rejection)**: Distinguishes between F5 support ID pages and general authorization limits. Never blindly retried.
- **HTTP 429 / 503**: Bounded retry with exponential backoff and jitter, honoring `Retry-After`.
- **Cancellation**: `CancellationError` / `URLError.cancelled` immediately aborts without retry.

---

## 4. Rate Limiting, Backoff & Caching

### 4.1 Exponential Backoff & Jitter (`MOTBackoff`)
To protect government infrastructure and prevent cascading retries:
- **Base Delay**: 0.5 seconds.
- **Multiplier**: 2.0.
- **Decorrelated Jitter**: Full random uniform distribution `[0, min(maxDelay, base * 2^attempt)]`.
- **Maximum Delay**: 5.0 seconds.
- **Maximum Retries**: 2 for idempotent GET requests, 0 for non-idempotent or policy-blocked requests.

### 4.2 In-Memory TTL Cache (`MOTCache`)
- Caches stop metadata and route geometries for 1 hour.
- Real-time arrival requests are never cached beyond a 15-second debounce window.
