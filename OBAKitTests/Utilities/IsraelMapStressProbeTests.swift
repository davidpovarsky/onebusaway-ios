//
//  IsraelMapStressProbeTests.swift
//  OBAKitTests
//
//  Regression test for IsraelMapStressProbe thread safety and deadlock prevention.
//

import Foundation
import Testing
@testable import OBAKit

#if DEBUG
@Suite("IsraelMapStressProbe Tests")
struct IsraelMapStressProbeTests {

    @Test("Concurrent update and serializedStatus do not deadlock")
    nonisolated func testConcurrentUpdatesAndSerializationDoNotDeadlock() async throws {
        setenv("ISRAEL_MAP_STRESS_TEST", "1", 1)
        defer { unsetenv("ISRAEL_MAP_STRESS_TEST") }

        let probe = IsraelMapStressProbe.shared

        // Initial sanity check
        probe.update(mapMode: "classic", regionID: 972, providerID: "israel-mot")
        let initialStatus = probe.serializedStatus()
        #expect(initialStatus.contains("mapMode=classic"))
        #expect(initialStatus.contains("regionID=972"))
        #expect(initialStatus.contains("providerID=israel-mot"))

        // Heavy concurrent stress: 10 parallel tasks performing 200 iterations each
        await withTaskGroup(of: Void.self) { group in
            for workerId in 0..<10 {
                group.addTask {
                    for i in 0..<200 {
                        if i % 2 == 0 {
                            probe.update(
                                mapMode: "classic",
                                regionID: 972,
                                centerLatitude: 31.790 + Double(workerId) * 0.001,
                                centerLongitude: 35.210 + Double(i) * 0.0001,
                                latitudeSpan: 0.05,
                                longitudeSpan: 0.05,
                                visibleMapRectHeight: 35000.0,
                                catalogAvailable: true,
                                loadedStopsCount: 150 + i,
                                renderedStopsCount: 75 + (i % 50)
                            )
                        } else {
                            let status = probe.serializedStatus()
                            let snap = probe.snapshot()
                            _ = status.count
                            _ = snap.regionID
                        }
                    }
                }
            }
        }

        let finalSnapshot = probe.snapshot()
        #expect(finalSnapshot.regionID == 972)
        #expect(finalSnapshot.catalogAvailable == true)
        #expect(finalSnapshot.loadedStopsCount >= 150)
        let finalStatus = probe.serializedStatus()
        #expect(finalStatus.contains("regionID=972"))
        #expect(finalStatus.contains("catalogAvailable=true"))
    }
}
#endif
