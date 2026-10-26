//
//  IsraelSelectedRouteSession.swift
//  IsraelMOT
//
//  Authoritative session manager maintaining state and real-time vehicle feeds
//  for a selected Israeli route.
//

import Foundation
import Combine
import CoreLocation
import OBAKitCore

@MainActor
public final class IsraelSelectedRouteSession: ObservableObject {
    public let route: Route
    public let stopsForRoute: StopsForRoute?

    @Published public private(set) var vehicles: [AmbientLiveVehicle] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var lastError: Error?

    private let apiService: RESTAPIService?
    private var refreshTask: Task<Void, Never>?
    private var isAutoRefreshRunning: Bool = false

    public init(
        route: Route,
        stopsForRoute: StopsForRoute? = nil,
        apiService: RESTAPIService? = nil
    ) {
        self.route = route
        self.stopsForRoute = stopsForRoute
        self.apiService = apiService
    }

    deinit {
        refreshTask?.cancel()
    }

    /// Triggers a fresh load of live vehicles for the selected route.
    public func refreshVehicles() async {
        guard let apiService = apiService,
              let stops = stopsForRoute?.stops, !stops.isEmpty else {
            return
        }

        refreshTask?.cancel()
        isLoading = true

        let task = Task { [weak self] () -> [AmbientLiveVehicle]? in
            guard let self = self else { return nil }
            return await IsraelRouteVehicleFeed.shared.fetchVehicles(
                routeID: self.route.id,
                routeShortName: self.route.shortName,
                stops: stops,
                apiService: apiService
            )
        }
        refreshTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let result = await task.value, !Task.isCancelled {
                self.vehicles = result
                self.lastUpdated = Date()
                self.isLoading = false
            }
        }
    }

    /// Starts a recurring periodic refresh (every 20 seconds) while the route is active on screen.
    public func startPeriodicRefresh() {
        guard !isAutoRefreshRunning else { return }
        isAutoRefreshRunning = true

        Task { @MainActor [weak self] in
            while let self = self, self.isAutoRefreshRunning {
                await self.refreshVehicles()
                try? await Task.sleep(nanoseconds: 20_000_000_000) // 20s
            }
        }
    }

    /// Stops periodic background refresh when the user navigates away from the route.
    public func stopPeriodicRefresh() {
        isAutoRefreshRunning = false
        refreshTask?.cancel()
        refreshTask = nil
    }
}
