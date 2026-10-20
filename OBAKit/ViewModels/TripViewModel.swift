//
//  TripViewModel.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import Combine
import CoreLocation
import OBAKitCore

/// Shared ViewModel for the trip map/details screen.
///
/// Consumed by `TripViewController` (UIKit, via Combine `sink`) and by
/// future `TripSheetView` (SwiftUI, via `@StateObject`).
/// Contains no UIKit or MapKit imports.
@MainActor
class TripViewModel: ObservableObject {

    // MARK: - Published State

    /// The trip convertible (ArrivalDeparture or Trip) being displayed.
    @Published private(set) var tripConvertible: TripConvertible

    /// Full trip details including stop sequence and vehicle status.
    @Published private(set) var tripDetails: TripDetails?

    /// The live arrival at `destinationStopID`, which the trip panel's progress
    /// header counts down to. `nil` when no shared destination was named, until
    /// it first loads, and after a refresh that failed to load it.
    @Published private(set) var destinationArrivalDeparture: ArrivalDeparture?

    /// Decoded route shape coordinates; nil until first loaded. UI layer converts to MKPolyline.
    @Published private(set) var routePolylineCoordinates: [CLLocationCoordinate2D]?

    /// `true` while any data request is in-flight.
    @Published private(set) var isLoading = false

    /// Non-nil when a network error occurred.
    @Published private(set) var operationError: Error?

    // MARK: - Configuration

    /// The stop a shared trip link named as the sharer's exit, or `nil` for
    /// every other way into the trip screen. See #449.
    let destinationStopID: StopID?

    /// Set by the UI layer to gate programmatic auto-refreshes.
    /// e.g. `viewModel.shouldSkipProgrammaticRefresh = { UIAccessibility.isVoiceOverRunning }`
    var shouldSkipProgrammaticRefresh: (() -> Bool)?

    // MARK: - Private

    private let application: Application
    private static let refreshInterval: TimeInterval = 30.0
    private var refreshTimer: Timer?

    /// The in-flight load started by `loadData()`.
    ///
    /// Held so a newer load or teardown can cancel it, and so tests have a
    /// completion to await instead of polling for its side effects.
    private(set) var loadDataTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameter destinationStopID: Where the sharer said they will step off,
    ///   when the trip was opened from a shared link that named one. See #449.
    init(application: Application, tripConvertible: TripConvertible, destinationStopID: StopID? = nil) {
        self.application = application
        self.tripConvertible = tripConvertible
        self.destinationStopID = destinationStopID
    }

    isolated deinit {
        refreshTimer?.invalidate()
        loadDataTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Call from `viewWillAppear`.
    func start() {
        startRefreshTimer()
        loadData()
    }

    /// Call from `viewWillDisappear`.
    func deactivate() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        loadDataTask?.cancel()
        loadDataTask = nil
        isLoading = false
    }

    // MARK: - Refresh

