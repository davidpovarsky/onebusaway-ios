//
//  IsraelRegionMigration.swift
//  IsraelMOT
//
//  Authoritative region migration and validation logic for Israel transit.
//

import Foundation
import OBAKitCore

public enum IsraelRegionMigration {

    public static let israelRegionIdentifier = 972

    /// Validates whether the given region definition contains valid endpoints for Israel MOT operations.
    public static func isValidIsraelRegion(_ region: Region) -> Bool {
        guard region.regionIdentifier == israelRegionIdentifier else { return false }
        let center = region.centerCoordinate
        return center.latitude >= 29.0 && center.latitude <= 34.0 &&
               center.longitude >= 34.0 && center.longitude <= 36.5
    }

    /// Preserves existing bookmarks and regional user settings during updates.
    public static func migrateRegionalSettingsIfNeeded(
        userDefaults: UserDefaults,
        currentRegion: Region?
    ) {
        guard let region = currentRegion, region.regionIdentifier == israelRegionIdentifier else {
            return
        }

        // Ensure active provider key is set if not already present
        if userDefaults.string(forKey: TransitProviderSelectionStore.userDefaultsKey) == nil {
            userDefaults.set(TransitProviderID.israelMOT.rawValue, forKey: TransitProviderSelectionStore.userDefaultsKey)
        }
    }
}
