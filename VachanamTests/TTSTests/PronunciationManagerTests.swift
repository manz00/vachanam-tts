//
//  PronunciationManagerTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class PronunciationManagerTests: XCTestCase {
    
    func testGlobalRulesApplication() {
        let manager = PronunciationManager.shared
        let input = "The new TTS API supports PDF documents."
        let output = manager.applyPronunciations(to: input)
        XCTAssertEqual(output, "The new text to speech A P I supports P D F documents.")
    }
    
    func testMathematicalAndTechnicalProperNames() {
        let manager = PronunciationManager.shared
        let input = "The Gaussian distribution discovered by Euler was posted on arXiv."
        let output = manager.applyPronunciations(to: input)
        XCTAssertTrue(output.contains("GOW-see-an"))
        XCTAssertTrue(output.contains("Oiler"))
        XCTAssertTrue(output.contains("archive"))
    }
    
    func testUserAndBookScopeRules() {
        let manager = PronunciationManager.shared
        let docID = UUID()
        
        let bookRule = PronunciationRule(
            match: "Daenerys",
            spokenText: "duh-NAIR-iss",
            scope: .book,
            documentID: docID
        )
        manager.addRule(bookRule)
        
        let userRule = PronunciationRule(
            match: "Targaryen",
            spokenText: "tar-GAIR-ee-un",
            scope: .user
        )
        manager.addRule(userRule)
        
        let text = "Daenerys Targaryen"
        let outputForDoc = manager.applyPronunciations(to: text, documentID: docID)
        XCTAssertEqual(outputForDoc, "duh-NAIR-iss tar-GAIR-ee-un")
        
        // Another document should NOT get the book-scoped rule
        let outputOtherDoc = manager.applyPronunciations(to: text, documentID: UUID())
        XCTAssertEqual(outputOtherDoc, "Daenerys tar-GAIR-ee-un")
        
        // Clean up
        manager.removeRule(id: bookRule.id)
        manager.removeRule(id: userRule.id)
    }
}
