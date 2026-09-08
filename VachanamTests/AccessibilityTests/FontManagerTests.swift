//
//  FontManagerTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class FontManagerTests: XCTestCase {
    
    func testFontManagerResolutions() {
        let manager = FontManager.shared
        manager.selectedFont = .system
        manager.fontSize = 22.0
        
        let font = manager.resolveFont()
        XCTAssertNotNil(font)
        
        manager.selectedFont = .openDyslexic
        let dyslexiaFont = manager.resolveFont()
        XCTAssertNotNil(dyslexiaFont)
    }
}
