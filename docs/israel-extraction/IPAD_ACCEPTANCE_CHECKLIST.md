# iPad Physical Hardware Acceptance Checklist

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Date:** 2026-10-27  
**Overall Device Verification Status:** **NOT VERIFIED ON DEVICE (Hardware not connected in agent environment)**

This checklist must be physically executed on the target iPad running the TestFlight build.

---

## Acceptance Matrix

| ID | Required Behavior on iPad | Evidence Needed | Automated Status | Physical iPad Status |
|---|---|---|---|---|
| **MAP-01** | Routes and vehicles remain visible when panning/zooming in the same area (no blanking/flicker) | Video/screenshots; overlay/annotation retention count | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **MAP-02** | No deletion of active snapshot due to empty API responses or new viewport requests | Mock tests & logs | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **ROUTE-01** | Selecting Route 71 displays route line and direction-matched live vehicles | Screenshot & Route/Trip IDs | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **ROUTE-02** | Tapping bus marker opens human card and canonical `TripPage` | Screenshot & navigation stack trace | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **ROUTE-03** | Route 71 screen displays graphic station spine; tapping stop opens Stop Details, Back retains route | Screenshot & UI flow | Verified in UI tests | **NOT VERIFIED ON DEVICE** |
| **STOP-01** | Station departure cards in Route & Time mode show bold destination and separate origin line | Screenshots in both modes | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **SEARCH-01** | Search for `31`, `71`, `קו 86` returns nationwide results; selection works | Screenshots & Route IDs | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **WIDGET-01** | Saved stops widget works after cold start; authentic arrivals or missing state (never blank) | Screenshot of small/medium widget + logs | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **ACT-01** | New Live Activity appears on Lock Screen with non-empty initial text | Screenshot & `Activity.request` log | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **ACT-02** | Background updates occur when iOS grants runtime; ending activity stops GPS | Time logs & Activity ID | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **DATA-01** | Schedule times are authentic (no fake `23:59` or `1181min`); missing data explicitly flagged | Line 71/86 inspection | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
| **REG-01** | Non-972 regions completely unaffected by Israel customizations | Mock/smoke test in Puget Sound | Verified in unit tests | **NOT VERIFIED ON DEVICE** |
