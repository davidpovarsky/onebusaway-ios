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

    /// Scenario 0: Fast P0 Smoke Test (Classic UIKit Map)
    /// Validates that the app boots in Jerusalem (Region 972), Onboarding does not block,
    /// accessibility hierarchy snapshot is healthy, local SQLite stops are loaded,
    /// stop annotations are rendered on MKMapView, and captures an evidence screenshot.
    func testJerusalemClassicMapSmoke() throws {
        let location = CLLocation(latitude: 31.790, longitude: 35.210)
        launchApp(useMapPanel: false, location: location)

        // 1. Accessibility Snapshot and Onboarding verification
        let onboardingTitle = app.staticTexts["Choose Region"]
        let onboardingTitleHe = app.staticTexts["בחר אזור"]
        XCTAssertFalse(onboardingTitle.exists || onboardingTitleHe.exists, "Onboarding must not block main screen when region 972 is set")

        // 2. Locate map element
        let map = try locateAndVerifyMap(useMapPanel: false)

        // 3. Verify real stops loaded and rendered
        try verifyRealIsraelStopsLoaded(expectedCityLat: 31.790, minStops: 10)

        // 4. Capture screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Jerusalem_Classic_Smoke_Stops_Rendered"
        attachment.lifetime = .keepAlways
        add(attachment)

        // 5. Read and log exact status
        let status = readCurrentStatus(map: map)
        let loaded = Int(status["loadedStopsCount"] ?? "0") ?? 0
        let rendered = Int(status["renderedStopsCount"] ?? "0") ?? 0
        let mem = status["memoryFootprintMB"] ?? "0"
        let rectH = status["visibleMapRectHeight"] ?? "0"
        print("ISRAEL_MAP_SMOKE_SUCCESS: loadedStops=\(loaded) renderedStops=\(rendered) height=\(rectH) mem=\(mem)MB")

        XCTAssertGreaterThan(loaded, 0, "Real stops must be loaded from local database")
        XCTAssertGreaterThan(rendered, 0, "Stop annotations must be rendered on MKMapView")
        XCTAssertEqual(app.state, .runningForeground, "App must remain running in foreground")
    }

    /// Scenario 1: Classic UIKit Map (MapViewController + MapRegionManager)
    /// Reproduces zoom-out / pan stress in Jerusalem with real SQLite stops and measured gestures.
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
    /// heavily stressing debounce timers, task cancellations, and tile/annotation pipelines.
    func testJerusalemRapidZoomCancellation() throws {
        let location = CLLocation(latitude: 31.790, longitude: 35.210)
        launchApp(useMapPanel: false, location: location)

        let map = try locateAndVerifyMap(useMapPanel: false)
        try verifyRealIsraelStopsLoaded(expectedCityLat: 31.790, minStops: 10)

        for cycle in 1...12 {
            XCTContext.runActivity(named: "RapidCancellation_Cycle_\(cycle)") { _ in
                XCTAssertEqual(app.state, .runningForeground, "App crashed during rapid cancellation cycle \(cycle)")

                let beforeStatus = readCurrentStatus(map: map)
                let beforeHeight = Double(beforeStatus["visibleMapRectHeight"] ?? "0") ?? 0

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

                Thread.sleep(forTimeInterval: 0.4)

                let afterStatus = readCurrentStatus(map: map)
                let afterHeight = Double(afterStatus["visibleMapRectHeight"] ?? "0") ?? 0
                let deltaH = abs(afterHeight - beforeHeight)

                print("ISRAEL_MAP_STRESS [RapidCancellation Cycle \(cycle)] deltaH=\(deltaH) mem=\(afterStatus["memoryFootprintMB"] ?? "?")MB loaded=\(afterStatus["loadedStopsCount"] ?? "?") rendered=\(afterStatus["renderedStopsCount"] ?? "?") height=\(afterHeight)")
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
                performMeasuredPinch(map: map, scale: 0.70, velocity: 1.0, activityName: "\(testName)_A_Cycle\(cycle)_ZoomOutSmall")

                // Step 2: Second zoom out past city threshold
                performMeasuredPinch(map: map, scale: 0.60, velocity: 1.0, activityName: "\(testName)_A_Cycle\(cycle)_ZoomOutThreshold")

                // Step 3: Zoom out further past the 40,000 / 0.25 gate
                let (_, _, zoomedOutStatus) = performMeasuredPinch(map: map, scale: 0.50, velocity: 1.0, activityName: "\(testName)_A_Cycle\(cycle)_ZoomOutMax")

                if cycle == 1 || cycle == 8 {
                    let attach = XCTAttachment(screenshot: app.screenshot())
                    attach.name = "\(testName)_SlowZoom_Cycle\(cycle)_ZoomedOut"
                    attach.lifetime = .keepAlways
                    add(attach)
                }

                // Step 4: Zoom back in to street level
                performMeasuredPinch(map: map, scale: 1.70, velocity: 1.0, activityName: "\(testName)_A_Cycle\(cycle)_ZoomIn1")
                performMeasuredPinch(map: map, scale: 1.60, velocity: 1.0, activityName: "\(testName)_A_Cycle\(cycle)_ZoomIn2")

                let zoomedInStatus = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) SlowZoom Cycle \(cycle) ZoomedIn] mem=\(zoomedInStatus["memoryFootprintMB"] ?? "?")MB loaded=\(zoomedInStatus["loadedStopsCount"] ?? "?") rendered=\(zoomedInStatus["renderedStopsCount"] ?? "?") height=\(zoomedInStatus["visibleMapRectHeight"] ?? "?")")
            }
        }

        // 3. Scenario B: Rapid Zoom Out & Return (6 cycles)
        XCTContext.runActivity(named: "Scenario_B_RapidZoomOutAndReturn") { _ in
            for cycle in 1...6 {
                XCTAssertEqual(app.state, .runningForeground, "App crashed in Scenario B cycle \(cycle)")

                performMeasuredPinch(map: map, scale: 0.60, velocity: 1.5, activityName: "\(testName)_B_Cycle\(cycle)_ZoomOut1")
                performMeasuredPinch(map: map, scale: 0.60, velocity: 1.5, activityName: "\(testName)_B_Cycle\(cycle)_ZoomOut2")
                performMeasuredPinch(map: map, scale: 0.60, velocity: 1.5, activityName: "\(testName)_B_Cycle\(cycle)_ZoomOut3")

                performMeasuredPinch(map: map, scale: 1.60, velocity: 1.5, activityName: "\(testName)_B_Cycle\(cycle)_ZoomIn1")
                performMeasuredPinch(map: map, scale: 1.60, velocity: 1.5, activityName: "\(testName)_B_Cycle\(cycle)_ZoomIn2")

                performMeasuredPinch(map: map, scale: 0.60, velocity: 1.5, activityName: "\(testName)_B_Cycle\(cycle)_ZoomOut4")
                performMeasuredPinch(map: map, scale: 1.70, velocity: 1.5, activityName: "\(testName)_B_Cycle\(cycle)_ZoomIn3")

                let status = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) RapidZoom Cycle \(cycle)] mem=\(status["memoryFootprintMB"] ?? "?")MB loaded=\(status["loadedStopsCount"] ?? "?") rendered=\(status["renderedStopsCount"] ?? "?")")
            }
        }

        // 4. Scenario C: Panning in All Directions (6 cycles)
        XCTContext.runActivity(named: "Scenario_C_PanInAllDirections") { _ in
            for cycle in 1...6 {
                XCTAssertEqual(app.state, .runningForeground, "App crashed in Scenario C cycle \(cycle)")

                let center = CGVector(dx: 0.50, dy: 0.40)
                let right = CGVector(dx: 0.75, dy: 0.40)
                let left = CGVector(dx: 0.25, dy: 0.40)
                let up = CGVector(dx: 0.50, dy: 0.22)
                let down = CGVector(dx: 0.50, dy: 0.58)

                // Pan Right, Left, Up, Down
                performMeasuredPan(map: map, from: center, to: right, activityName: "\(testName)_C_Cycle\(cycle)_PanRight")
                performMeasuredPan(map: map, from: center, to: left, activityName: "\(testName)_C_Cycle\(cycle)_PanLeft")
                performMeasuredPan(map: map, from: center, to: up, activityName: "\(testName)_C_Cycle\(cycle)_PanUp")
                performMeasuredPan(map: map, from: center, to: down, activityName: "\(testName)_C_Cycle\(cycle)_PanDown")

                // Combined Zoom + Pan
                performMeasuredPinch(map: map, scale: 0.75, velocity: 1.0, activityName: "\(testName)_C_Cycle\(cycle)_PinchOut")
                performMeasuredPan(map: map, from: center, to: right, activityName: "\(testName)_C_Cycle\(cycle)_PanRightCombo")
                performMeasuredPinch(map: map, scale: 1.35, velocity: 1.0, activityName: "\(testName)_C_Cycle\(cycle)_PinchIn")
                performMeasuredPan(map: map, from: center, to: left, activityName: "\(testName)_C_Cycle\(cycle)_PanLeftCombo")

                let status = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) Pan Cycle \(cycle)] mem=\(status["memoryFootprintMB"] ?? "?")MB center=(\(status["centerLatitude"] ?? "?"),\(status["centerLongitude"] ?? "?")) loaded=\(status["loadedStopsCount"] ?? "?")")
            }
        }

        // 5. Scenario D: Continuous Pinch and Drag (6 cycles)
        XCTContext.runActivity(named: "Scenario_D_ContinuousPinchAndDrag") { _ in
            for cycle in 1...6 {
                XCTAssertEqual(app.state, .runningForeground, "App crashed in Scenario D cycle \(cycle)")

                performMeasuredPinch(map: map, scale: 0.50, velocity: 2.0, activityName: "\(testName)_D_Cycle\(cycle)_PinchOut")
                performMeasuredPan(map: map, from: CGVector(dx: 0.50, dy: 0.40), to: CGVector(dx: 0.80, dy: 0.40), activityName: "\(testName)_D_Cycle\(cycle)_DragRight")

                performMeasuredPinch(map: map, scale: 1.80, velocity: 2.0, activityName: "\(testName)_D_Cycle\(cycle)_PinchIn")
                performMeasuredPan(map: map, from: CGVector(dx: 0.50, dy: 0.40), to: CGVector(dx: 0.20, dy: 0.40), activityName: "\(testName)_D_Cycle\(cycle)_DragLeft")

                let status = readCurrentStatus(map: map)
                print("ISRAEL_MAP_STRESS [\(testName) Continuous Cycle \(cycle)] mem=\(status["memoryFootprintMB"] ?? "?")MB loaded=\(status["loadedStopsCount"] ?? "?") rendered=\(status["renderedStopsCount"] ?? "?")")

                if cycle == 6 {
                    let rendered = Int(status["renderedStopsCount"] ?? "0") ?? 0
                    XCTAssertGreaterThan(rendered, 0, "Stops must reappear after returning to street zoom level")
                }
            }
        }
    }

    // MARK: - Measured Gestures Helpers

    @discardableResult
    private func performMeasuredPinch(
        map: XCUIElement,
        scale: CGFloat,
        velocity: CGFloat,
        activityName: String
    ) -> (didChange: Bool, beforeStatus: [String: String], afterStatus: [String: String]) {
        let before = readCurrentStatus(map: map)
        let beforeHeight = Double(before["visibleMapRectHeight"] ?? "0") ?? 0
        let beforeLatSpan = Double(before["latitudeSpan"] ?? "0") ?? 0

        map.pinch(withScale: scale, velocity: velocity)
        Thread.sleep(forTimeInterval: 0.5)

        let after = readCurrentStatus(map: map)
        let afterHeight = Double(after["visibleMapRectHeight"] ?? "0") ?? 0
        let afterLatSpan = Double(after["latitudeSpan"] ?? "0") ?? 0

        let heightDelta = abs(afterHeight - beforeHeight)
        let spanDelta = abs(afterLatSpan - beforeLatSpan)
        let didChange = heightDelta > 5.0 || spanDelta > 0.0005

        print("ISRAEL_MAP_GESTURE [\(activityName)] scale=\(scale) vel=\(velocity) didChange=\(didChange) " +
              "beforeHeight=\(beforeHeight) afterHeight=\(afterHeight) deltaH=\(heightDelta) " +
              "beforeSpan=\(beforeLatSpan) afterSpan=\(afterLatSpan) deltaSpan=\(spanDelta) " +
              "loadedStops=\(after["loadedStopsCount"] ?? "?") renderedStops=\(after["renderedStopsCount"] ?? "?") mem=\(after["memoryFootprintMB"] ?? "?")MB")

        return (didChange, before, after)
    }

    @discardableResult
    private func performMeasuredPan(
        map: XCUIElement,
        from: CGVector,
        to: CGVector,
        activityName: String
    ) -> (didChange: Bool, beforeStatus: [String: String], afterStatus: [String: String]) {
        let before = readCurrentStatus(map: map)
        let beforeLat = Double(before["centerLatitude"] ?? "0") ?? 0
        let beforeLon = Double(before["centerLongitude"] ?? "0") ?? 0

        let startCoord = map.coordinate(withNormalizedOffset: from)
        let endCoord = map.coordinate(withNormalizedOffset: to)
        startCoord.press(forDuration: 0.05, thenDragTo: endCoord)
        Thread.sleep(forTimeInterval: 0.4)

        let after = readCurrentStatus(map: map)
        let afterLat = Double(after["centerLatitude"] ?? "0") ?? 0
        let afterLon = Double(after["centerLongitude"] ?? "0") ?? 0

        let latDelta = abs(afterLat - beforeLat)
        let lonDelta = abs(afterLon - beforeLon)
        let didChange = latDelta > 0.0005 || lonDelta > 0.0005

        print("ISRAEL_MAP_GESTURE [\(activityName)] PAN didChange=\(didChange) " +
              "beforeCenter=(\(beforeLat),\(beforeLon)) afterCenter=(\(afterLat),\(afterLon)) " +
              "loadedStops=\(after["loadedStopsCount"] ?? "?") renderedStops=\(after["renderedStopsCount"] ?? "?") mem=\(after["memoryFootprintMB"] ?? "?")MB")

        return (didChange, before, after)
    }

    // MARK: - Launch & Verification Helpers

    private func launchApp(useMapPanel: Bool, location: CLLocation) {
        XCUIDevice.shared.location = XCUILocation(location: location)

        app.launchArguments = [
            "-AppleLanguages", "(he)",
            "-AppleLocale", "he_IL",
            "-OBACurrentRegionIdentifierUserDefaultsKey", "<integer>972</integer>",
            "-OBAAutomaticallySelectRegionUserDefaultsKey", "<false/>",
            "-OBAUseMapPanelExperience", useMapPanel ? "<true/>" : "<false/>"
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
        dismissSystemAlertsIfPresent()
    }

    private func dismissSystemAlertsIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 2.0) {
            for label in ["Allow While Using App", "Allow Once", "Allow While Using the App", "Allow", "OK", "אישור", "אפשר בעת שימוש ביישום", "אפשר פעם אחת"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    break
                }
            }
        }
    }

    private func locateAndVerifyMap(useMapPanel: Bool = false) throws -> XCUIElement {
        if app.state != .runningForeground {
            app.activate()
        }

        dismissSystemAlertsIfPresent()

        let map = app.maps.firstMatch
        if map.waitForExistence(timeout: 20) {
            return map
        }

        let mapById = app.descendants(matching: .any)["oba.map.view"]
        if mapById.waitForExistence(timeout: 10) {
            return mapById
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

        XCTAssertTrue(map.waitForExistence(timeout: 10) || mapById.waitForExistence(timeout: 10), "Map element must exist on launch")
        return map.exists ? map : mapById
    }

    private func verifyRealIsraelStopsLoaded(expectedCityLat: Double, minStops: Int) throws {
        let map = app.maps.firstMatch.exists ? app.maps.firstMatch : app.descendants(matching: .any)["oba.map.view"]
        let probe = app.descendants(matching: .any)["israel.map.stress.status"]

        let deadline = Date().addingTimeInterval(35.0)
        var lastStatus: [String: String] = [:]

        while Date() < deadline {
            let rawStatus = (map.exists ? map.value as? String : nil) ?? (probe.exists ? probe.value as? String : nil)
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
        let raw = (map.value as? String) ?? (app.descendants(matching: .any)["israel.map.stress.status"].exists ? app.descendants(matching: .any)["israel.map.stress.status"].value as? String : nil) ?? ""
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
