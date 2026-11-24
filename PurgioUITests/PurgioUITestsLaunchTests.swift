//
//  PurgioUITestsLaunchTests.swift
//  PurgioUITests
//
//  Smoke test for the UI test target: the app launches in `-uiTesting` mode and shows its tabs.
//  The launch helper and screen objects come with the UI test flows.
//

import XCTest

final class PurgioUITestsLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesInUITestingMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }
}
