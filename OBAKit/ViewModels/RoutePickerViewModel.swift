//
//  RoutePickerViewModel.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Combine
import CoreLocation
import Foundation
import OBAKitCore

/// Shared ViewModel for `RoutePickerViewController`.
///
/// Owns route loading (cache-first, API fallback), nationwide search filtering,
/// and load-error surfacing. The VC keeps `UISearchController` and `OBAListView` presentation.
@MainActor
final class RoutePickerViewModel: ObservableObject {

    /// Reasons `loadRoutes()` can fail short of a thrown network/decoding error.
    /// Conforms to `LocalizedError` so a SwiftUI consumer can read
    /// `errorDescription` without going through the typed enum.
    enum RoutePickerError: LocalizedError {
        case serviceUnavailable
        case locationUnavailable

        var errorDescription: String? {
            switch self {
            case .serviceUnavailable:
                return OBALoc(
                    "route_picker.error_no_service",
                    value: "Unable to connect to the transit service.",
                    comment: "Error when the API service is unavailable in the route picker."
                )
            case .locationUnavailable:
                return OBALoc(
                    "route_picker.error_no_location",
                    value: "Location unavailable. Please enable location services to find nearby routes.",
                    comment: "Error when location is unavailable in the route picker."
                )
            }
        }
    }

    // MARK: - Published State

    /// Routes matching the current search filter. Drives the list.
    @Published private(set) var filteredRoutes: [Route] = []

    /// `true` once `loadRoutes()` has resolved (success or failure).
    @Published private(set) var didFinishLoading: Bool = false

    /// `true` while an asynchronous nationwide route search is in flight.
    @Published private(set) var isSearching: Bool = false

    /// Error from the last `loadRoutes()` attempt, or `nil`. Kept as `Error` so a
    /// SwiftUI consumer can classify on type rather than parsing a flattened
    /// `String`. The VC reads `localizedDescription` for display.
    @Published private(set) var loadError: Error?

    // MARK: - Direct Reads (not observed)

    /// All routes available for selection, sorted alphabetically. VC reads to detect
    /// the "no routes found" empty state.
    private(set) var allRoutes: [Route] = []

    // MARK: - Private

    private let application: Application
    private var searchQuery: String = ""
    private var searchTask: Task<Void, Never>?
    private var queryCache: [String: [Route]] = [:]

    // MARK: - Init

    init(application: Application) {
        self.application = application
    }

    // MARK: - Load

