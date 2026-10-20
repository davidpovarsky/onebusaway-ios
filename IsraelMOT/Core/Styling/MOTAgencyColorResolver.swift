//
//  MOTAgencyColorResolver.swift
//  IsraelMOT
//
//  Authoritative agency and operator color resolution for Israeli transit.
//

import Foundation
import UIKit
import OBAKitCore

nonisolated public enum MOTAgencyColorResolver {

    public struct ResolvedColors: Equatable, Sendable {
        public let colorHex: String
        public let textColorHex: String

        public init(colorHex: String, textColorHex: String) {
            self.colorHex = colorHex
            self.textColorHex = textColorHex
        }
    }

    /// Primary brand colors for licensed public transport operators in Israel.
    private static let agencyHexColors: [Int: String] = [
        2: "0D47A1",   // Israel Railways / רכבת ישראל
        3: "007A3D",   // Egged / אגד
        4: "2E7D32",   // Egged Taavura / אגד תעבורה
        5: "002D72",   // Dan / דן
        6: "0277BD",   // Dan BaDarom / דן בדרום
        7: "00838F",   // Dan Be'er Sheva / דן באר שבע
        8: "EA5A00",   // Metropoline / מטרופולין
        10: "00897B",  // Superbus (North) / סופרבוס
        14: "00695C",  // Nativ Express / נתיב אקספרס
        15: "EA5A00",  // Kavim / קווים
        16: "004F9E",  // Superbus (Jerusalem) / סופרבוס ירושלים
        18: "283593",  // Electra Afikim / אלקטרה אפיקים
        20: "6A1B9A",  // Tnufa / תנופה
        21: "AD1457",  // Extra / אקסטרה
        22: "37474F",  // Beit Shemesh Express / בית שמש אקספרס
        23: "AD1457",  // Extra Public Transport
        24: "D32F2F",  // Kfir (Jerusalem Light Rail) / כפיר
        25: "C2185B",  // Tevel (Dankal Tel Aviv Light Rail) / תבל
        31: "00838F"   // Galim / גלים
    ]

    private static let defaultBrandHex = "007A3D" // Israel transit green fallback

    /// Resolves the authentic operator color and contrast-safe text color.
    public static func resolve(agencyID: MOTAgencyID?, customColor: String? = nil) -> ResolvedColors {
        let hex: String
        if let custom = customColor?.trimmingCharacters(in: .whitespacesAndNewlines),
           isValidHex(custom) {
            hex = normalizeHex(custom)
        } else if let id = agencyID?.rawValue, let operatorHex = agencyHexColors[id] {
            hex = operatorHex
        } else {
            hex = defaultBrandHex
        }

        let textColor = contrastTextColor(forHex: hex)
        return ResolvedColors(colorHex: hex, textColorHex: textColor)
    }

    public static func hexColor(forAgencyID agencyID: Int) -> String {
        return resolve(agencyID: MOTAgencyID(agencyID)).colorHex
    }

    public static func textColorHex(forAgencyID agencyID: Int) -> String {
        return resolve(agencyID: MOTAgencyID(agencyID)).textColorHex
    }

    public static func color(forAgencyID agencyID: Int) -> UIColor {
        let hex = hexColor(forAgencyID: agencyID)
        return UIColor(hex: hex) ?? .systemGreen
    }

    public static func contrastingTextColor(forHex hex: String) -> UIColor {
        let textHex = contrastTextColor(forHex: hex)
        return UIColor(hex: textHex) ?? .white
    }

    /// Verifies if a string is a 6-digit RGB hex code (with or without '#').
    public static func isValidHex(_ hex: String) -> Bool {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard clean.count == 6 else { return false }
        return clean.allSatisfy { $0.isHexDigit }
    }

    private static func normalizeHex(_ hex: String) -> String {
        return hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
    }

    /// Calculates high-contrast foreground text color (000000 or FFFFFF)
    /// based on ITU-R BT.601 perceived luminance.
    public static func contrastTextColor(forHex hex: String) -> String {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard clean.count == 6, let intVal = UInt32(clean, radix: 16) else {
            return "FFFFFF"
        }

        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0

        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.55 ? "000000" : "FFFFFF"
    }
}
