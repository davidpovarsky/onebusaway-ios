//
//  MOTLegStyleResolver.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Resolves authentic, accessible, and distinguishable colors for journey planner legs.
/// Implements a stable per-leg differentiation system so consecutive transit legs
/// (e.g. bus 86 followed by bus 67) remain visually distinct even when sharing an agency.
nonisolated public enum MOTLegStyleResolver {

    /// Named accessible palette for consecutive transit legs when official provider color is absent.
    /// Tested for high contrast and colorblind accessibility.
    public static let fallbackTransitPalette: [String] = [
        "#007AFF", // Leg 1: System Blue
        "#2E7D32", // Leg 2: Forest Green (reference: Ministry 86 -> 67 transfer)
        "#7B1FA2", // Leg 3: Deep Purple
        "#E65100", // Leg 4: Deep Amber / Orange
        "#00838F", // Leg 5: Dark Teal
        "#C2185B"  // Leg 6: Dark Rose
    ]

    public static let walkingColor = "#8E8E93" // Neutral Apple System Gray

    /// Resolves the stroke color for a transit or walking section.
    ///
    /// - Parameters:
    ///   - transportColor: Official color from `SectionDTO.transport.color` (if present).
    ///   - transitLegIndex: Zero-based index of this transit leg within the itinerary.
    ///   - isWalk: Whether this section is a pedestrian walking leg.
    /// - Returns: Valid normalized hex color string (e.g. `"#007AFF"`).
    public static func resolveColor(
        transportColor: String?,
        transitLegIndex: Int,
        isWalk: Bool
    ) -> String {
        if isWalk {
            return walkingColor
        }

        if let validColor = normalizeHexColor(transportColor) {
            return validColor
        }

        let paletteIndex = abs(transitLegIndex) % fallbackTransitPalette.count
        return fallbackTransitPalette[paletteIndex]
    }

    /// Resolves high-contrast text color (`#FFFFFF` or `#000000`) for a route badge background.
    public static func resolveTextColor(forBackgroundColor hexColor: String) -> String {
        let (r, g, b) = rgbComponents(from: hexColor)
        // Standard perceived luminance calculation
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.55 ? "#000000" : "#FFFFFF"
    }

    /// Validates and normalizes hex color strings to `#RRGGBB` format.
    public static func normalizeHexColor(_ color: String?) -> String? {
        guard let color = color?.trimmingCharacters(in: .whitespacesAndNewlines), !color.isEmpty else {
            return nil
        }
        var clean = color.replacingOccurrences(of: "#", with: "")
        if clean.count == 3 {
            clean = clean.map { "\($0)\($0)" }.joined()
        }
        guard clean.count == 6, Int(clean, radix: 16) != nil else {
            return nil
        }
        return "#" + clean.uppercased()
    }

    private static func rgbComponents(from hexColor: String) -> (Double, Double, Double) {
        var clean = hexColor.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.count == 3 {
            clean = clean.map { "\($0)\($0)" }.joined()
        }
        guard clean.count == 6, let rgb = UInt64(clean, radix: 16) else {
            return (0.0, 0.48, 1.0) // Fallback blue
        }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        return (r, g, b)
    }
}
