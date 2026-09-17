//
//  ModelManagementTests.swift
//  VachanamUITests
//

import XCTest

final class ModelManagementTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testModelListInspection() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Open models sheet if available
        let brainButton = app.buttons["TTS Neural Models"]
        if brainButton.exists {
            brainButton.tap()
            XCTAssertTrue(app.staticTexts["Kokoro"].waitForExistence(timeout: 3.0))
        }
    }
}
