//
//  RouteDirectionLabelResolver.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import OBAKitCore

/// Resolves authentic destination and origin display labels from trip headsigns or route names.
/// Separates the headline destination from the subtle origin without conflating them into a single line.
public struct RouteDirectionLabelResolver: Sendable, Equatable {
    public let destination: String
    public let origin: String?

    public init(headsign: String, routeLongName: String? = nil) {
        let text = !headsign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? headsign : (routeLongName ?? "")
        let normalized = text
            .replacingOccurrences(of: "<->", with: "↔")
            .replacingOccurrences(of: "< - >", with: "↔")
            .replacingOccurrences(of: " - ", with: " ↔ ")

        let parts = normalized.split(separator: "↔").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count >= 2 {
            self.origin = String(parts[0])
            self.destination = String(parts[1])
        } else {
            self.destination = text.trimmingCharacters(in: .whitespacesAndNewlines)
            self.origin = nil
        }
    }
}
