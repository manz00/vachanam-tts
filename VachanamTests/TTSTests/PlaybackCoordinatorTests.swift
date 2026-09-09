//
//  PlaybackCoordinatorTests.swift
//  VachanamTests
//

import XCTest
import PDFKit
@testable import Vachanam

final class PlaybackCoordinatorTests: XCTestCase {
    
    private func createTestSemanticDocument() -> SemanticDocument {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            let p1 = "First sentence of the first paragraph. Second sentence follows immediately."
            p1.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            
            context.beginPage()
            let p2 = "Third sentence on the second page. Fourth sentence finishes the text."
            p2.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        let pdf = PDFDocument(data: data)!
        return SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "Coordinator Test")
    }
    
    func testLoadingDocumentSetsInitialState() {
        let doc = createTestSemanticDocument()
        let coordinator = PlaybackCoordinator.shared
        
        coordinator.loadDocument(doc)
        
        XCTAssertEqual(coordinator.activeSemanticDocument?.title, "Coordinator Test")
        XCTAssertEqual(coordinator.currentSentenceID, 0)
        XCTAssertNotNil(coordinator.currentWordID)
        XCTAssertNotNil(coordinator.currentChunkID)
    }
    
    func testWordBoundingBoxesAreNonZero() {
        let doc = createTestSemanticDocument()
        XCTAssertFalse(doc.words.isEmpty, "Document must have words")
        
        for word in doc.words {
            XCTAssertGreaterThan(word.bounds.width, 0, "Word '\(word.text)' must have positive width")
            XCTAssertGreaterThan(word.bounds.height, 0, "Word '\(word.text)' must have positive height")
        }
    }
    
    func testVisiblePagePlayDoesNotResetToPageZero() {
        let doc = createTestSemanticDocument()
        let coordinator = PlaybackCoordinator.shared
        coordinator.loadDocument(doc)
        
        // User navigates to page 1 (second page) without selecting a word
        coordinator.setVisiblePageIndex(1)
        
        // When play() is invoked, it must resolve to page 1's first word, NOT page 0
        coordinator.play()
        
        guard let cursor = coordinator.cursor else {
            XCTFail("Cursor should be set")
            return
        }
        
        XCTAssertEqual(cursor.pageIndex, 1, "Playback must start on page 1 when user is viewing page 1")
        coordinator.stop()
    }
    
    func testSinglePageScopeStopsAtPageBoundary() {
        let doc = createTestSemanticDocument()
        let coordinator = PlaybackCoordinator.shared
        coordinator.loadDocument(doc)
        
        coordinator.play(page: 0)
        XCTAssertTrue(coordinator.scope.isPageOnly)
        XCTAssertEqual(coordinator.scope.targetPageIndex, 0)
        
        coordinator.stop()
    }
    
    func testJumpToGlobalWordAcrossPages() {
        let doc = createTestSemanticDocument()
        let coordinator = PlaybackCoordinator.shared
        coordinator.loadDocument(doc)
        
        // Find a word that is on page 1 (second page)
        let page1Words = doc.words(forPageIndex: 1)
        guard let targetWord = page1Words.first else {
            XCTFail("Should have words on page 1")
            return
        }
        
        var receivedPage: Int?
        coordinator.onPageChanged = { page in
            receivedPage = page
        }
        
        coordinator.play(fromWordID: targetWord.globalWordID)
        
        XCTAssertEqual(coordinator.currentWordID, targetWord.globalWordID)
        XCTAssertEqual(coordinator.currentSentenceID, targetWord.sentenceID)
        XCTAssertEqual(receivedPage, 1, "Should notify page change to page 1")
        coordinator.stop()
    }
    
    func testRequestIDTokenInvalidationOnNewAction() {
        let doc = createTestSemanticDocument()
        let coordinator = PlaybackCoordinator.shared
        coordinator.loadDocument(doc)
        
        guard let word1 = doc.words.first, doc.words.count > 5 else {
            XCTFail("Need words in doc")
            return
        }
        let word2 = doc.words[5]
        
        coordinator.play(fromWordID: word1.globalWordID)
        let token1 = coordinator.currentRequestID
        
        coordinator.play(fromWordID: word2.globalWordID)
        let token2 = coordinator.currentRequestID
        
        XCTAssertNotEqual(token1, token2, "New selection must invalidate previous request token")
        XCTAssertEqual(coordinator.currentWordID, word2.globalWordID)
        coordinator.stop()
    }
    
    func testTapToSpeakImmediateCursorUpdateAndAudioHalting() {
        let doc = createTestSemanticDocument()
        let coordinator = PlaybackCoordinator.shared
        coordinator.loadDocument(doc)
        
        guard doc.words.count > 3 else {
            XCTFail("Need at least 4 words in test document")
            return
        }
        
        let targetWord = doc.words[3]
        coordinator.play(fromWordID: targetWord.globalWordID)
        
        // Assert cursor and current word immediately match the tapped word
        XCTAssertEqual(coordinator.currentWordID, targetWord.globalWordID)
        XCTAssertEqual(coordinator.currentSentenceID, targetWord.sentenceID)
        XCTAssertEqual(coordinator.cursor?.globalWordID, targetWord.globalWordID)
        
        coordinator.stop()
    }
}

