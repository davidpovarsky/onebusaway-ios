//
//  RoutePickerView.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import SwiftUI
import OBAKitCore

/// SwiftUI route picker surfaced by `AppSheetRoute.routePicker`. Drives the
/// merged `RoutePickerViewModel`; on selection, opens route details with stops and map.
struct RoutePickerView: View {
    @StateObject private var viewModel: RoutePickerViewModel
    @EnvironmentObject var coordinator: SheetCoordinator<AppSheetRoute>

    var onSelectRoute: ((Route) -> Void)?

    @State private var searchText: String = ""
    @State private var loadTask: Task<Void, Never>?

    init(
        viewModel: @autoclosure @escaping () -> RoutePickerViewModel,
        onSelectRoute: ((Route) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onSelectRoute = onSelectRoute
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text(Strings.routePickerTitle))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(Strings.routePickerSearchPlaceholder)
                )
                .accessibilityIdentifier("oba.route_picker.search_field")
                .onChange(of: searchText) { _, newValue in
                    viewModel.updateSearch(newValue)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(Strings.close) { coordinator.pop() }
                    }
                    if viewModel.isSearching {
                        ToolbarItem(placement: .topBarTrailing) {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
        }
        .onAppear {
            startLoad()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    /// Kicks off a fresh `loadRoutes()` unless one is already in flight. Re-entrant
    /// safe: SwiftUI can re-attach on scenePhase changes, and the retry button
    /// funnels through the same entry point.
    private func startLoad() {
        guard loadTask == nil else { return }
        loadTask = Task { [viewModel] in
            await viewModel.loadRoutes()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.didFinishLoading && viewModel.allRoutes.isEmpty {
            EmptyStateView(title: Strings.routePickerLoading, systemImage: AppSymbol.loading)
        } else if let error = viewModel.loadError, viewModel.filteredRoutes.isEmpty {
            EmptyStateView(title: error.localizedDescription, systemImage: AppSymbol.error) { retryButton }
        } else if viewModel.allRoutes.isEmpty && !viewModel.isSearching {
            EmptyStateView(title: Strings.routePickerNoRoutes, systemImage: AppSymbol.search)
        } else if viewModel.filteredRoutes.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if viewModel.isSearching {
                EmptyStateView(title: Strings.routePickerLoading, systemImage: AppSymbol.loading)
            } else {
                EmptyStateView(title: Strings.routePickerNoRoutes, systemImage: AppSymbol.search)
            }
        } else {
            routesList
        }
    }

    private var retryButton: some View {
        Button {
            loadTask?.cancel()
            loadTask = nil
            startLoad()
        } label: {
            Label(Strings.currentTripTryAgain, systemImage: AppSymbol.retry)
        }
        .padding(.top, 8)
    }

    private var routesList: some View {
        List(viewModel.filteredRoutes, id: \.id) { route in
            routeRow(route)
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("oba.route_picker.list")
    }

    private func routeRow(_ route: Route) -> some View {
        Button {
            if let onSelectRoute {
                onSelectRoute(route)
            } else {
                coordinator.push(.currentTrip(route: route))
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(route.shortName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(ThemeColors.shared.label))
                    if let agency = route.agency.name, !agency.isEmpty {
                        Text(agency)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                            .foregroundStyle(Color(ThemeColors.shared.secondaryLabel))
                    }
                }
                if let longName = route.longName, !longName.isEmpty {
                    Text(longName)
                        .font(.subheadline)
                        .foregroundStyle(Color(ThemeColors.shared.secondaryLabel))
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("oba.route_picker.row.\(route.shortName)")
    }
}
