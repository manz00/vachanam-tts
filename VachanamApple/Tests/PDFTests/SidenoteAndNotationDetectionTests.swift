//
//  SidenoteAndNotationDetectionTests.swift
//  VachanamTests
//
//  Unit tests for margin column (sidenote) layout separation,
//  table of symbols page detection, and draft footer regex expansion.
//

import XCTest
@testable import Vachanam

final class SidenoteAndNotationDetectionTests: XCTestCase {
    
    func testDraftFooterDetection() {
        let draftFooterText = "Draft (2024-01-15) of \"Mathematics for Machine Learning\". Feedback: https://mml-book.com."
        let line = VisualLine(
            text: draftFooterText,
            bounds: CGRect(x: 50, y: 30, width: 500, height: 12),
            pageIndex: 0
        )
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        let classified = PageFurnitureDetector.shared.classifyLine(
            line: line,
            pageBounds: pageBounds,
            analysis: nil,
            medianLineHeight: 12.0
        )
        
        XCTAssertEqual(classified, .pageFooter, "Expected draft footer to be classified as .pageFooter")
    }
    
    func testNotationPageDetection() {
        let lines: [VisualLine] = [
            VisualLine(
                text: "Table of Symbols",
                bounds: CGRect(x: 50, y: 720, width: 200, height: 24),
                pageIndex: 2
            ),
            VisualLine(
                text: "x, y, z     Vectors in real space",
                bounds: CGRect(x: 50, y: 650, width: 300, height: 14),
                pageIndex: 2
            )
        ]
        let pageBounds: [Int: CGRect] = [2: CGRect(x: 0, y: 0, width: 612, height: 792)]
        
        let analysis = PageFurnitureDetector.shared.analyzeDocument(
            linesByPage: [2: lines],
            pageBounds: pageBounds
        )
        
        XCTAssertTrue(analysis.notationPages.contains(2), "Expected page 2 to be detected as a notation page")
        
        // When ParagraphDetector runs on a notation page, non-heading blocks should have blockType == .symbolTable
        let paragraphs = ParagraphDetector.shared.detectParagraphs(
            from: lines,
            pageIndex: 2,
            pageBounds: pageBounds[2]!,
            analysis: analysis
        )
        
        let bodyBlocks = paragraphs.filter { $0.blockType != .heading }
        XCTAssertFalse(bodyBlocks.isEmpty)
        XCTAssertEqual(bodyBlocks.first?.blockType, .symbolTable, "Expected body block on notation page to be .symbolTable")
    }
    
    func testMarginColumnSeparation() {
        // Create a simulated page like MML Page 18:
        // Margin notes: x in [35, 175] (width 140)
        // Main body text: x in [220, 540] (width 320)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        let lines: [VisualLine] = [
            // Margin note lines
            VisualLine(
                text: "Pavel Grinfeld video lecture",
                bounds: CGRect(x: 40, y: 650, width: 130, height: 11),
                pageIndex: 18
            ),
            VisualLine(
                text: "See chapter 2 for linear algebra basics",
                bounds: CGRect(x: 40, y: 635, width: 130, height: 11),
                pageIndex: 18
            ),
            // Main body lines
            VisualLine(
                text: "A system of linear equations can be compactly represented in matrix form.",
                bounds: CGRect(x: 220, y: 680, width: 330, height: 14),
                pageIndex: 18
            ),
            VisualLine(
                text: "We consider vectors x and y belonging to the real coordinate space.",
                bounds: CGRect(x: 220, y: 660, width: 330, height: 14),
                pageIndex: 18
            ),
            VisualLine(
                text: "The matrix transformation maps any input vector linearly.",
                bounds: CGRect(x: 220, y: 640, width: 330, height: 14),
                pageIndex: 18
            )
        ]
        
        let paragraphs = ParagraphDetector.shared.detectParagraphs(
            from: lines,
            pageIndex: 18,
            pageBounds: pageBounds,
            analysis: nil
        )
        
        let sidenoteBlocks = paragraphs.filter { $0.blockType == .sidenote }
        let mainBodyBlocks = paragraphs.filter { $0.blockType == .paragraph }
        
        XCTAssertFalse(sidenoteBlocks.isEmpty, "Expected margin notes to be separated into .sidenote blocks")
        XCTAssertFalse(mainBodyBlocks.isEmpty, "Expected main text to be in .paragraph blocks")
        
        // Ensure main body text does not contain the margin note text
        let mainText = mainBodyBlocks.map { $0.combinedText }.joined(separator: " ")
        XCTAssertFalse(mainText.contains("Pavel Grinfeld"), "Margin note text must not be merged into main body text")
        XCTAssertTrue(mainText.contains("compactly represented in matrix form"))
    }
}
