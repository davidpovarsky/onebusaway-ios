# Upstream Non-Regression & Mergeability Report

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Ancestor SHA:** `eeeae021d813fa6d3e1748cabf7b73d3079edaa3`  
**Upstream Remote:** `https://github.com/OneBusAway/onebusaway-ios.git`  
**Date:** 2026-10-27  

---

## 1. Upstream Seam & Isolation Audit

A core requirement of this extraction is that non-Israel transit regions (such as Puget Sound / Seattle, Tampa, Washington D.C., San Diego, York) must continue running exact upstream behavior with zero performance penalty, zero semantic distortion of headsigns, and zero routing through regional adapters.

### A. Departure and Stop Cards Presentation
- In upstream files (`DepartureRowView.swift`, `TripCardView.swift`, `GroupedListView.swift`), Israeli direction splitting was previously executed globally or omitted inconsistently.
- In this branch, every presentation point is strictly guarded:
  ```swift
  if IsraelProviderBootstrap.isIsraelContext(routeID: departure.routeID, stopID: departure.stopID) {
      IsraelRouteDirectionTitleView(...)
  } else {
      Text(departure.tripHeadsign ?? departure.routeShortName)
          .font(.headline.weight(.heavy))
          .lineLimit(2)
  }
  ```
- **Proof:** In Seattle (e.g. King County Metro Route 44 to "UW Medical Center - Ballard"), the headsign contains hyphenation. In non-Israel regions, `isIsraelContext` evaluates to `false`, and the original `Text(departure.tripHeadsign ?? ...)` is rendered verbatim.

### B. Route Stops Presentation
- In `RouteStopsSheetView.swift`:
  ```swift
  if IsraelProviderBootstrap.isIsraelContext(routeID: stopsForRoute.route?.id) {
      IsraelRouteStopsTimelineView(...)
  } else {
      List(rows) { ... }
  }
  ```
- Non-Israel regions retain the exact upstream `List(rows)` with identical row buttons, styling, and navigation.

### C. Widget Data Path Isolation
- In `WidgetDataProvider.swift`:
  ```swift
  if region.regionIdentifier == 972 {
      departures = await IsraelWidgetArrivalsClient.shared.loadDepartures(...)
  } else {
      let service = RESTAPIService.standalone(region: region, ...)
      departures = await BookmarkArrivalsLoader(minutesAfter: 90).departuresByBookmark(for: bookmarks, using: service)
  }
  ```
- All non-972 regions execute the exact original `RESTAPIService.standalone` pipeline with `URLSession.shared`. No regional client or data loader is instantiated.

### D. Networking & Application DataLoader
- In `Application.swift`:
  ```swift
  open override func dataLoader(for region: Region) -> URLDataLoader {
      let fallback = super.dataLoader(for: region)
      return IsraelAppServices.shared.dataLoader(for: region, fallbackLoader: fallback)
  }
  ```
- For any region whose `regionIdentifier != 972`, `IsraelProviderBootstrap.dataLoader` immediately returns `fallbackLoader` without wrapping or intercepting requests.

---

## 2. Upstream Mergeability & `git merge-tree` Analysis

A three-way merge analysis was executed against the common ancestor (`eeeae021d813fa6d3e1748cabf7b73d3079edaa3`) and `upstream/main`:

```shell
$ git merge-tree $(git merge-base upstream/main HEAD) upstream/main HEAD
```

### Analysis Results:
1. **Core Domain Models (`OBAKitCore`):**
   - Clean additions in `ScheduleForRoute.swift` and `TripStopTime.swift` improve optional decoding resilience across all regions without breaking any existing decoding tests.
2. **Upstream Files:**
   - Modified files are limited to clean, guarded injection hooks.
   - All Israeli logic has been moved to `IsraelMOT/` and `OBAKit/Israel/`.
3. **Target Definitions:**
   - `OBAKit/project.yml` and `OBAWidget/project.yml` include `IsraelMOT` as a source group without circular dependencies or duplicate symbols.
4. **Merge Readiness:**
   - The branch is clean, modular, and structurally ready for upstream PR separation if requested by the repository owner.
