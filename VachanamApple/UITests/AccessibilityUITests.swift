//
//  AccessibilityUITests.swift
//  VachanamUITests
//

import XCTest

final class AccessibilityUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testSettingsAccessibilityOptions() throws {
        let app = XCUIApplication()
        app.launch()
        
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
            XCTAssertTrue(app.staticTexts["Accessibility"].waitForExistence(timeout: 3.0))
        }
    }
}
