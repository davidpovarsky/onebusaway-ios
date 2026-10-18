# Bus Nearby Integration Contract & Plugin Architecture Spec

**Status:** Draft / Integration Preparation  
**Provider Identifier:** `bus-nearby`  
**Current State:** Future Placeholder (`isAvailable = false`)  
**Strict Policy:** No hypothetical API endpoints or unverified contracts are implemented in code.

---

## 1. Architectural Boundary

In the OneBusAway Israel architecture, there is a strict separation between two planes:

1. **Shared Geography & Stop Catalog Plane:**
   - Handled locally by `IsraelStopCatalogRepository` backed by `IsraelStopCatalog.sqlite`.
   - Provides nationwide station coordinates, Hebrew/English/Arabic station names, platform codes, and spatial R-Tree indexing.
   - Any new provider (including Bus Nearby) does **not** need to provide an entire national map/stop catalog; stations are resolved locally on the device with zero network traffic during pan/zoom.

2. **Dynamic Telemetry & Routing Plane:**
   - Handled by provider-specific adapters conforming to domain protocols.
   - Providers supply: real-time arrival predictions (ETA), service alerts, route shapes/schedules, and origin-to-destination trip planning.

```mermaid
flowchart TD
    UI[OneBusAway Map & UI] --> CoreRouter[Transit Provider Router]
    
    subgraph Shared Local Geography
        Catalog[IsraelStopCatalogRepository\nSQLite R-Tree & 35,387 GTFS Stops]
    end
    
    subgraph Provider Adapters
        MOT[Israel MOT Adapter\nisrael-mot]
        BN[Bus Nearby Adapter\nbus-nearby (Future)]
    end
    
    CoreRouter -->|Viewport Map Pins| Catalog
    CoreRouter -->|Dynamic Live Telemetry| MOT
    CoreRouter -.->|Dynamic Live Telemetry (When Ready)| BN
```

---

## 2. Required Plugin Protocols for Bus Nearby

When Bus Nearby contracts and API access are officially researched and verified, the integration requires implementing the following domain protocols in an isolated module (e.g. `IsraelBusNearby/`):

### 2.1 Identity Crosswalk (`BusNearbyIdentityMapper`)
- Translates between Bus Nearby station/route keys and the official GTFS `stop_code` / `stop_id`.
- Example contract:
  ```swift
  public protocol BusNearbyIdentityMapping {
      func resolveStopCode(fromProviderKey key: String) -> MOTStopCode?
      func providerKey(forStopCode code: MOTStopCode) -> String?
  }
  ```

### 2.2 Live Predictions Provider (`BusNearbyPredictionsProvider`)
- Provides live countdown and arrivals for a selected stop code.
- Contract:
  ```swift
  public protocol BusNearbyPredictionsProvider: Sendable {
      func fetchArrivals(for stopCode: MOTStopCode) async throws -> [TransitArrival]
  }
  ```

### 2.3 Trip Planning Provider (`BusNearbyTripPlanningProvider`)
- Implements door-to-door itinerary planning conforming to `OTPKit.APIService` or a domain routing protocol.
- Contract:
  ```swift
  public protocol BusNearbyRoutingProvider: Sendable {
      func calculateRoute(from origin: CLLocationCoordinate2D,
                          to destination: CLLocationCoordinate2D,
                          arriveBy: Bool,
                          targetTime: Date,
                          options: TransitRouteOptions) async throws -> [TransitItinerary]
  }
  ```

---

## 3. Registration in `TransitProviderRegistry`

Once the adapter is implemented and verified with tests:
1. Construct `TransitProviderDescriptor`:
   ```swift
   let busNearbyDescriptor = TransitProviderDescriptor(
       id: .busNearby,
       displayName: "Bus Nearby",
       localizedDescription: "נתוני זמן אמת ומסלולים מספק Bus Nearby",
       dataSourceAttribution: "Bus Nearby Live API",
       isAvailable: true, // Flip to true upon verification
       isExperimental: false,
       capabilities: verifiedCapabilities,
       statusMessage: "פעיל"
   )
   TransitProviderRegistry.shared.register(descriptor: busNearbyDescriptor)
   ```
2. Enable user selection in `TransitProviderSelectionStore`.
3. Ensure that switching between providers cleanly invalidates transient ETA caches without touching bookmarks or the local stop catalog.

---

## 4. Acceptance Criteria for Future Activation

1. **Independent Verification:** Endpoints and rate limits must be documented and tested with real fixtures before writing code.
2. **Zero Upstream Regression:** Core OBA classes must not be modified to accommodate Bus Nearby; integration must use the established `TransitProvider` seam.
3. **Graceful Fallback:** If Bus Nearby is unreachable or unconfigured, the UI must report explicit capability degradation without falling back silently to MOT data under a false label.
