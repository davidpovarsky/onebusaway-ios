//
//  IsraelLocalLiveActivityCoordinator.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import ActivityKit
import Foundation
import UIKit
import OBAKitCore

public struct IsraelTrackedActivityContext: Codable, Sendable {
    public let activityID: String
    public let stopID: String
    public let routeShortName: String
    public let routeHeadsign: String
    public let tripID: String
    public var lastDepartureTime: Int?
    public var lastUpdateTime: Date?

    public init(
        activityID: String,
        stopID: String,
        routeShortName: String,
        routeHeadsign: String,
        tripID: String,
        lastDepartureTime: Int? = nil,
        lastUpdateTime: Date? = nil
    ) {
        self.activityID = activityID
        self.stopID = stopID
        self.routeShortName = routeShortName
        self.routeHeadsign = routeHeadsign
        self.tripID = tripID
        self.lastDepartureTime = lastDepartureTime
        self.lastUpdateTime = lastUpdateTime
    }
}

@MainActor
public final class IsraelLocalLiveActivityCoordinator {
    public typealias APIServiceProvider = () -> RESTAPIService?

    private let apiServiceProvider: APIServiceProvider
    private let userDefaults: UserDefaults
    private let persistenceKey = "org.onebusaway.israel.live_activities.tracked"

    public private(set) var trackedContexts: [String: IsraelTrackedActivityContext] = [:]
    private var lifecycleTasks: [String: Task<Void, Never>] = [:]
    private var pollingTask: Task<Void, Never>?
    private var isForeground = true
    private var consecutiveErrors = 0

    public init(
        apiServiceProvider: @escaping APIServiceProvider,
        userDefaults: UserDefaults = .standard
    ) {
        self.apiServiceProvider = apiServiceProvider
        self.userDefaults = userDefaults

        loadPersistedContexts()
        setupLifecycleNotifications()
        reconcileRunningActivities()
    }

    deinit {
        pollingTask?.cancel()
        lifecycleTasks.values.forEach { $0.cancel() }
    }

    public func isTracking(activityID: String) -> Bool {
        trackedContexts[activityID] != nil || lifecycleTasks[activityID] != nil
    }

    public func track(activity: Activity<TripAttributes>, arrivalDepartures: [ArrivalDeparture]) {
        let staticData = activity.attributes.staticData
        let departure = arrivalDepartures.first(where: {
            !staticData.tripID.isEmpty && $0.tripID == staticData.tripID
        }) ?? arrivalDepartures.first

        let context = IsraelTrackedActivityContext(
            activityID: activity.id,
            stopID: staticData.stopID,
            routeShortName: staticData.routeShortName,
            routeHeadsign: staticData.routeHeadsign,
            tripID: staticData.tripID,
            lastDepartureTime: departure.map { Int($0.arrivalDepartureDate.timeIntervalSince1970) },
            lastUpdateTime: Date()
        )

        registerTrackedContext(context, for: activity)
    }

    public func track(activity: Activity<TripAttributes>, departure: ArrivalDeparture?) {
        let staticData = activity.attributes.staticData
        let context = IsraelTrackedActivityContext(
            activityID: activity.id,
            stopID: staticData.stopID,
            routeShortName: staticData.routeShortName,
            routeHeadsign: staticData.routeHeadsign,
            tripID: staticData.tripID.isEmpty ? (departure?.tripID ?? "") : staticData.tripID,
            lastDepartureTime: departure.map { Int($0.arrivalDepartureDate.timeIntervalSince1970) },
            lastUpdateTime: Date()
        )

        registerTrackedContext(context, for: activity)
    }

