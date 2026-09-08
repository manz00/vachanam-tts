//
//  ReaderFlowTests.swift
//  VachanamUITests
//

import XCTest

final class ReaderFlowTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testAppLaunchAndLibraryDisplay() throws {
        let app = XCUIApplication()
        app.launch()
        
        XCTAssertTrue(app.staticTexts["Your Library"].waitForExistence(timeout: 5.0))
    }
}