    func refresh() {
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        loadDataTask?.cancel()
        loadDataTask = Task { [weak self] in
            guard let self else { return }
            isLoading = true
            do {
                // Trip details is the essential payload (stop sequence & timeline).
                async let detailsTask = fetchTripDetails()
                // Polyline shape and refreshed arrival/departure are resiliently loaded.
                async let polylineTask = fetchMapPolylineSilently()
                async let convertibleTask = fetchTripConvertibleSilently()

                // Publish essential trip details as soon as available, without waiting for optional requests
                if let newDetails = try await detailsTask {
                    guard !Task.isCancelled else { return }
                    tripDetails = newDetails
                    operationError = nil
                    await loadDestinationArrival()
                }

                let newPolyline = await polylineTask
                let newConvertible = await convertibleTask

                // Cancellation is cooperative: a load cancelled by a newer one or
                // by `deactivate()` can still get its responses back. Applying
                // them could overwrite the newer load's trip.
                guard !Task.isCancelled else { return }

                if let newPolyline { routePolylineCoordinates = newPolyline }
                if let newConvertible { tripConvertible = newConvertible }
                operationError = nil
            } catch {
                // A cancelled load (e.g. dismissing a context menu preview)
                // should never surface an error to the user. It leaves
                // `isLoading` to the load that replaced it, or to `deactivate()`.
                if Task.isCancelled {
                    return
                }
                // URLSession can also report NSURLErrorCancelled without the
                // enclosing Task being cancelled (e.g. a lower layer cancelled
                // the request). Swallow the error, but clear the spinner — the
                // view is still alive and waiting.
                if error.isCancellation {
                    isLoading = false
                    return
                }
                operationError = error
            }
            // Same for a load cancelled while it waited for the destination's
            // arrival: the load that replaced it may still be running.
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }

    private func fetchTripConvertible() async throws -> TripConvertible? {
        guard let apiService = application.apiService,
              let arrivalDeparture = tripConvertible.arrivalDeparture else { return nil }

        let newArrDep = try await apiService.getTripArrivalDepartureAtStop(
            stopID: arrivalDeparture.stopID,
            tripID: arrivalDeparture.tripID,
            serviceDate: arrivalDeparture.serviceDate,
            vehicleID: arrivalDeparture.vehicleID,
            stopSequence: arrivalDeparture.stopSequence
        ).entry

        return TripConvertible(arrivalDeparture: newArrDep)
    }

    private func fetchTripConvertibleSilently() async -> TripConvertible? {
        do {
            return try await fetchTripConvertible()
        } catch {
            Logger.warn("TripViewModel: optional convertible refresh failed: \(error)")
            return nil
        }
    }

    private func fetchTripDetails() async throws -> TripDetails? {
        guard let apiService = application.apiService else { return nil }

        return try await apiService.getTrip(
            tripID: tripConvertible.trip.id,
            vehicleID: tripConvertible.vehicleID,
            serviceDate: tripConvertible.serviceDate
        ).entry
    }

    private func fetchMapPolyline() async throws -> [CLLocationCoordinate2D]? {
        guard let apiService = application.apiService,
              routePolylineCoordinates == nil else { return nil }

        // No shape ID means the agency doesn't publish shape data for this trip.
        // Degrade quietly: the trip map simply draws no route line.
        guard let shapeID = tripConvertible.trip.shapeID, !shapeID.isEmpty else { return nil }

        let response = try await apiService.getShape(id: shapeID)
        return Polyline(encodedPolyline: response.entry.points).coordinates
    }

    private func fetchMapPolylineSilently() async -> [CLLocationCoordinate2D]? {
        do {
            return try await fetchMapPolyline()
        } catch {
            Logger.warn("TripViewModel: optional polyline fetch failed: \(error)")
            return nil
        }
    }

    /// Loads the live arrival at the shared destination, for the progress
    /// header's countdown.
    ///
    /// A failure is logged and clears the countdown rather than leave an old
    /// prediction on screen. It does not set `operationError`: the trip itself
    /// loaded, and an error alert over one supplementary time would be out of
    /// proportion.
    private func loadDestinationArrival() async {
        guard let destinationStopID,
              let apiService = application.apiService,
              let arrivalDeparture = tripConvertible.arrivalDeparture,
              let tripDetails else { return }

        guard let destinationIndex = TripStopListModel.riderStops(
            in: tripDetails.stopTimes,
            arrivalDeparture: arrivalDeparture,
            sharedDestinationStopID: destinationStopID
        ).destinationIndex else {
            destinationArrivalDeparture = nil
            return
        }

        do {
            let arrival = try await apiService.getTripArrivalDepartureAtStop(
                stopID: destinationStopID,
                tripID: arrivalDeparture.tripID,
                serviceDate: arrivalDeparture.serviceDate,
                vehicleID: arrivalDeparture.vehicleID,
                stopSequence: destinationIndex
            ).entry
            guard !Task.isCancelled else { return }
            destinationArrivalDeparture = arrival
        } catch {
            if Task.isCancelled || error.isCancellation { return }
            Logger.error("Failed to load the arrival at shared destination \(destinationStopID) on trip \(arrivalDeparture.tripID): \(error)")
            destinationArrivalDeparture = nil
        }
    }

    // MARK: - Refresh Timer

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: Self.refreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !(self.shouldSkipProgrammaticRefresh?() ?? false) else { return }
                self.loadData()
            }
        }
    }
}
