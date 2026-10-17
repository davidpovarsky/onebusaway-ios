# Live Native API Verification Report

## Overview
This document records verified live HTTP interactions with the Ministry of Transport (MOT) APIs (`api.bus.gov.il`), demonstrating that both trip planning (`RoutePlanning/GetRoutes`) and scheduler predictions (`Routes/GetNextStopTimesAndLocation`) function natively without a browser session or web scraping when using the confirmed request contract.

---

## 1. Test Environments & Results Matrix

| Environment | OS / Runtime | HTTP Stack | Date (UTC) | Endpoint | HTTP Status | `success` | Route Alternatives / Records | Response Duration | Response Bytes |
|---|---|---|---|---|---|---|---|---|---|
| **iPad Test (User)** | iOS / iPadOS | Scriptable (Native NSURLSession) | 2026-10-17 19:45 | `POST /RoutePlanning/GetRoutes` | **200 OK** | `true` | 6 routes (24 sections) | 2,810 ms | ~166 KB |
| **Linux Runner** | Ubuntu 24.04 LTS | Python 3 `urllib` (OpenSSL) | 2026-10-17 20:30 | `POST /RoutePlanning/GetRoutes` | **200 OK** | `true` | 6 routes (24 sections) | 2,941 ms | 166,231 B |
| **Windows Native Swift** | Windows 11 / Swift 6.3.3 | Foundation `URLSession` | 2026-10-17 21:25 | `POST /RoutePlanning/GetRoutes` | **200 OK** | `true` | 6 routes (24 sections) | 3,183 ms | 166,235 B |
| **Windows Native Swift** | Windows 11 / Swift 6.3.3 | Foundation `URLSession` | 2026-10-17 21:25 | `POST /Routes/GetNextStopTimesAndLocation` | **200 OK** | `true` | 81 stopTimes (Stop 5997) | 243 ms | 19,700 B |
| **Linux Runner** | Ubuntu 24.04 LTS | Python 3 `urllib` (OpenSSL) | 2026-10-17 20:35 | `POST /Routes/GetNextStopTimesAndLocation` | **200 OK** | `true` | Dictionary response (`data.5997`) | ~320 ms | ~19 KB |

---

## 2. Header Policy Breakdown

A header isolation analysis confirmed that requests are rejected with HTTP 403 by the Volt-ADC edge only when mandatory origin profiles are missing:

| Headers Supplied | Result | Notes |
|---|---|---|
| `Content-Type: application/json` only | **HTTP 403** | Rejected by gateway policy |
| + `Origin: https://route.bus.gov.il` + `Referer: https://route.bus.gov.il/` | **HTTP 200** | Full JSON with 6 route alternatives |
| Standard App User-Agent (No fake Chrome UA) | **HTTP 200** | Proves browser spoofing is not required |
| Scheduler endpoint with `Origin: https://bus.gov.il` | **HTTP 200** | Full JSON with stop times and real-time predictions |

---

## 3. Truthful Data Mapping & Real-Time Status

1. **Route Planning Timestamps**:
   - Dates returned by `GetRoutes` (e.g. `2026-10-18T09:32:00`) are local Israel wall-clock time (`Asia/Jerusalem`) without timezone offsets.
   - Parsed strictly via `MOTDateParser` taking into account DST.
2. **Real-Time Predictions**:
   - `isRealTime: false` is accurately surfaced as static schedule.
   - `isRealTime: true` with vehicle coordinates is surfaced as live predicted arrival.
   - Placeholder default time offsets (`now + 600s`) have been completely removed.
