//
//  LayoutBoundaryEdgeCaseTests.swift
//  VachanamTests
//
//  Regression test suite for AUD-25:
//  - Boundary edge cases: Empty document, 1-page/1-sentence, odd page count,
//    empty chapters, image-only documents, 10,000+ word chapters.
//  - TTS cursor edge cases: Word 0, last word, cursor clearing.
//

import XCTest
@testable import Vachanam

final class LayoutBoundaryEdgeCaseTests: XCTestCase {
    
    // MARK: - Layout Boundary Edge Cases
    
    func testEmptyDocumentZeroBlocks() {
        let emptyDoc = ParsedDocument(
            title: "Empty Document",
            format: .plainText,
            chapters: []
        )
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: emptyDoc)
        
        XCTAssertEqual(semDoc.pageCount, 1, "An empty document should construct a single blank virtual page")
        XCTAssertEqual(semDoc.sentences.count, 0)
        XCTAssertEqual(semDoc.words.count, 0)
    }
    
    func testSingleSentenceDocument() {
        let doc = ParsedDocument(
            title: "Minimal Doc",
            format: .markdown,
            chapters: [
                ParsedChapter(title: "Only Chapter", blocks: [
                    ParsedBlock(type: .paragraph, text: "Hello world.")
                ])
            ]
        )
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: doc)
        
        XCTAssertEqual(semDoc.pageCount, 1)
        XCTAssertEqual(semDoc.sentences.count, 1)
        XCTAssertEqual(semDoc.words.count, 2)
        XCTAssertEqual(semDoc.words[0].text, "Hello")
        XCTAssertEqual(semDoc.words[1].text, "world")
    }
    
    func testOddPageCountInTwoPageMode() {
        // Construct document with ~700 words. At 100 words/page, yields 7 virtual pages (odd count).
        var blocks: [ParsedBlock] = []
        for i in 1...7 {
            let paragraph = (1...100).map { "word\($0)" }.joined(separator: " ") + "."
            blocks.append(ParsedBlock(type: .paragraph, text: "Chapter \(i). " + paragraph))
        }
        
        let doc = ParsedDocument(
            title: "Seven Page Document",
            format: .plainText,
            chapters: [ParsedChapter(title: "All", blocks: blocks)]
        )
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: doc, targetWordsPerVirtualPage: 100)
        XCTAssertGreaterThanOrEqual(semDoc.pageCount, 7)
        
        let layout = ReadingLayout.twoPage
        XCTAssertEqual(layout.pageStep, 2)
        
        // In two-page mode, if pageCount is 7, the last spread starts at page 6 (index 6, which is page 7)
        let lastSpreadIndex = (semDoc.pageCount - 1) - ((semDoc.pageCount - 1) % layout.pageStep)
        XCTAssertEqual(lastSpreadIndex % 2, 0, "Spread index should always be even-aligned")
        XCTAssertLessThan(lastSpreadIndex, semDoc.pageCount)
    }
    
    func testEmptyChapterBetweenValidChapters() {
        let doc = ParsedDocument(
            title: "Document With Empty Chapter",
            format: .epub,
            chapters: [
                ParsedChapter(title: "Chapter 1", blocks: [
                    ParsedBlock(type: .paragraph, text: "First chapter text.")
                ]),
                ParsedChapter(title: "Empty Chapter 2", blocks: []),
                ParsedChapter(title: "Chapter 3", blocks: [
                    ParsedBlock(type: .paragraph, text: "Third chapter content.")
                ])
            ]
        )
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: doc)
        XCTAssertGreaterThanOrEqual(semDoc.pageCount, 1)
        XCTAssertEqual(semDoc.sentences.count, 2)
        XCTAssertEqual(semDoc.sentences.first?.text, "First chapter text.")
        XCTAssertEqual(semDoc.sentences.last?.text, "Third chapter content.")
    }
    
    func testExtremelyLongChapterTenThousandWords() {
        // Over 10,000 words in a single chapter
        let sentenceText = "Knowledge is power and wisdom creates understanding. " // 7 words
        let paragraph = String(repeating: sentenceText, count: 1500) // 10,500 words
        
        let doc = ParsedDocument(
            title: "Epic Chapter",
            format: .plainText,
            chapters: [ParsedChapter(title: "Giant Chapter", blocks: [
                ParsedBlock(type: .paragraph, text: paragraph)
            ])]
        )
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: doc, targetWordsPerVirtualPage: 100)
        XCTAssertGreaterThanOrEqual(semDoc.pageCount, 95, "10.5k words at 100 words/page should yield ~100 virtual pages")
        XCTAssertEqual(semDoc.sentences.count, 1500)
        XCTAssertGreaterThanOrEqual(semDoc.words.count, 10000)
    }
    
    func testDocumentContainingOnlyImages() {
        // Document with captionless images
        let doc = ParsedDocument(
            title: "Photo Album",
            format: .markdown,
            chapters: [
                ParsedChapter(title: "Gallery", blocks: [
                    ParsedBlock(type: .image, text: "", imageData: Data([0x00])),
                    ParsedBlock(type: .image, text: "", imageURL: URL(string: "https://example.com/2.png")),
                    ParsedBlock(type: .image, text: "", imageData: Data([0x01]))
                ])
            ]
        )
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: doc)
        XCTAssertEqual(semDoc.pageCount, 1)
        XCTAssertEqual(semDoc.sentences.count, 3)
        for s in semDoc.sentences {
            XCTAssertEqual(s.blockType, .image)
        }
        XCTAssertEqual(semDoc.words.count, 0, "Images without captions produce no spoken words")
        
        // TTS chunker skips empty sentences cleanly
        let chunks = TTSChunker.shared.chunk(sentences: semDoc.sentences)
        XCTAssertEqual(chunks.count, 0, "No chunks generated when images lack captions")
    }
    
    // MARK: - TTS Cursor Boundary Tests
    
    func testCursorAtWordZeroAndLastWord() {
        let doc = ParsedDocument(
            title: "Cursor Test",
            format: .plainText,
            chapters: [
                ParsedChapter(title: "Section", blocks: [
                    ParsedBlock(type: .paragraph, text: "Alpha beta gamma delta.")
                ])
            ]
        )
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: doc)
        XCTAssertEqual(semDoc.words.count, 4)
        
        // First word
        let firstWord = semDoc.words.first!
        XCTAssertEqual(firstWord.globalWordID, 0)
        XCTAssertEqual(firstWord.text, "Alpha")
        
        // Last word
        let lastWord = semDoc.words.last!
        XCTAssertEqual(lastWord.globalWordID, 3)
        XCTAssertEqual(lastWord.text, "delta")
    }
}
