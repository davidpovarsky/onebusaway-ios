//
//  IsraelProviderBootstrap.swift
//  IsraelMOT
//
//  Authoritative bootstrap and data loader factory for Israel transit.
//

import Foundation
import OBAKitCore

public enum IsraelProviderBootstrap {

    public static let israelRegionIdentifier = 972

    /// Returns whether the Israel transit provider is active for the specified region ID.
    public static func isIsraelMOTActive(regionIdentifier: Int?) -> Bool {
        guard regionIdentifier == israelRegionIdentifier else { return false }
        let currentProvider = TransitProviderSelectionStore.currentProviderID()
        return currentProvider == .israelMOT
    }

    /// Determines whether the active transit context represents Israel.
    public static func isIsraelContext(routeID: String? = nil, stopID: String? = nil) -> Bool {
        if let routeID = routeID, routeID.hasPrefix("mot:") { return true }
        if let stopID = stopID, stopID.hasPrefix("mot:") { return true }
        if let currentRegionID = UserDefaults.standard.object(forKey: RegionsService.currentRegionIdentifierUserDefaultsKey) as? Int {
            return currentRegionID == israelRegionIdentifier
        }
        return false
    }

    /// Resolves the authentic `URLDataLoader` for the given region.
    /// Falls back to the provided loader for non-972 regions or when native OBA is explicitly selected.
    public static func dataLoader(
        for region: Region?,
        fallbackLoader: URLDataLoader
    ) -> URLDataLoader {
        guard let region = region, region.regionIdentifier == israelRegionIdentifier else {
            return fallbackLoader
        }

        let currentProvider = TransitProviderSelectionStore.currentProviderID()
        if currentProvider == .israelMOT {
            return MOTCompatibilityDataLoader(fallbackLoader: fallbackLoader)
        } else {
            return fallbackLoader
        }
    }
}