    func loadRoutes() async {
        didFinishLoading = false
        loadError = nil

        // Primary: extract routes from stops already loaded by MapRegionManager.
        let cachedStops = application.mapRegionManager.stops
        if !cachedStops.isEmpty {
            applyRoutes(from: cachedStops)
            return
        }

        // Fallback: fetch nearby stops from the API.
        guard let apiService = application.apiService else {
            loadError = RoutePickerError.serviceUnavailable
            didFinishLoading = true
            return
        }

        guard let location = application.locationService.currentLocation else {
            loadError = RoutePickerError.locationUnavailable
            didFinishLoading = true
            return
        }

        do {
            let stops = try await apiService.getStops(coordinate: location.coordinate).list
            applyRoutes(from: stops)
        } catch {
            let nsError = error as NSError
            let isCancelled = Task.isCancelled
                || error is CancellationError
                || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)

            if isCancelled {
                return
            }
            Logger.error("Failed to load routes for picker: \(error)")
            loadError = error
            didFinishLoading = true
        }
    }

    // MARK: - Search

    /// Updates the search filter. Performs immediate local filtering on `allRoutes`
    /// for instant feedback, then triggers a debounced nationwide route search
    /// against the transit API.
    func updateSearch(_ query: String) {
        searchQuery = query
        recomputeLocalFilteredRoutes()

        let normalized = Self.normalizeQuery(query)
        if normalized.isEmpty {
            searchTask?.cancel()
            searchTask = nil
            isSearching = false
            return
        }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            // Debounce for 250ms
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self = self else { return }
            await self.performSearch(normalized)
        }
    }

    /// Directly awaitable search method for testing and explicit submission.
    func performSearchAndWait(_ query: String) async {
        searchQuery = query
        recomputeLocalFilteredRoutes()
        let normalized = Self.normalizeQuery(query)
        if normalized.isEmpty {
            filteredRoutes = allRoutes
            return
        }
        await performSearch(normalized)
    }

    private func performSearch(_ query: String) async {
        if let cached = queryCache[query] {
            applySearchResults(cached, for: query)
            isSearching = false
            return
        }

        guard let apiService = application.apiService else { return }

        isSearching = true
        defer {
            if !Task.isCancelled {
                isSearching = false
            }
        }

        let circularRegion = resolveSearchRegion()

        do {
            let response = try await apiService.getRoute(query: query, region: circularRegion)
            guard !Task.isCancelled else { return }
            let results = response.list
            queryCache[query] = results
            applySearchResults(results, for: query)
        } catch {
            guard !Task.isCancelled else { return }
            let nsError = error as NSError
            let isCancelled = error is CancellationError
                || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
            if isCancelled { return }

            Logger.error("RoutePickerViewModel: search error for '\(query)': \(error)")
            if filteredRoutes.isEmpty {
                loadError = error
            }
        }
    }

    private func resolveSearchRegion() -> CLCircularRegion {
        if let mapRect = application.mapRegionManager.lastVisibleMapRect {
            return CLCircularRegion(mapRect: mapRect)
        } else if let serviceRect = application.regionsService.currentRegion?.serviceRect {
            return CLCircularRegion(mapRect: serviceRect)
        } else if let currentRegion = application.regionsService.currentRegion {
            return CLCircularRegion(
                center: currentRegion.centerCoordinate,
                radius: 40000.0,
                identifier: "DefaultRegionalRadius"
            )
        } else if let location = application.locationService.currentLocation {
            return CLCircularRegion(
                center: location.coordinate,
                radius: 40000.0,
                identifier: "DefaultLocationRadius"
            )
        } else {
            return CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: 31.78, longitude: 35.21),
                radius: 50000.0,
                identifier: "FallbackIsraelRadius"
            )
        }
    }

    private func applySearchResults(_ results: [Route], for query: String) {
        var seenIDs = Set<RouteID>()
        var combined: [Route] = []

        // Local matches that start with query or exact match
        for r in filteredRoutes where seenIDs.insert(r.id).inserted {
            combined.append(r)
        }

        // Add network results
        for r in results where seenIDs.insert(r.id).inserted {
            combined.append(r)
        }

        // Rank results: exact match first, prefix second, then localized compare
        if application.currentRegion?.regionIdentifier == IsraelProviderBootstrap.israelRegionIdentifier {
            filteredRoutes = IsraelRouteSearchService.shared.rankRoutes(combined, for: query)
        } else {
            let target = query.lowercased()
            filteredRoutes = combined.sorted { first, second in
                let firstExact = first.shortName.lowercased() == target
                let secondExact = second.shortName.lowercased() == target
                if firstExact != secondExact { return firstExact }

                let firstPrefix = first.shortName.lowercased().hasPrefix(target)
                let secondPrefix = second.shortName.lowercased().hasPrefix(target)
                if firstPrefix != secondPrefix { return firstPrefix }

                return first.shortName.localizedStandardCompare(second.shortName) == .orderedAscending
            }
        }
        didFinishLoading = true
    }

    // MARK: - Normalization

    static func normalizeQuery(_ raw: String) -> String {
        IsraelRouteQueryNormalizer.normalize(raw)
    }

    // MARK: - Private

    /// Extracts unique routes from stops, sorts, and refreshes the filtered list.
    private func applyRoutes(from stops: [Stop]) {
        var seen = Set<RouteID>()
        var uniqueRoutes = [Route]()

        for stop in stops {
            for route in stop.routes where seen.insert(route.id).inserted {
                uniqueRoutes.append(route)
            }
        }

        allRoutes = uniqueRoutes.localizedCaseInsensitiveSort()
        didFinishLoading = true
        recomputeLocalFilteredRoutes()
    }

    private func recomputeLocalFilteredRoutes() {
        if searchQuery.isEmpty {
            filteredRoutes = allRoutes
            return
        }
        let normalized = Self.normalizeQuery(searchQuery).lowercased()
        let query = searchQuery.lowercased()

        filteredRoutes = allRoutes.filter { route in
            let short = route.shortName.lowercased()
            let long = route.longName?.lowercased() ?? ""
            let agency = route.agency.name.lowercased()
            return short.contains(normalized) || short.contains(query)
                || long.contains(normalized) || long.contains(query)
                || agency.contains(normalized) || agency.contains(query)
        }
    }
}
