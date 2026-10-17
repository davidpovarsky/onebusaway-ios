//
//  MOTDateParser.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

nonisolated public enum MOTDateParser {
    public static let jerusalemTimeZone: TimeZone = TimeZone(identifier: "Asia/Jerusalem") ?? TimeZone(secondsFromGMT: 7200)!

    /// Parses a date string from the MOT API.
    ///
    /// If the string contains a 'Z' or explicit timezone offset, it is parsed as ISO8601 UTC/offset.
    /// If no timezone offset is present (the standard for MOT RoutePlanning and Scheduler timestamps,
    /// e.g. "2026-10-18T09:32:00"), it is strictly interpreted in the "Asia/Jerusalem" timezone
    /// taking into account Israel's daylight saving time (DST) rules.
    ///
    /// Never returns `Date()` as a fallback on failure; returns `nil` if the string cannot be parsed.
    public static func parse(_ dateString: String?) -> Date? {
        guard let str = dateString?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else {
            return nil
        }

        // 1. If explicit 'Z' or timezone offset (+XX:XX or -XX:XX) at the end
        if str.hasSuffix("Z") || hasTimezoneOffset(str) {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: str) {
                return date
            }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: str) {
                return date
            }
        }

        // 2. Local Israel wall-clock time without timezone offset
        let localFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "HH:mm:ss",
            "HH:mm"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = jerusalemTimeZone
        formatter.calendar = Calendar(identifier: .gregorian)

        for format in localFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: str) {
                return date
            }
        }

        return nil
    }

    private static func hasTimezoneOffset(_ str: String) -> Bool {
        guard str.count >= 6 else { return false }
        let suffix = str.suffix(6)
        guard let first = suffix.first, first == "+" || first == "-" else { return false }
        let chars = Array(suffix)
        return chars[3] == ":" && chars[1].isNumber && chars[2].isNumber && chars[4].isNumber && chars[5].isNumber
    }
}
