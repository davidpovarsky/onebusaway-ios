//
//  IsraelMapZoomStressUITests.swift
//  OBAKitUITests
//
//  Automated comprehensive stress testing of OneBusAway Israel map on iPad Simulator.
//  Reproduces and diagnoses zoom-out / pan crashes with real Israeli stops and touch gestures.
//

import XCTest
import CoreLocation

final class IsraelMapZoomStressUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        if let app = app, app.state == .runningForeground {
            let finalAttachment = XCTAttachment(screenshot: app.screenshot())
            finalAttachment.name = "Final_Test_State"
            finalAttachment.lifetime = .keepAlways
            add(finalAttachment)
        }
        app = nil
    }

    // MARK: - Test Cases

    /// Scenario 1: Classic UIKit Map (MapViewController + MapRegionManager)
    /// Reproduces zoom-out / pan stress in Jerusalem with real SQLite stops.
    func testJerusalemClassicMapZoomPanStress() throws {
        try runMapStressSuite(
            testName: "Classic_UIKit",
            useMapPanel: false,
            location: CLLocation(latitude: 31.790, longitude: 35.210),
            cityName: "Jerusalem"
        )
    }

    /// Scenario 2: Modern SwiftUI Map (MapPanelRootView + MapStopsObserver)
    /// Tests the SwiftUI map-panel implementation under identical zoom/pan stress.
    func testJerusalemSwiftUIMapZoomPanStress() throws {
        try runMapStressSuite(
            testName: "SwiftUI_MapPanel",
            useMapPanel: true,
            location: CLLocation(latitude: 31.790, longitude: 35.210),
            cityName: "Jerusalem"
        )
    }

    /// Scenario 3: Rapid Zoom Cancellation Stress
    /// Fires rapid zoom-in and zoom-out gestures without waiting for camera settles,
    /// heavily stressing the debounce timer, task cancellation, and tile/annotation pipelines.
    func testJerusalemRapidZoomCancellation() throws {
        let location = CLLocation(latitude: 31.790, longitude: 35.210)
        launchApp(useMapPanel: false, location: location)

        let map = try locateAndVerifyMap(useMapPanel: false)
        try verifyRealIsraelStopsLoaded(expectedCityLat: 31.790, minStops: 10)

        for cycle in 1...12 {
            XCTContext.runActivity(named: "RapidCancellation_Cycle_\(cycle)") { _ in
                XCTAssertEqual(app.state, .runningForeground, "App crashed during rapid cancellation cycle \(cycle)")

                // Burst 1: 3 rapid zoom outs
                map.pinch(withScale: 0.65, velocity: 2.0)
                map.pinch(withScale: 0.65, velocity: 2.0)
                map.pinch(withScale: 0.65, velocity: 2.0)

                // Burst 2: 2 rapid zoom ins immediately
                map.pinch(withScale: 1.5, velocity: 2.0)
                map.pinch(withScale: 1.5, velocity: 2.0)

                // Burst 3: Rapid switch
                map.pinch(withScale: 0.55, velocity: 2.0)
                map.pinch(withScale: 1.8, velocity: 2.0)

                Thread.sleep(forTimeInterval: 0.35)

                let status = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [RapidCancellation Cycle \(cycle)] mem=\(status["memoryFootprintMB"] ?? "?")MB loaded=\(status["loadedStopsCount"] ?? "?") rendered=\(status["renderedStopsCount"] ?? "?") height=\(status["visibleMapRectHeight"] ?? "?")")
            }
        }
    }

    /// Scenario 4: Dense City Stress (Tel Aviv Metropolitan Area)
    /// Validates behavior under high station density.
    func testDenseCityMapStress() throws {
        try runMapStressSuite(
            testName: "TelAviv_DenseCity",
            useMapPanel: false,
            location: CLLocation(latitude: 32.080, longitude: 34.780),
            cityName: "TelAviv"
        )
    }

    // MARK: - Core Stress Runner

    private func runMapStressSuite(
        testName: String,
        useMapPanel: Bool,
        location: CLLocation,
        cityName: String
    ) throws {
        launchApp(useMapPanel: useMapPanel, location: location)

        let map = try locateAndVerifyMap(useMapPanel: useMapPanel)

        // 1. Mandatory verification: real stops must be loaded and rendered
        try verifyRealIsraelStopsLoaded(expectedCityLat: location.coordinate.latitude, minStops: 10)

        let initialAttachment = XCTAttachment(screenshot: app.screenshot())
        initialAttachment.name = "\(testName)_Initial_Stops_Rendered"
        initialAttachment.lifetime = .keepAlways
        add(initialAttachment)

        // 2. Scenario A: Slow Zoom In/Out (8 cycles)
        XCTContext.runActivity(named: "Scenario_A_SlowZoomInOut") { _ in
            for cycle in 1...8 {
                XCTAssertEqual(app.state, .runningForeground, "App crashed in Scenario A cycle \(cycle)")

                // Step 1: Small zoom out
                map.pinch(withScale: 0.70, velocity: 1.0)
                Thread.sleep(forTimeInterval: 0.4)

                // Step 2: Second zoom out past city threshold
                map.pinch(withScale: 0.60, velocity: 1.0)
                Thread.sleep(forTimeInterval: 0.4)

                // Step 3: Zoom out further past the 40,000 / 0.25 gate
                map.pinch(withScale: 0.50, velocity: 1.0)
                Thread.sleep(forTimeInterval: 0.5)

                let zoomedOutStatus = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) SlowZoom Cycle \(cycle) ZoomedOut] mem=\(zoomedOutStatus["memoryFootprintMB"] ?? "?")MB loaded=\(zoomedOutStatus["loadedStopsCount"] ?? "?") rendered=\(zoomedOutStatus["renderedStopsCount"] ?? "?") height=\(zoomedOutStatus["visibleMapRectHeight"] ?? "?")")

                if cycle == 1 || cycle == 8 {
                    let attach = XCTAttachment(screenshot: app.screenshot())
                    attach.name = "\(testName)_SlowZoom_Cycle\(cycle)_ZoomedOut"
                    attach.lifetime = .keepAlways
                    add(attach)
                }

                // Step 4: Zoom back in to street level
                map.pinch(withScale: 1.70, velocity: 1.0)
                Thread.sleep(forTimeInterval: 0.4)
                map.pinch(withScale: 1.60, velocity: 1.0)
                Thread.sleep(forTimeInterval: 0.4)

                let zoomedInStatus = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) SlowZoom Cycle \(cycle) ZoomedIn] mem=\(zoomedInStatus["memoryFootprintMB"] ?? "?")MB loaded=\(zoomedInStatus["loadedStopsCount"] ?? "?") rendered=\(zoomedInStatus["renderedStopsCount"] ?? "?") height=\(zoomedInStatus["visibleMapRectHeight"] ?? "?")")
            }
        }

        // 3. Scenario B: Rapid Zoom Out & Return (6 cycles)
        XCTContext.runActivity(named: "Scenario_B_RapidZoomOutAndReturn") { _ in
            for cycle in 1...6 {
                XCTAssertEqual(app.state, .runningForeground, "App crashed in Scenario B cycle \(cycle)")

                map.pinch(withScale: 0.60, velocity: 1.5)
                map.pinch(withScale: 0.60, velocity: 1.5)
                map.pinch(withScale: 0.60, velocity: 1.5)

                map.pinch(withScale: 1.60, velocity: 1.5)
                map.pinch(withScale: 1.60, velocity: 1.5)

                map.pinch(withScale: 0.60, velocity: 1.5)
                map.pinch(withScale: 1.70, velocity: 1.5)

                Thread.sleep(forTimeInterval: 0.3)
                let status = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) RapidZoom Cycle \(cycle)] mem=\(status["memoryFootprintMB"] ?? "?")MB loaded=\(status["loadedStopsCount"] ?? "?") rendered=\(status["renderedStopsCount"] ?? "?")")
            }
        }

        // 4. Scenario C: Panning in All Directions (6 cycles)
        XCTContext.runActivity(named: "Scenario_C_PanInAllDirections") { _ in
            for cycle in 1...6 {
                XCTAssertEqual(app.state, .runningForeground, "App crashed in Scenario C cycle \(cycle)")

                let centerCoord = map.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.40))
                let rightCoord = map.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.40))
                let leftCoord = map.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.40))
                let upCoord = map.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.22))
                let downCoord = map.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.58))

                // Pan Right
                centerCoord.press(forDuration: 0.05, thenDragTo: rightCoord)
                Thread.sleep(forTimeInterval: 0.2)

                // Pan Left
                centerCoord.press(forDuration: 0.05, thenDragTo: leftCoord)
                Thread.sleep(forTimeInterval: 0.2)

                // Pan Up
                centerCoord.press(forDuration: 0.05, thenDragTo: upCoord)
                Thread.sleep(forTimeInterval: 0.2)

                // Pan Down
                centerCoord.press(forDuration: 0.05, thenDragTo: downCoord)
                Thread.sleep(forTimeInterval: 0.2)

                // Combined Zoom + Pan
                map.pinch(withScale: 0.75, velocity: 1.0)
                centerCoord.press(forDuration: 0.05, thenDragTo: rightCoord)
                map.pinch(withScale: 1.35, velocity: 1.0)
                centerCoord.press(forDuration: 0.05, thenDragTo: leftCoord)

                let status = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) Pan Cycle \(cycle)] mem=\(status["memoryFootprintMB"] ?? "?")MB center=(\(status["centerLatitude"] ?? "?"),\(status["centerLongitude"] ?? "?")) loaded=\(status["loadedStopsCount"] ?? "?")")
            }
        }

        // 5. Scenario D: Continuous Pinch and Drag (6 cycles)
        XCTContext.runActivity(named: "Scenario_D_ContinuousPinchAndDrag") { _ in
            for cycle in 1...6 {
                XCTAssertEqual(app.state, .runningForeground, "App crashed in Scenario D cycle \(cycle)")

                map.pinch(withScale: 0.50, velocity: 2.0)
                let centerCoord = map.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.40))
                let rightCoord = map.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.40))
                centerCoord.press(forDuration: 0.05, thenDragTo: rightCoord)

                map.pinch(withScale: 1.80, velocity: 2.0)
                let leftCoord = map.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.40))
                centerCoord.press(forDuration: 0.05, thenDragTo: leftCoord)

                Thread.sleep(forTimeInterval: 0.3)

                let status = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) Continuous Cycle \(cycle)] mem=\(status["memoryFootprintMB"] ?? "?")MB loaded=\(status["loadedStopsCount"] ?? "?") rendered=\(status["renderedStopsCount"] ?? "?")")

                if cycle == 6 {
                    let rendered = Int(status["renderedStopsCount"] ?? "0") ?? 0
                    XCTAssertGreaterThan(rendered, 0, "Stops must reappear after returning to street zoom level")
                }
            }
        }
    }

    // MARK: - Helpers

    private func launchApp(useMapPanel: Bool, location: CLLocation) {
        XCUIDevice.shared.location = XCUILocation(location: location)

        app.launchArguments += [
            "-AppleLanguages", "(he)",
            "-AppleLocale", "he_IL",
            "-OBACurrentRegionIdentifierUserDefaultsKey", "<integer>972</integer>",
            "-OBAAutomaticallySelectRegionUserDefaultsKey", "<false/>",
            "-OBAUseMapPanelExperience", useMapPanel ? "<true/>" : "<false/>",
            "-OBAOnboardingSeenStepVersions", "<dict><key>migration</key><integer>1</integer><key>welcome</key><integer>1</integer><key>location</key><integer>1</integer><key>region</key><integer>1</integer><key>notifications</key><integer>1</integer><key>done</key><integer>1</integer></dict>"
        ]
        app.launchEnvironment["TEST_SUPPRESS_ALERT_BULLETINS"] = "1"
        app.launchEnvironment["ISRAEL_MAP_STRESS_TEST"] = "1"

        addUIInterruptionMonitor(withDescription: "Location Permission") { alert in
            for label in ["Allow Once", "Allow While Using App", "Allow While Using the App", "Allow", "OK", "אישור", "אפשר בעת שימוש ביישום", "אפשר פעם אחת"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        app.launch()
    }

    private func locateAndVerifyMap(useMapPanel: Bool = false) throws -> XCUIElement {
        if app.state != .runningForeground {
            app.activate()
        }

        // The map is the initial screen on launch (Page 0 in ClassicApplicationRootController / MapPanelRootView).
        let mapById = app.descendants(matching: .any)["oba.map.view"]
        if mapById.waitForExistence(timeout: 25) {
            return mapById
        }

        let map = app.maps.firstMatch
        if map.waitForExistence(timeout: 25) {
            return map
        }

        // Fallback: If map not immediately found, try tapping the Map tab if present
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            for label in ["Map", "מפה"] {
                let tab = tabBar.buttons[label]
                if tab.exists {
                    tab.tap()
                    break
                }
            }
        }

        XCTAssertTrue(mapById.waitForExistence(timeout: 10) || map.waitForExistence(timeout: 10), "Map element must exist on launch")
        return mapById.exists ? mapById : map
    }

    private func verifyRealIsraelStopsLoaded(expectedCityLat: Double, minStops: Int) throws {
        let probe = app.descendants(matching: .any)["israel.map.stress.status"]
        let map = app.descendants(matching: .any)["oba.map.view"]

        let deadline = Date().addingTimeInterval(35.0)
        var lastStatus: [String: String] = [:]

        while Date() < deadline {
            let rawStatus = (probe.exists ? probe.value as? String : nil) ?? (map.exists ? map.value as? String : nil)
            if let valueStr = rawStatus, !valueStr.isEmpty {
                lastStatus = parseStatus(valueStr)
                let loaded = Int(lastStatus["loadedStopsCount"] ?? "0") ?? 0
                let rendered = Int(lastStatus["renderedStopsCount"] ?? "0") ?? 0
                let catalogAvailable = lastStatus["catalogAvailable"] == "true"
                let regionID = Int(lastStatus["regionID"] ?? "0") ?? 0

                if catalogAvailable && regionID == 972 && loaded >= minStops && rendered >= 1 {
                    let provider = lastStatus["providerID"] ?? ""
                    let lat = Double(lastStatus["centerLatitude"] ?? "0") ?? 0
                    let lon = Double(lastStatus["centerLongitude"] ?? "0") ?? 0

                    XCTAssertEqual(provider, "israel-mot", "Active transit provider must be israel-mot")
                    XCTAssertEqual(regionID, 972, "Region must be 972 (Israel)")
                    XCTAssertTrue(abs(lat - expectedCityLat) < 0.35, "Map center latitude \(lat) must be near target city \(expectedCityLat)")
                    XCTAssertTrue(lon > 34.0 && lon < 36.0, "Map center longitude \(lon) must be within Israel bounds")

                    print("ISRAEL_MAP_STRESS: Verified real stops loaded successfully! provider=\(provider) region=\(regionID) loaded=\(loaded) rendered=\(rendered) center=(\(lat),\(lon))")
                    return
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTFail("Failed to load real Israel stops within timeout. Last status: \(lastStatus)")
    }

    private func readCurrentStatus(map: XCUIElement) -> [String: String] {
        let probe = app.descendants(matching: .any)["israel.map.stress.status"]
        let raw = (probe.exists ? probe.value as? String : nil) ?? (map.value as? String) ?? ""
        return parseStatus(raw)
    }

    private func parseStatus(_ text: String) -> [String: String] {
        var dict = [String: String]()
        let pairs = text.split(separator: ";")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                dict[String(parts[0])] = String(parts[1])
            }
        }
        return dict
    }
}
