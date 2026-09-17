//
//  SemanticBlockTests.swift
//  VachanamTests
//

import XCTest
import CoreGraphics
@testable import Vachanam

final class SemanticBlockTests: XCTestCase {
    
    func testHeadingDetection() {
        let detector = ParagraphDetector.shared
        
        let lines: [VisualLine] = [
            VisualLine(text: "Chapter 1: Introduction to Intelligence", bounds: CGRect(x: 50, y: 700, width: 300, height: 22), pageIndex: 0),
            VisualLine(text: "This is the opening sentence of the chapter.", bounds: CGRect(x: 50, y: 670, width: 400, height: 14), pageIndex: 0),
            VisualLine(text: "It explains the foundational concepts of the field.", bounds: CGRect(x: 50, y: 650, width: 400, height: 14), pageIndex: 0)
        ]
        
        let blocks = detector.detectParagraphs(from: lines, pageIndex: 0)
        
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].blockType, .heading)
        XCTAssertEqual(blocks[0].level, 1)
        XCTAssertEqual(blocks[0].combinedText, "Chapter 1: Introduction to Intelligence")
        
        XCTAssertEqual(blocks[1].blockType, .paragraph)
        XCTAssertTrue(blocks[1].combinedText.contains("opening sentence"))
    }
    
    func testListItemsAndContinuationLines() {
        let detector = ParagraphDetector.shared
        
        let lines: [VisualLine] = [
            VisualLine(text: "Here is a list of features:", bounds: CGRect(x: 50, y: 700, width: 250, height: 14), pageIndex: 0),
            VisualLine(text: "• High fidelity neural speech synthesis", bounds: CGRect(x: 60, y: 680, width: 300, height: 14), pageIndex: 0),
            VisualLine(text: "  with natural prosody and inflection.", bounds: CGRect(x: 75, y: 664, width: 280, height: 14), pageIndex: 0),
            VisualLine(text: "• Synchronized real-time highlighting", bounds: CGRect(x: 60, y: 644, width: 300, height: 14), pageIndex: 0),
            VisualLine(text: "1. Numbered step one", bounds: CGRect(x: 60, y: 624, width: 200, height: 14), pageIndex: 0),
            VisualLine(text: "2. Numbered step two", bounds: CGRect(x: 60, y: 604, width: 200, height: 14), pageIndex: 0)
        ]
        
        let blocks = detector.detectParagraphs(from: lines, pageIndex: 0)
        
        // Block 0: intro paragraph
        XCTAssertEqual(blocks[0].blockType, .paragraph)
        
        // Block 1: first bullet with continuation line
        XCTAssertEqual(blocks[1].blockType, .listItem)
        XCTAssertEqual(blocks[1].marker, "•")
        XCTAssertTrue(blocks[1].combinedText.contains("natural prosody"))
        
        // Block 2: second bullet
        XCTAssertEqual(blocks[2].blockType, .listItem)
        XCTAssertEqual(blocks[2].marker, "•")
        
        // Block 3: numbered 1.
        XCTAssertEqual(blocks[3].blockType, .listItem)
        XCTAssertEqual(blocks[3].marker, "1.")
        
        // Block 4: numbered 2.
        XCTAssertEqual(blocks[4].blockType, .listItem)
        XCTAssertEqual(blocks[4].marker, "2.")
    }
}
