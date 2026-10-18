//
//  MOTProviderSettingsView.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (Multi-Provider Architecture)
//

import SwiftUI

public struct MOTProviderSettingsView: View {
    @ObservedObject private var store = TransitProviderSelectionStore.shared

    public init() {}

    public var body: some View {
        List {
            Section(header: Text("ספקי תחבורה ונותני שירות")) {
                ForEach(TransitProviderRegistry.shared.allProviders) { provider in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(provider.displayName)
                                .font(.headline)
                            Spacer()
                            if store.activeProviderID == provider.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else if !provider.isAvailable {
                                Text("לא זמין")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }

                        Text(provider.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let status = provider.statusMessage {
                            HStack {
                                Text("מצב:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(status)
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(provider.isAvailable ? .green : .orange)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if provider.isAvailable {
                            _ = store.selectProvider(provider.id)
                        }
                    }
                    .opacity(provider.isAvailable ? 1.0 : 0.6)
                }
            }

            Section(header: Text("מאגר תחנות ארצי מקומי")) {
                HStack {
                    Text("מקור נתונים")
                    Spacer()
                    Text("GTFS משרד התחבורה")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("כיסוי תחנות")
                    Spacer()
                    Text("35,387 תחנות בכל הארץ")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("אינדקס גיאוגרפי")
                    Spacer()
                    Text("SQLite R-Tree מקומי")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("מצב שימוש ללא רשת")
                    Spacer()
                    Label("זמין אופליין", systemImage: "bolt.horizontal.circle.fill")
                        .foregroundColor(.green)
                }
                HStack {
                    Text("תנועת מפה (Pan/Zoom)")
                    Spacer()
                    Text("0 פניות רשת")
                        .foregroundColor(.green)
                }
            }

            Section(header: Text("יכולות הספק הפעיל")) {
                capabilityRow(title: "שליפת תחנות במפה", status: store.activeDescriptor.capabilities.mapViewportStops)
                capabilityRow(title: "חיפוש קווים ותחנות", status: store.activeDescriptor.capabilities.searchLines)
                capabilityRow(title: "תחנות ולוח זמנים של קו", status: store.activeDescriptor.capabilities.routeStops)
                capabilityRow(title: "תכנון מסלול (GetRoutes)", status: store.activeDescriptor.capabilities.planJourney)
                capabilityRow(title: "תכנון לפי שעת הגעה (Arrive By)", status: store.activeDescriptor.capabilities.arriveBy)
                capabilityRow(title: "זמני אמת וספירה לאחור", status: store.activeDescriptor.capabilities.predictions)
                capabilityRow(title: "מיקום רכב פעיל בקו", status: store.activeDescriptor.capabilities.vehicleLocations)
            }

            Section(footer: Text("תשתית OneBusAway ישראל מפרידה בין מאגר התחנות הארצי המקומי לבין ספקי נתוני הנסיעה, ומאפשרת הרחבה עתידית לספקים נוספים כגון Bus Nearby.")) {
                EmptyView()
            }
        }
        .navigationTitle("ספקי תחבורה ונתונים")
    }

    @ViewBuilder
    private func capabilityRow(title: String, status: CapabilityStatus) -> some View {
        HStack {
            Text(title)
            Spacer()
            switch status {
            case .supported:
                Label("נתמך", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .degraded(let reason):
                Label(reason, systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            case .temporarilyUnavailable(let reason):
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            case .futurePlaceholder(let desc):
                Label(desc, systemImage: "clock.badge.questionmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .unsupported:
                Label("לא נתמך", systemImage: "xmark.circle")
                    .foregroundColor(.secondary)
            }
        }
    }
}
