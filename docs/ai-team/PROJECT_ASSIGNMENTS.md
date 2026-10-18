# OneBusAway Israel — Team Assignments & Work Routing

**Asana Project:** [OneBusAway Israel (1219605677718919)](https://app.asana.com/0/1219605677718919/list)  
**Base Branch:** `feature/israel-local-catalog-smart-map-provider-architecture`  
**Setup PR:** https://github.com/davidpovarsky/onebusaway-ios/pull/2  
**Setup Task:** `1219611656748102`

---

## 1. Project Scope & Technical Boundaries
- Israel transit provider architecture, MOT adapters, local stop catalog, smart map, and route parity.
- Isolate MOT integration to `IsraelMOT` layer; preserve upstream OneBusAway seams and core contracts.
- Smart map viewport and zoom budget: Do not perform country-wide stop scanning during pan/zoom.

---

## 2. Active Open Tasks & Role Assignments

| Task / Area | Logical Lead | Reviewer / QA | Scope & Constraints |
|---|---|---|---|
| **[P0] CI Compilation Fix (`regionIdentifier`)** | נועם (noam) | תומר (tomer) + רוני (roni) | Fix `regionIdentifier` accessibility in `OnDemandProbeController.swift`; resolve CI run 39085550149. |
| **[P0] Arrive By / Depart At Time Formatting** | נועם (noam) | יעל (yael) + רוני (roni) | Fix UTC / local time DST offset in `MOTTripPlanningAPIService` and verify Route Parity. |
| **[P1] Smart Map Viewport & Zoom Budget** | נועם (noam) | מיה (maya) + רוני (roni) | Viewport queries with debounce, radius caps, LRU caching; no full country `GetMapStops` scan. |
| **[P1] MOT Stops-for-Route & Schedules** | נועם (noam) | יעל (yael) + רוני (roni) | Map MOT endpoints for route stops, directions, calendar service dates, and references. |
| **[P1] Route Search Decoupling** | נועם (noam) | מיה (maya) + רוני (roni) | Fix `SearchLines` query matching ('31 ירושלים'), isolate search state from previous selection. |
| **[P2] Provider Registry & Capability Menus** | איתן (eitan) | נועם (noam) + מיה (maya) | Provider selection settings, conditional menus based on provider capabilities. |
| **Truthful Verification & Physical iPad** | רוני (roni) | Owner | SideStore / physical iPad verification, live MOT API checks, real arrival times. |
| **Privacy, Location & Unsigned IPA** | דנה (dana) | רוני (roni) | Entitlement audit; suppress remote APNs registration in unsigned IPA builds. |

---

## 3. Approval Gates
- **Release Readiness:** Release gate tasks remain OPEN until verified on physical iPad via SideStore with green CI.
- **Physical Device:** Tasks with physical iPad runtime verification remain open until verified on hardware.
- **Asana Policy:** Autonomous updates and verified completion are authorized per `docs/ai-team/ASANA_POLICY.md`.
