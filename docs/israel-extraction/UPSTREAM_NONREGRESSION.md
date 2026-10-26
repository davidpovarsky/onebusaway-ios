# Upstream Non-Regression & Mergeability Report

**Branch:** `fix/israel-extraction-and-repair-20261027`  
**Upstream Remote:** `https://github.com/OneBusAway/onebusaway-ios.git`  
**Origin Remote:** `https://github.com/davidpovarsky/onebusaway-ios.git`  
**Date:** 2026-10-27  

---

## 1. Upstream Seam & Isolation Audit

A core requirement of this extraction is that non-Israel transit regions (such as Puget Sound / Seattle, Tampa, Washington D.C., San Diego, York) must continue running exact upstream behavior with zero performance penalty, zero semantic distortion of headsigns, and zero routing through regional adapters.

### A. Departure and Stop Cards Presentation
- In upstream presentation files (`DepartureRowView.swift`, `TripCardView.swift`, `GroupedListView.swift`), Israeli direction splitting is strictly guarded:
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

A three-way merge analysis was executed against `origin/main` and `HEAD`:

### Raw Command and Output:
```powershell
$ git merge-tree origin/main HEAD
aff72d7429173ce19b87e227f42a54b71c3ee75b
100644 f312e324c281d2f8805f7deb07e982b2d0ee7687 2	AGENTS.md
100644 2170f177fb6badf2fcf0a4f8583afa349bae106e 3	AGENTS.md
100644 d8737263b648ccd823aa98e70e43a74078dec18f 2	docs/ai-team/TEAM.md
100644 306473f9c3527790aff5a2834d5d68ad4eca623d 3	docs/ai-team/TEAM.md

Auto-merging AGENTS.md
CONFLICT (add/add): Merge conflict in AGENTS.md
Auto-merging docs/ai-team/TEAM.md
CONFLICT (add/add): Merge conflict in docs/ai-team/TEAM.md
Exit code: 1
```

### Truthful Interpretation of Exit Code 1:
- `git merge-tree origin/main HEAD` exits with **code 1** (conflict).
- **Location of conflicts:** Exclusively in metadata/documentation files:
  - `AGENTS.md` (team operating instructions added on main vs branch)
  - `docs/ai-team/TEAM.md` (team contract added on main vs branch)
- **Zero code conflicts:** There are **zero conflicts** in application source files (`OBAKit`, `OBAKitCore`, `OBAWidget`, `IsraelMOT`).
- The branch is not merged to `main` (per strict instruction "אל תמזג ל־main"). If a merge to main were to be performed in the future by the owner, a simple trivial resolution of `AGENTS.md` and `docs/ai-team/TEAM.md` will be required.
