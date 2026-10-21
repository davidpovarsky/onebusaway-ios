//
//  AmbientVehicleDetailCard.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import SwiftUI
import OBAKitCore

/// A human-readable, Hebrew-localized detail card surfaced when tapping a live transit vehicle on the map.
/// Displays line number, operator, destination, next stop, real-time ETA and an 'Open Trip Details' action.
struct AmbientVehicleDetailCard: View {
    let vehicle: AmbientLiveVehicle
    let onOpenTrip: () -> Void
    let onClose: () -> Void

    private var formattedETA: String? {
        guard let eta = vehicle.etaDate else { return nil }
        let df = DateFormatter()
        df.timeStyle = .short
        df.locale = Locale(identifier: "he_IL")
        return df.string(from: eta)
    }

    private var formattedLastUpdate: String? {
        guard let update = vehicle.lastUpdateTime else { return nil }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "he_IL")
        return rel.localizedString(for: update, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Close button and Drag indicator
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("סגור")
            }

            // Route & Operator Header
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(vehicle.routeColor)
                        .frame(width: 52, height: 52)
                    Text(vehicle.routeShortName)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.headsign.isEmpty ? "קו \(vehicle.routeShortName)" : "אל \(vehicle.headsign)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if !vehicle.agencyName.isEmpty {
                            Text(vehicle.agencyName)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                                .foregroundStyle(.secondary)
                        }

                        if let updateStr = formattedLastUpdate {
                            Text(updateStr)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Real-Time Trip Context Details
            VStack(alignment: .leading, spacing: 10) {
                if let nextStop = vehicle.nextStopName, !nextStop.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(vehicle.routeColor)
                            .frame(width: 20)
                        Text("תחנה הבאה:")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(nextStop)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }

                if let etaStr = formattedETA {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(vehicle.routeColor)
                            .frame(width: 20)
                        Text("זמן הגעה משוער:")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(etaStr)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("מיקום:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.4f, %.4f", vehicle.coordinate.latitude, vehicle.coordinate.longitude))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let vid = vehicle.vehicleID, !vid.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "number")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text("מזהה רכב:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(vid)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            // Primary Navigation Button
            Button(action: onOpenTrip) {
                HStack {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    Text("פתח פרטי נסיעה")
                        .font(.headline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(vehicle.routeColor, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .accessibilityIdentifier("oba.ambient_vehicle.open_trip_button")
        }
        .padding(20)
        .background(Color(uiColor: .systemBackground))
        .presentationDetents([.height(340), .medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("oba.ambient_vehicle.detail_sheet")
    }
}
