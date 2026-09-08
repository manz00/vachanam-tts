//
//  TextNormalizerTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class TextNormalizerTests: XCTestCase {
    
    func testLigatureExpansion() {
        let normalizer = TextNormalizer.shared
        let input = "The \u{FB01}rst \u{FB02}ight of the e\u{FB03}cient engineer."
        let output = normalizer.normalize(input)
        XCTAssertEqual(output, "The first flight of the efficient engineer.")
    }
    
    func testSoftHyphenAndZeroWidthStripping() {
        let normalizer = TextNormalizer.shared
        let input = "prob\u{00AD}abil\u{200B}ity"
        let output = normalizer.normalize(input)
        XCTAssertEqual(output, "probability")
    }
    
    func testWhitespaceStandardization() {
        let normalizer = TextNormalizer.shared
        let input = "Line  with   multiple\u{00A0}spaces and\ttabs."
        let output = normalizer.normalize(input)
        XCTAssertEqual(output, "Line with multiple spaces and tabs.")
    }
}
