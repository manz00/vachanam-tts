//
//  WordReconstructorTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class WordReconstructorTests: XCTestCase {
    
    func testLineBreakHyphenRemovalForStandardWords() {
        let reconstructor = WordReconstructor.shared
        
        let result1 = reconstructor.resolveHyphenation(firstPart: "probabil-", secondPart: "ity")
        XCTAssertEqual(result1.reconstructedWord, "probability")
        XCTAssertTrue(result1.wasHyphenJoined)
        XCTAssertFalse(result1.preservedHyphen)
        
        let result2 = reconstructor.resolveHyphenation(firstPart: "algo-", secondPart: "rithm")
        XCTAssertEqual(result2.reconstructedWord, "algorithm")
        XCTAssertTrue(result2.wasHyphenJoined)
        
        let result3 = reconstructor.resolveHyphenation(firstPart: "compu-", secondPart: "tation")
        XCTAssertEqual(result3.reconstructedWord, "computation")
        XCTAssertTrue(result3.wasHyphenJoined)
    }
    
    func testLegitimateHyphenPreservationForCompoundWords() {
        let reconstructor = WordReconstructor.shared
        
        let result1 = reconstructor.resolveHyphenation(firstPart: "well-", secondPart: "known")
        XCTAssertEqual(result1.reconstructedWord, "well-known")
        XCTAssertTrue(result1.preservedHyphen)
        
        let result2 = reconstructor.resolveHyphenation(firstPart: "user-", secondPart: "friendly")
        XCTAssertEqual(result2.reconstructedWord, "user-friendly")
        XCTAssertTrue(result2.preservedHyphen)
    }
    
    func testNonHyphenatedSeparatedWords() {
        let reconstructor = WordReconstructor.shared
        let result = reconstructor.resolveHyphenation(firstPart: "machine", secondPart: "learning")
        XCTAssertEqual(result.reconstructedWord, "machine learning")
        XCTAssertFalse(result.wasHyphenJoined)
    }
}
