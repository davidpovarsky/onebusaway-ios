//
//  NearbyStopsListViewControllerTests.swift
//  OBAKitTests
//
//  Created for OneBusAway Israel (P0 Diffable Data Source Deduplication Fix)
//

import Foundation
import UIKit
import Testing
@testable import OBAKit
@testable import OBAKitCore

@MainActor
@Suite(.serialized)
final class NearbyStopsListViewControllerTests {

    private final class MockDataSource: NearbyStopsListDataSource {
        var highSeverityAlerts: [AgencyAlert] = []
        var stops: [Stop] = []
    }

    @Test
    func testDuplicateStopIDsDoNotCrashDiffableDataSource() throws {
        let controller = NearbyStopsListViewController()
        let dataSource = MockDataSource()
        controller.dataSource = dataSource

        // Force view hierarchy and collection view diffable data source initialization
        _ = controller.view

        let baseStops = try Fixtures.loadSomeStops()
        guard let firstStop = baseStops.first else {
            Issue.record("No fixture stops available")
            return
        }

        // Intentionally feed duplicate stop instances with identical Stop.ID
        dataSource.stops = [firstStop, firstStop, firstStop]

        // Prior to the defensive deduplication fix, appending duplicates to the section snapshot
        // caused NSInternalInconsistencyException (SIGABRT).
        // With deduplication in place, this must complete cleanly without throwing or crashing.
        controller.updateList()
    }
}
