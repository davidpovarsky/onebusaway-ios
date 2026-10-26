//
//  IsraelWidgetArrivalsClient.swift
//  IsraelMOT
//
//  Widget-safe arrivals loader for Israel MOT bookmarks.
//  Operates without dependencies on UIKit or Application singleton.
//

import Foundation
import CoreLocation
import OBAKitCore

public final class IsraelWidgetArrivalsClient: Sendable {
    public static let shared = IsraelWidgetArrivalsClient()

    public init() {}

    /// Loads arrivals for the provided Israeli bookmarks using the MOT compatibility pipeline.
    public func loadDepartures(
        for bookmarks: [Bookmark],
        in region: Region,
        apiKey: String,
        appVersion: String,
        uuid: String,
        minutesAfter: Int = 90
    ) async -> [UUID: [ArrivalDeparture]] {
        guard region.regionIdentifier == IsraelProviderBootstrap.israelRegionIdentifier else {
            return [:]
        }

        // Use MOT compatibility loader to intercept OBA requests and map MOT real-time arrivals
        let loader = MOTCompatibilityDataLoader()
        let service = RESTAPIService.standalone(
            region: region,
            apiKey: apiKey,
            appVersion: appVersion,
            uuid: uuid,
            dataLoader: loader
        )

        let departuresLoader = BookmarkArrivalsLoader(minutesAfter: UInt(max(0, minutesAfter)))
        return await departuresLoader.departuresByBookmark(for: bookmarks, using: service)
    }
}