    public func observeLifecycle(of activity: Activity<TripAttributes>) {
        let activityID = activity.id
        guard lifecycleTasks[activityID] == nil else { return }

        lifecycleTasks[activityID] = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                switch state {
                case .dismissed, .ended:
                    await self?.untrackOnMain(activityID: activityID)
                    return
                case .active, .stale, .pending:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    public func reconcileRunningActivities() {
        let israelActivities = Activity<TripAttributes>.activities.filter {
            $0.attributes.staticData.regionID == 972
        }

        let liveIDs = Set(israelActivities.map(\.id))
        let deadIDs = trackedContexts.keys.filter { !liveIDs.contains($0) }
        for id in deadIDs {
            untrack(activityID: id)
        }

        for activity in israelActivities {
            observeLifecycle(of: activity)
            if trackedContexts[activity.id] == nil {
                let staticData = activity.attributes.staticData
                let restored = IsraelTrackedActivityContext(
                    activityID: activity.id,
                    stopID: staticData.stopID,
                    routeShortName: staticData.routeShortName,
                    routeHeadsign: staticData.routeHeadsign,
                    tripID: staticData.tripID,
                    lastDepartureTime: activity.content.state.arrivals.first?.departureTime,
                    lastUpdateTime: Date()
                )
                trackedContexts[activity.id] = restored
            }
        }

        persistContexts()
        checkPollingState()
    }

    public func refreshTrackedActivities() async {
        guard !trackedContexts.isEmpty else { return }
        guard let apiService = apiServiceProvider() else {
            Logger.warn("IsraelLocalLiveActivityCoordinator: apiService is nil; cannot refresh.")
            return
        }

        let contextsByStop = Dictionary(grouping: trackedContexts.values, by: \.stopID)

        for (stopID, contexts) in contextsByStop {
            do {
                let response = try await apiService.getArrivalsAndDeparturesForStop(
                    id: stopID,
                    minutesBefore: 0,
                    minutesAfter: 90
                )
                consecutiveErrors = 0
                let arrivals = response.entry.arrivalsAndDepartures

                for context in contexts {
                    await updateActivity(withID: context.activityID, from: arrivals, context: context)
                }
            } catch {
                consecutiveErrors += 1
                Logger.error("IsraelLocalLiveActivityCoordinator: error fetching stop \(stopID): \(error)")
            }
        }
    }

    private func updateActivity(
        withID activityID: String,
        from allArrivals: [ArrivalDeparture],
        context: IsraelTrackedActivityContext
    ) async {
        guard let activity = Activity<TripAttributes>.activities.first(where: { $0.id == activityID }) else {
            untrack(activityID: activityID)
            return
        }

        let matchingArrivals: [ArrivalDeparture]
        if !context.tripID.isEmpty {
            let byTrip = allArrivals.filter { $0.tripID == context.tripID }
            if !byTrip.isEmpty {
                matchingArrivals = byTrip
            } else {
                matchingArrivals = allArrivals.filter {
                    $0.routeShortName == context.routeShortName
                }
            }
        } else {
            matchingArrivals = allArrivals.filter {
                $0.routeShortName == context.routeShortName
            }
        }

        let sorted = matchingArrivals.sorted { $0.arrivalDepartureDate < $1.arrivalDepartureDate }
        let newContentState = BookmarkActions.contentState(from: sorted)

        let now = Date()
        let staleDate: Date
        if let firstArrival = sorted.first {
            let soonestDeparture = firstArrival.arrivalDepartureDate
            staleDate = min(now.addingTimeInterval(300), soonestDeparture.addingTimeInterval(60))
        } else {
            staleDate = now.addingTimeInterval(300)
        }

        let existing = activity.content
        let updatedContent = TripLiveActivityRelevance.contentPreservingRelevance(
            state: newContentState,
            staleDate: staleDate,
            existing: existing
        )

        await activity.update(updatedContent)
        Logger.info("IsraelLocalLiveActivityCoordinator: updated activity \(activityID) with \(sorted.count) arrivals.")

        if var ctx = trackedContexts[activityID] {
            ctx.lastDepartureTime = sorted.first.map { Int($0.arrivalDepartureDate.timeIntervalSince1970) }
            ctx.lastUpdateTime = now
            trackedContexts[activityID] = ctx
            persistContexts()
        }
    }

    private func registerTrackedContext(
        _ context: IsraelTrackedActivityContext,
        for activity: Activity<TripAttributes>
    ) {
        trackedContexts[context.activityID] = context
        persistContexts()
        observeLifecycle(of: activity)
        checkPollingState()
    }

    private func untrackOnMain(activityID: String) async {
        untrack(activityID: activityID)
    }

    private func untrack(activityID: String) {
        trackedContexts.removeValue(forKey: activityID)
        lifecycleTasks[activityID]?.cancel()
        lifecycleTasks.removeValue(forKey: activityID)
        persistContexts()
        checkPollingState()
    }

    private func checkPollingState() {
        if isForeground && !trackedContexts.isEmpty {
            startPolling()
        } else {
            stopPolling()
        }
    }

    private func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                let backoffMultiplier = min(Double(self?.consecutiveErrors ?? 0), 3.0)
                let intervalSeconds = 30.0 + (backoffMultiplier * 30.0)

                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }

                await self?.refreshTrackedActivities()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func setupLifecycleNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isForeground = true
                self?.consecutiveErrors = 0
                self?.reconcileRunningActivities()
                await self?.refreshTrackedActivities()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isForeground = false
                self?.stopPolling()
            }
        }
    }

    private func loadPersistedContexts() {
        guard let data = userDefaults.data(forKey: persistenceKey) else { return }
        do {
            let contexts = try JSONDecoder().decode([IsraelTrackedActivityContext].self, from: data)
            self.trackedContexts = Dictionary(uniqueKeysWithValues: contexts.map { ($0.activityID, $0) })
        } catch {
            Logger.error("Failed to decode persisted Israel Live Activity contexts: \(error)")
        }
    }

    private func persistContexts() {
        do {
            let data = try JSONEncoder().encode(Array(trackedContexts.values))
            userDefaults.set(data, forKey: persistenceKey)
        } catch {
            Logger.error("Failed to encode Israel Live Activity contexts: \(error)")
        }
    }
}
