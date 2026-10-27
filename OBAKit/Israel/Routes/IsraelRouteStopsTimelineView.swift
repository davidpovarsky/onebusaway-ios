//
//  IsraelRouteStopsTimelineView.swift
//  OBAKit
//
//  Graphic timeline spine presentation for Israeli route stops.
//

import SwiftUI
import MapKit
import OBAKitCore

struct IsraelRouteStopsTimelineView: View {
    let stopsForRoute: StopsForRoute
    let displayModel: MapSearchDisplayModel
    let onSelectStop: (Stop.ID, CLLocationCoordinate2D) -> Void

    private var timelineItems: [IsraelRouteStopItem] {
        IsraelRouteStopTimelineFactory.makeTimeline(from: stopsForRoute)
    }

    init(
        stopsForRoute: StopsForRoute,
        displayModel: MapSearchDisplayModel,
        onSelectStop: @escaping (Stop.ID, CLLocationCoordinate2D) -> Void
    ) {
        self.stopsForRoute = stopsForRoute
        self.displayModel = displayModel
        self.onSelectStop = onSelectStop
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                    timelineRow(item: item, isFirst: item.isFirstStop, isLast: item.isLastStop)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func timelineRow(item: IsraelRouteStopItem, isFirst: Bool, isLast: Bool) -> some View {
        Button {
            displayModel.focus(coordinate: item.coordinate)
            onSelectStop(item.id, item.coordinate)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                // Timeline spine & indicator
                timelineIndicator(isFirst: isFirst, isLast: isLast)
                    .frame(width: 24)

                // Stop Name, Code, and Details
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(uiColor: ThemeColors.shared.label))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text("תחנה \(item.stopCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !item.subtitle.isEmpty {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(uiColor: ThemeColors.shared.brand))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.sequence). \(item.name), תחנה \(item.stopCode)")
        .accessibilityHint("לחיצה מציגה את פרטי התחנה וזמני הגעה")
        .accessibilityIdentifier("oba.israel.timeline.stop.\(item.stopCode)")
    }

    @ViewBuilder
    private func timelineIndicator(isFirst: Bool, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            // Top half line
            Rectangle()
                .fill(isFirst ? Color.clear : Color(uiColor: ThemeColors.shared.brand).opacity(0.4))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            // Center Node
            ZStack {
                if isFirst {
                    Circle()
                        .fill(Color(uiColor: ThemeColors.shared.brand))
                        .frame(width: 14, height: 14)
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 14, height: 14)
                } else if isLast {
                    Circle()
                        .fill(Color(uiColor: .systemRed))
                        .frame(width: 14, height: 14)
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 14, height: 14)
                } else {
                    Circle()
                        .strokeBorder(Color(uiColor: ThemeColors.shared.brand), lineWidth: 2.5)
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .frame(width: 11, height: 11)
                }
            }
            .frame(height: 16)

            // Bottom half line
            Rectangle()
                .fill(isLast ? Color.clear : Color(uiColor: ThemeColors.shared.brand).opacity(0.4))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
        }
    }
}
