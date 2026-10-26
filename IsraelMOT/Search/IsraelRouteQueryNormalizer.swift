//
//  IsraelRouteQueryNormalizer.swift
//  IsraelMOT
//
//  Authoritative query normalization and intent classification for transit search.
//  Converts Arabic-Indic digits, strips linguistic bus line prefixes (Hebrew/Arabic/English).
//

import Foundation

public enum TransitQueryIntent: Sendable, Equatable {
    case route
    case stopNumber
    case address
}

public enum IsraelRouteQueryNormalizer {

    private static let arabicIndicNumerals: [Character: Character] = [
        "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
        "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"
    ]

    /// Normalizes raw user search input:
    /// 1. Replaces Eastern Arabic numerals with Western Arabic digits.
    /// 2. Strips common line prefixes like "קו", "خط", "line", "route", "bus".
    /// 3. Trims whitespace and newlines.
    public static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let ascii = toAsciiDigits(trimmed)
        return ascii.replacingOccurrences(
            of: "^(קו|خط|line|route|bus)\\s*",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Converts Arabic-Indic numbers to Western digits.
    public static func toAsciiDigits(_ raw: String) -> String {
        String(raw.map { arabicIndicNumerals[$0] ?? $0 })
    }

    /// Classifies user search input into Route, Stop Number, or Address.
    public static func detectIntent(for raw: String, isIsraelRegion: Bool) -> TransitQueryIntent {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .address }

        let asciiTrimmed = toAsciiDigits(trimmed)

        let hasRoutePrefix = asciiTrimmed.hasPrefix("קו") ||
            asciiTrimmed.hasPrefix("خط") ||
            asciiTrimmed.localizedCaseInsensitiveContains("line ") ||
            asciiTrimmed.localizedCaseInsensitiveContains("route ") ||
            asciiTrimmed.localizedCaseInsensitiveContains("bus ")

        if hasRoutePrefix {
            return .route
        } else if let num = Int(asciiTrimmed), num > 0 {
            // Short numbers (1-3 digits) are almost always bus lines; 4+ digits are stop numbers.
            return asciiTrimmed.count <= 3 ? .route : .stopNumber
        } else {
            // Recognize route patterns like "31 ירושלים", "86 מרכז", or alphanumeric lines like "31א", "14ב"
            let tokens = asciiTrimmed.split(separator: " ")
            let firstToken = tokens.first ?? ""
            let isAlphaNumericRoute = firstToken.count <= 4 && firstToken.contains(where: \.isNumber)
            if isAlphaNumericRoute && isIsraelRegion {
                return .route
            } else {
                return .address
            }
        }
    }
}
