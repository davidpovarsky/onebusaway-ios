//
//  IsraelRouteDirectionTitleView.swift
//  OBAKit
//
//  Unified SwiftUI presentation component for Israeli bus destination and origin lines.
//

import SwiftUI
import OBAKitCore

public struct IsraelRouteDirectionTitleView: View {
    public let headsign: String
    public let routeLongName: String?
    public let lineLimit: Int

    private var parsed: IsraelRouteDirectionResult {
        IsraelRouteDirectionFormatter.format(headsign: headsign, routeLongName: routeLongName)
    }

    public init(headsign: String, routeLongName: String? = nil, lineLimit: Int = 2) {
        self.headsign = headsign
        self.routeLongName = routeLongName
        self.lineLimit = lineLimit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(parsed.destination)
                .font(.system(.body, weight: .bold))
                .lineLimit(lineLimit)
                .accessibilityHeading(.h3)

            if let origin = parsed.origin, !origin.isEmpty {
                Text(String(format: OBALoc("departure_row.origin_fmt", value: "מוצא: %@", comment: "Subdued origin line under destination"), origin))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(parsed.accessibilityLabel)
    }
}
