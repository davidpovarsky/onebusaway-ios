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
        // Verify Israel coordinates bounds roughly cover Israel
        let bounds = region.bounds
        guard !bounds.isEmpty else { return false }
        let coversIsrael = bounds.contains { bound in
            bound.lat >= 29.0 && bound.lat <= 34.0 &&
            bound.lon >= 34.0 && bound.lon <= 36.5
        }
        return coversIsrael
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
