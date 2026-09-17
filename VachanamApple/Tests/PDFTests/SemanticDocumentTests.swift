//
//  SemanticDocumentTests.swift
//  VachanamTests
//

import XCTest
import PDFKit
@testable import Vachanam

final class SemanticDocumentTests: XCTestCase {
    
    private func createTestPDF() -> PDFDocument {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            let p1 = "Machine learning is a method of data analysis that automates analytical model building."
            p1.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            
            let p2 = "It is a branch of artificial intelligence based on the idea that systems can learn from data."
            p2.draw(at: CGPoint(x: 50, y: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            
            context.beginPage()
            let p3 = "Using algorithms that iteratively learn from data, machine learning allows computers to find hidden insights."
            p3.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        return PDFDocument(data: data)!
    }
    
    func testSemanticDocumentParsingAndGlobalWordIDs() {
        let pdf = createTestPDF()
        let semDoc = SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "Test Doc")
        
        XCTAssertEqual(semDoc.pageCount, 2)
        XCTAssertFalse(semDoc.sentences.isEmpty)
        XCTAssertFalse(semDoc.words.isEmpty)
        
        // Ensure global word IDs are sequential and 0-indexed
        for (idx, word) in semDoc.words.enumerated() {
            XCTAssertEqual(word.globalWordID, idx, "Word ID should be monotonic and match array index")
        }
        
        // Check lookups
        let firstWord = semDoc.words.first!
        let lookedUp = semDoc.word(id: firstWord.globalWordID)
        XCTAssertEqual(lookedUp?.text, firstWord.text)
        
        let sentence = semDoc.sentence(id: firstWord.sentenceID)
        XCTAssertNotNil(sentence)
        
        let chunk = semDoc.chunk(forWordID: firstWord.globalWordID)
        XCTAssertNotNil(chunk)
    }
    
    func testTTSChunkingWordBounds() {
        let pdf = createTestPDF()
        let semDoc = SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "Test Doc")
        
        for chunk in semDoc.chunks {
            XCTAssertFalse(chunk.text.isEmpty)
            XCTAssertFalse(chunk.sentenceIDs.isEmpty)
            XCTAssertFalse(chunk.wordIDs.isEmpty)
            XCTAssertGreaterThan(chunk.estimatedDuration, 0)
        }
    }
    
    func testFindWordSpatialHitTesting() {
        let pdf = createTestPDF()
        let semDoc = SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "Test Doc")
        
        guard let firstWord = semDoc.words(forPageIndex: 0).first else {
            XCTFail("Should have words on page 0")
            return
        }
        
        // Exact center hit
        let centerPoint = CGPoint(x: firstWord.bounds.midX, y: firstWord.bounds.midY)
        let exactMatch = semDoc.findWord(at: centerPoint, onPageIndex: 0)
        XCTAssertEqual(exactMatch?.globalWordID, firstWord.globalWordID)
        
        // Padded hit test (5 points outside bounds)
        let nearPoint = CGPoint(x: firstWord.bounds.maxX + 4.0, y: firstWord.bounds.midY)
        let nearMatch = semDoc.findWord(at: nearPoint, onPageIndex: 0)
        XCTAssertNotNil(nearMatch)
        
        // Fallback radius hit test (20 points outside bounds)
        let fallbackPoint = CGPoint(x: firstWord.bounds.maxX + 18.0, y: firstWord.bounds.midY)
        let fallbackMatch = semDoc.findWord(at: fallbackPoint, onPageIndex: 0, hitPadding: 6.0, maxSearchRadius: 30.0)
        XCTAssertNotNil(fallbackMatch)
        
        // Far point should return nil
        let farPoint = CGPoint(x: 1000, y: 1000)
        let farMatch = semDoc.findWord(at: farPoint, onPageIndex: 0)
        XCTAssertNil(farMatch)
    }
}

