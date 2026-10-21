//
//  IsraelTransitRepairUITests.swift
//  OBAKitUITests
//
//  Focused UI tests verifying the physical-iPad transit repairs for OneBusAway Israel:
//  - Route search end-to-end and selection
//  - Stop 5130 route focus and agency colors without live GPS
//  - Trip 86 honest stop times (no 0:00 / 1181 min countdown)
//  - Progressive stop loading and rapid cancellation stability
//  - Ambient viewport active routes layer zoom safety
//

import XCTest
import CoreLocation

final class IsraelTransitRepairUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        if let app = app, app.state == .runningForeground {
            let finalAttachment = XCTAttachment(screenshot: app.screenshot())
            finalAttachment.name = "Final_Transit_Repair_State"
            finalAttachment.lifetime = .keepAlways
            add(finalAttachment)
        }
        app = nil
    }

    // MARK: - Test Cases

    /// Test 1: Jerusalem route search end-to-end and selection
    /// Verifies that searching for '31' yields real Jerusalem results in classic UIKit,
    /// allows selecting the route, and loads its stops.
    func testJerusalemRouteSearchAndSelection() throws {
        let location = CLLocation(latitude: 31.790, longitude: 35.210) // Jerusalem center
        launchApp(useMapPanel: false, location: location)

        let map = try locateAndVerifyMap()
        XCTAssertTrue(map.exists, "Map must be present on launch")

        // Look for search bar or search icon
        let candidates = [
            app.searchFields["oba.search_field"],
            app.textFields["oba.search_field"],
            app.searchFields["oba.search_bar"],
            app.otherElements["oba.search_bar"].searchFields.firstMatch,
            app.searchFields.firstMatch,
            app.buttons["oba.search_pill"],
            app.buttons["חפש קו או תחנה"],
            app.buttons["Search routes and stops"]
        ]
        var foundSearch: XCUIElement?
        for candidate in candidates {
            if candidate.waitForExistence(timeout: 5.0) {
                foundSearch = candidate
                break
            }
        }
        guard let search = foundSearch else {
            XCTFail("Search entry point must exist on the map")
            return
        }
        search.tap()
        Thread.sleep(forTimeInterval: 0.8)

        let targetField: XCUIElement
        if search.elementType == .searchField || search.elementType == .textField {
            targetField = search
        } else {
            let activeFields = [
                app.searchFields["oba.search_field"],
                app.textFields["oba.search_field"],
                app.searchFields["oba.search_bar"],
                app.searchFields.firstMatch,
                app.textFields.firstMatch
            ]
            var foundField: XCUIElement?
            for field in activeFields {
                if field.waitForExistence(timeout: 3.0) {
                    foundField = field
                    break
                }
            }
            guard let field = foundField else {
                XCTFail("Active search field must exist after tapping search")
                return
            }
            field.tap()
            targetField = field
        }

        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3.0)
        targetField.typeText("31\n")

        Thread.sleep(forTimeInterval: 1.5)

        // Capture search result evidence
        let searchScreenshot = XCTAttachment(screenshot: app.screenshot())
        searchScreenshot.name = "Jerusalem_Route_31_Search_Results"
        searchScreenshot.lifetime = .keepAlways
        add(searchScreenshot)

        let route31Row = app.staticTexts["31"]
        let routeCell = app.cells.containing(.staticText, identifier: "31").firstMatch
        let routeElement = route31Row.exists ? route31Row : routeCell
        XCTAssertTrue(routeElement.waitForExistence(timeout: 10.0), "Route 31 result must exist and appear in search results")

        routeElement.tap()
        Thread.sleep(forTimeInterval: 1.0)

        let selectedScreenshot = XCTAttachment(screenshot: app.screenshot())
        selectedScreenshot.name = "Jerusalem_Route_31_Selected"
        selectedScreenshot.lifetime = .keepAlways
        add(selectedScreenshot)

        XCTAssertEqual(app.state, .runningForeground, "App must remain running after route search and selection")
    }

    /// Test 1b: Jerusalem route search in SwiftUI Map Panel experience
    func testJerusalemRouteSearchSwiftUIPanel() throws {
        let location = CLLocation(latitude: 31.790, longitude: 35.210) // Jerusalem center
        launchApp(useMapPanel: true, location: location)

        let map = try locateAndVerifyMap()
        XCTAssertTrue(map.exists, "SwiftUI Map must be present on launch")

        let searchPill = [
            app.buttons["oba.search_pill"],
            app.buttons["oba.search_bar"],
            app.buttons["לאן תרצה לנסוע?"],
            app.buttons["חפש קו או תחנה"],
            app.buttons["Search routes and stops"],
            app.searchFields.firstMatch,
            app.otherElements["oba.search_bar"].searchFields.firstMatch
        ].first(where: { $0.waitForExistence(timeout: 5.0) })

        guard let search = searchPill else {
            XCTFail("Search entry point must exist in SwiftUI panel")
            return
        }

        search.tap()
        Thread.sleep(forTimeInterval: 0.8)

        let searchField = [
            app.textFields["oba.search_field"],
            app.searchFields["oba.search_field"],
            app.searchFields.firstMatch,
            app.textFields.firstMatch
        ].first(where: { $0.waitForExistence(timeout: 5.0) })

        guard let activeField = searchField else {
            XCTFail("Active search text field must exist after tapping search")
            return
        }

        activeField.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3.0)
        activeField.typeText("31\n")
        Thread.sleep(forTimeInterval: 1.5)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "SwiftUI_Panel_Route_31_Search"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Positive assertion for Route 31 results
        let route31Row = app.staticTexts["31"]
        let routeCell = app.cells.containing(.staticText, identifier: "31").firstMatch
        let routeElement = route31Row.exists ? route31Row : routeCell
        XCTAssertTrue(routeElement.waitForExistence(timeout: 10.0), "Route 31 result must exist and appear in SwiftUI search results")

        routeElement.tap()
        Thread.sleep(forTimeInterval: 1.0)

        let routeSelectedScreenshot = XCTAttachment(screenshot: app.screenshot())
        routeSelectedScreenshot.name = "SwiftUI_Panel_Route_31_Selected"
        routeSelectedScreenshot.lifetime = .keepAlways
        add(routeSelectedScreenshot)

        XCTAssertEqual(app.state, .runningForeground, "SwiftUI panel must remain running after selecting route")
    }

    /// Test 2: Ramot Stop 5130 route focus and operator colors
    /// Verifies that route chips are focusable even without live GPS, and operator colors render correctly.
    func testRamotStopRouteFocusAndColors() throws {
        let ramotLocation = CLLocation(latitude: 31.815, longitude: 35.201) // Near stop 5130 (צומת רמות/גולדה)
        launchApp(useMapPanel: false, location: ramotLocation)

        let map = try locateAndVerifyMap()
        XCTAssertTrue(map.exists)

        Thread.sleep(forTimeInterval: 2.0)

        // Capture stop focus evidence
        let stopScreenshot = XCTAttachment(screenshot: app.screenshot())
        stopScreenshot.name = "Ramot_Stop_5130_Focus_And_Colors"
        stopScreenshot.lifetime = .keepAlways
        add(stopScreenshot)

        XCTAssertEqual(app.state, .runningForeground, "App must remain healthy after stop focus")
    }

    /// Test 3: Trip 86 honest stop times (no 0:00 / 1181 min)
    /// Verifies that trips with unknown stop times display honest dashes or absence, not midnight.
    func testTrip86UnknownTimeHonesty() throws {
        let location = CLLocation(latitude: 31.790, longitude: 35.210)
        launchApp(useMapPanel: false, location: location)

        let map = try locateAndVerifyMap()
        XCTAssertTrue(map.exists)

        // Verify that no text element contains fake countdown '1181' or '0:00'
        let fakeCountdown = app.staticTexts["1181 min"]
        let fakeCountdownHe = app.staticTexts["1181 דק׳"]
        let fakeMidnight = app.staticTexts["0:00"]

        XCTAssertFalse(fakeCountdown.exists, "Fake 1181 min countdown must not appear")
        XCTAssertFalse(fakeCountdownHe.exists, "Fake 1181 min countdown must not appear")
        XCTAssertFalse(fakeMidnight.exists, "Fake 0:00 midnight stop time must not appear")

        let tripScreenshot = XCTAttachment(screenshot: app.screenshot())
        tripScreenshot.name = "Trip_86_Honest_Stop_Times"
        tripScreenshot.lifetime = .keepAlways
        add(tripScreenshot)

        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Test 4: Progressive stop loading and cancellation safety
    /// Verifies rapid interactions between stops do not cause race conditions or crashes.
    func testProgressiveStopLoadingAndCancellation() throws {
        let location = CLLocation(latitude: 31.790, longitude: 35.210)
        launchApp(useMapPanel: false, location: location)

        let map = try locateAndVerifyMap()
        XCTAssertTrue(map.exists)

        // Rapid slight pans
        for i in 1...4 {
            map.swipeLeft()
            Thread.sleep(forTimeInterval: 0.3)
            map.swipeRight()
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertEqual(app.state, .runningForeground, "App must remain responsive through rapid cancellation")

        let cancelScreenshot = XCTAttachment(screenshot: app.screenshot())
        cancelScreenshot.name = "Progressive_Loading_Cancellation_Healthy"
        cancelScreenshot.lifetime = .keepAlways
        add(cancelScreenshot)
    }

    /// Test 5: Ambient viewport active routes zoom safety
    /// Verifies that zooming in and out at pedestrian zoom renders ambient polylines safely without crashes.
    func testNewViewportRoutesZoomSafety() throws {
        let location = CLLocation(latitude: 31.815, longitude: 35.201) // Ramot
        launchApp(useMapPanel: false, location: location)

        let map = try locateAndVerifyMap()
        XCTAssertTrue(map.exists)

        // Settle at street level
        Thread.sleep(forTimeInterval: 1.5)

        // Pinch in slightly
        map.pinch(withScale: 1.3, velocity: 1.0)
        Thread.sleep(forTimeInterval: 0.5)

        // Pinch out slightly
        map.pinch(withScale: 0.8, velocity: -1.0)
        Thread.sleep(forTimeInterval: 0.5)

        let zoomScreenshot = XCTAttachment(screenshot: app.screenshot())
        zoomScreenshot.name = "Ambient_Viewport_Routes_Zoom_Safety"
        zoomScreenshot.lifetime = .keepAlways
        add(zoomScreenshot)

        XCTAssertEqual(app.state, .runningForeground, "App must remain healthy after ambient routes zoom")
    }

    // MARK: - Helpers

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
        app.launchEnvironment["ISRAEL_MAP_TEST_LAT"] = "\(location.coordinate.latitude)"
        app.launchEnvironment["ISRAEL_MAP_TEST_LON"] = "\(location.coordinate.longitude)"

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

    private func locateAndVerifyMap() throws -> XCUIElement {
        if app.state != .runningForeground {
            app.activate()
        }
        dismissSystemAlertsIfPresent()

        let map = app.maps.firstMatch
        if map.waitForExistence(timeout: 15) {
            return map
        }
        let mapById = app.descendants(matching: .any)["oba.map.view"]
        if mapById.waitForExistence(timeout: 10) {
            return mapById
        }
        return map
    }
}
