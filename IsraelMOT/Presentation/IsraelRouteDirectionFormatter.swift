//
//  IsraelRouteDirectionFormatter.swift
//  IsraelMOT
//
//  Authoritative destination and origin parsing for Israeli transit headsigns.
//

import Foundation

public struct IsraelRouteDirectionResult: Sendable, Equatable {
    public let destination: String
    public let origin: String?
    public let rawText: String

    public init(destination: String, origin: String?, rawText: String) {
        self.destination = destination
        self.origin = origin
        self.rawText = rawText
    }

    /// Accessibility VoiceOver representation.
    public var accessibilityLabel: String {
        if let origin = origin, !origin.isEmpty {
            return "אל \(destination), מוצא: \(origin)"
        }
        return "אל \(destination)"
    }
}

public enum IsraelRouteDirectionFormatter {

    /// Standardizes headsign string by splitting distinct origin and destination names.
    /// Safely handles bidirectional markers ("<->", "↔", " - ") without corrupting single destinations.
    public static func format(headsign: String, routeLongName: String? = nil) -> IsraelRouteDirectionResult {
        let trimmedHeadsign = headsign.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackText = (routeLongName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let text = !trimmedHeadsign.isEmpty ? trimmedHeadsign : fallbackText

        guard !text.isEmpty else {
            return IsraelRouteDirectionResult(destination: "", origin: nil, rawText: "")
        }

        // Normalize various bidirectional and directional delimiters to standard arrow "↔"
        let normalized = text
            .replacingOccurrences(of: "<->", with: "↔")
            .replacingOccurrences(of: "< - >", with: "↔")
            .replacingOccurrences(of: "<—>", with: "↔")
            .replacingOccurrences(of: " <-> ", with: "↔")
            .replacingOccurrences(of: " - ", with: " ↔ ")

        let parts = normalized
            .split(separator: "↔")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            let origin = stripLeadingLineNumber(from: String(parts[0]))
            let destination = stripLeadingLineNumber(from: String(parts[1]))
            return IsraelRouteDirectionResult(destination: destination, origin: origin, rawText: text)
        } else {
            return IsraelRouteDirectionResult(destination: text, origin: nil, rawText: text)
        }
    }

    private static func stripLeadingLineNumber(from string: String) -> String {
        let pattern = #"^[0-9]+[א-תa-zA-Z]?\s+"#
        if let range = string.range(of: pattern, options: .regularExpression) {
            return String(string[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return string
    }
}
