//
//  PageFurnitureDetectorTests.swift
//  VachanamTests
//
//  Unit tests for PageFurnitureDetector and reading intelligence classification.
//

import XCTest
import CoreGraphics
@testable import Vachanam

final class PageFurnitureDetectorTests: XCTestCase {
    
    func testPageNumberDetection() {
        let detector = PageFurnitureDetector.shared
        
        XCTAssertTrue(detector.isPageNumber("42"))
        XCTAssertTrue(detector.isPageNumber("1"))
        XCTAssertTrue(detector.isPageNumber("  100  "))
        XCTAssertTrue(detector.isPageNumber("Page 5"))
        XCTAssertTrue(detector.isPageNumber("PAGE 12"))
        XCTAssertTrue(detector.isPageNumber("Page 3 of 50"))
        XCTAssertTrue(detector.isPageNumber("Page 4 / 20"))
        XCTAssertTrue(detector.isPageNumber("- 42 -"))
        XCTAssertTrue(detector.isPageNumber("[12]"))
        XCTAssertTrue(detector.isPageNumber("(7)"))
        XCTAssertTrue(detector.isPageNumber("iv"))
        XCTAssertTrue(detector.isPageNumber("XII"))
        XCTAssertTrue(detector.isPageNumber("1-15"))
        XCTAssertTrue(detector.isPageNumber("Chapter 2 - 4"))
        
        XCTAssertFalse(detector.isPageNumber("This is a regular sentence."))
        XCTAssertFalse(detector.isPageNumber("In 2024, the team achieved remarkable breakthroughs."))
    }
    
    func testCaptionDetection() {
        let detector = PageFurnitureDetector.shared
        
        XCTAssertTrue(detector.isCaption("Figure 1: Neural network pipeline overview."))
        XCTAssertTrue(detector.isCaption("Fig. 3.2: Architecture diagram of TTS synthesizer."))
        XCTAssertTrue(detector.isCaption("Table 4: Evaluation benchmark results."))
        XCTAssertTrue(detector.isCaption("Chart 2. Distribution of audio quality metrics."))
        XCTAssertTrue(detector.isCaption("Photo 1. Historic laboratory."))
        
        XCTAssertFalse(detector.isCaption("Figure it out before tomorrow."))
        XCTAssertFalse(detector.isCaption("We placed the vase on the table."))
    }
    
    func testHeaderAndFooterZoneClassification() {
        let detector = PageFurnitureDetector.shared
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        // Line in top 5% (header zone)
        let headerLine = VisualLine(
            text: "Chapter 4 — The Architecture of Neural Attention",
            bounds: CGRect(x: 54, y: 750, width: 350, height: 12),
            pageIndex: 0
        )
        let headerType = detector.classifyLine(line: headerLine, pageBounds: pageBounds)
        XCTAssertEqual(headerType, .pageHeader)
        
        // Standalone page number in header zone
        let headerPageNum = VisualLine(
            text: "42",
            bounds: CGRect(x: 550, y: 750, width: 20, height: 12),
            pageIndex: 0
        )
        let pageNumType = detector.classifyLine(line: headerPageNum, pageBounds: pageBounds)
        XCTAssertEqual(pageNumType, .pageNumber)
        
        // Line in bottom 5% (footer zone)
        let footerLine = VisualLine(
            text: "Advances in Neural Information Processing Systems",
            bounds: CGRect(x: 54, y: 30, width: 300, height: 11),
            pageIndex: 0
        )
        let footerType = detector.classifyLine(line: footerLine, pageBounds: pageBounds)
        XCTAssertEqual(footerType, .pageFooter)
        
        // Line in middle of page (body text)
        let bodyLine = VisualLine(
            text: "The quick brown fox jumps over the lazy dog.",
            bounds: CGRect(x: 54, y: 400, width: 400, height: 14),
            pageIndex: 0
        )
        let bodyType = detector.classifyLine(line: bodyLine, pageBounds: pageBounds)
        XCTAssertNil(bodyType)
    }
    
    func testSentenceEndingColonOrContinuationNotClassifiedAsFooter() {
        let detector = PageFurnitureDetector.shared
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        // Line in bottom margin (e.g. y: 65, relY: ~0.08) ending with a colon or lowercase continuation
        let colonLine = VisualLine(
            text: "row echelon form (the reduced row-echelon form is unnecessary here):",
            bounds: CGRect(x: 54, y: 65, width: 450, height: 12),
            pageIndex: 0
        )
        let colonClassified = detector.classifyLine(line: colonLine, pageBounds: pageBounds)
        XCTAssertNil(colonClassified, "A sentence ending with a colon must not be classified as a page footer")
        
        // Lowercase continuation line in bottom margin
        let lowercaseLine = VisualLine(
            text: "vectors as columns of a matrix A and perform elimination.",
            bounds: CGRect(x: 54, y: 55, width: 400, height: 12),
            pageIndex: 0
        )
        let lowercaseClassified = detector.classifyLine(line: lowercaseLine, pageBounds: pageBounds)
        XCTAssertNil(lowercaseClassified, "A lowercase sentence continuation line must not be classified as a page footer")
    }
    
    func testCrossPageRepetitionDetection() {
        let detector = PageFurnitureDetector.shared
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let pageBoundsMap: [Int: CGRect] = [0: pageBounds, 1: pageBounds, 2: pageBounds]
        
        let linesPage0 = [
            VisualLine(text: "Handbook of Speech Synthesis", bounds: CGRect(x: 54, y: 750, width: 250, height: 12), pageIndex: 0),
            VisualLine(text: "Body text on page zero.", bounds: CGRect(x: 54, y: 400, width: 300, height: 14), pageIndex: 0),
            VisualLine(text: "1", bounds: CGRect(x: 300, y: 30, width: 10, height: 12), pageIndex: 0)
        ]
        
        let linesPage1 = [
            VisualLine(text: "Handbook of Speech Synthesis", bounds: CGRect(x: 54, y: 750, width: 250, height: 12), pageIndex: 1),
            VisualLine(text: "Body text on page one.", bounds: CGRect(x: 54, y: 400, width: 300, height: 14), pageIndex: 1),
            VisualLine(text: "2", bounds: CGRect(x: 300, y: 30, width: 10, height: 12), pageIndex: 1)
        ]
        
        let linesPage2 = [
            VisualLine(text: "Handbook of Speech Synthesis", bounds: CGRect(x: 54, y: 750, width: 250, height: 12), pageIndex: 2),
            VisualLine(text: "Body text on page two.", bounds: CGRect(x: 54, y: 400, width: 300, height: 14), pageIndex: 2),
            VisualLine(text: "3", bounds: CGRect(x: 300, y: 30, width: 10, height: 12), pageIndex: 2)
        ]
        
        let docLines: [Int: [VisualLine]] = [0: linesPage0, 1: linesPage1, 2: linesPage2]
        let analysis = detector.analyzeDocument(linesByPage: docLines, pageBounds: pageBoundsMap)
        
        XCTAssertTrue(analysis.recurringHeaders.contains("handbook of speech synthesis"))
        
        // Classify recurring header on page 1 with analysis context
        let candidate = VisualLine(text: "Handbook of Speech Synthesis", bounds: CGRect(x: 54, y: 750, width: 250, height: 12), pageIndex: 1)
        let classified = detector.classifyLine(line: candidate, pageBounds: pageBounds, analysis: analysis)
        XCTAssertEqual(classified, .pageHeader)
    }
    
    func testParagraphDetectorWithFurniture() {
        let detector = ParagraphDetector.shared
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        let lines: [VisualLine] = [
            // Page header
            VisualLine(text: "Vachanam Manual — Section 1", bounds: CGRect(x: 54, y: 755, width: 200, height: 12), pageIndex: 0),
            // Heading
            VisualLine(text: "Chapter 1: Getting Started", bounds: CGRect(x: 54, y: 680, width: 300, height: 22), pageIndex: 0),
            // Body paragraph
            VisualLine(text: "This is the primary body text of the document.", bounds: CGRect(x: 54, y: 640, width: 400, height: 14), pageIndex: 0),
            VisualLine(text: "It explains the foundational concepts.", bounds: CGRect(x: 54, y: 620, width: 400, height: 14), pageIndex: 0),
            // Caption
            VisualLine(text: "Figure 1: Audio player interface.", bounds: CGRect(x: 54, y: 450, width: 250, height: 13), pageIndex: 0),
            // Page number at bottom
            VisualLine(text: "42", bounds: CGRect(x: 300, y: 25, width: 20, height: 12), pageIndex: 0)
        ]
        
        let blocks = detector.detectParagraphs(from: lines, pageIndex: 0, pageBounds: pageBounds)
        
        XCTAssertEqual(blocks.count, 5)
        XCTAssertEqual(blocks[0].blockType, .pageHeader)
        XCTAssertEqual(blocks[1].blockType, .heading)
        XCTAssertEqual(blocks[2].blockType, .paragraph)
        XCTAssertEqual(blocks[3].blockType, .caption)
        XCTAssertEqual(blocks[4].blockType, .pageNumber)
    }
    
    private func makeSentence(id: Int, blockType: BlockType, text: String) -> SemanticSentence {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let semanticWords = words.enumerated().map { index, word in
            SemanticWord(
                globalWordID: id * 100 + index,
                text: word,
                originalText: word,
                pageIndex: 0,
                sentenceID: id,
                wordIndexInSentence: index,
                bounds: CGRect(x: 0, y: 0, width: 20, height: 10),
                sentenceRange: NSRange(location: 0, length: word.count),
                isHyphenatedBreak: false
            )
        }
        return SemanticSentence(
            sentenceID: id,
            paragraphID: id,
            blockID: id,
            blockType: blockType,
            primaryPageIndex: 0,
            pageSpans: [0],
            text: text,
            words: semanticWords,
            lineBoundsByPage: [0: [CGRect(x: 0, y: 0, width: 200, height: 10)]],
            boundsByPage: [0: CGRect(x: 0, y: 0, width: 200, height: 10)]
        )
    }
    
    func testTTSChunkerSkippingFurniture() {
        let chunker = TTSChunker.shared
        
        let s0 = makeSentence(id: 0, blockType: .pageHeader, text: "Header text to skip.")
        let s1 = makeSentence(id: 1, blockType: .paragraph, text: "This is important narrative content to be read aloud.")
        let s2 = makeSentence(id: 2, blockType: .pageNumber, text: "42")
        
        // Chunk with default furniture skip list [.pageHeader, .pageFooter, .pageNumber]
        let chunks = chunker.chunk(sentences: [s0, s1, s2])
        
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].blockType, BlockType.paragraph)
        XCTAssertTrue(chunks[0].text.contains("narrative content"))
        XCTAssertFalse(chunks[0].text.contains("Header"))
        XCTAssertFalse(chunks[0].text.contains("42"))
    }
    
    func testAcademicPublicationNoticeInFooterZone() {
        let detector = PageFurnitureDetector.shared
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        let disclaimerText = "This material is published by Cambridge University Press. This pre-publication version is free to view and download for personal use only."
        XCTAssertTrue(detector.isPublicationDisclaimer(disclaimerText))
        
        // Placed in bottom 15% (e.g. y = 90)
        let footerLine = VisualLine(
            text: disclaimerText,
            bounds: CGRect(x: 54, y: 90, width: 500, height: 20),
            pageIndex: 0
        )
        let classified = detector.classifyLine(line: footerLine, pageBounds: pageBounds)
        XCTAssertEqual(classified, .pageFooter)
    }
    
    func testRomanNumeralAndHeaderZoneTitles() {
        let detector = PageFurnitureDetector.shared
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let pageBoundsMap: [Int: CGRect] = [0: pageBounds, 1: pageBounds]
        
        let lines0 = [
            VisualLine(text: "ii Contents", bounds: CGRect(x: 54, y: 720, width: 100, height: 14), pageIndex: 0),
            VisualLine(text: "Body text on page ii.", bounds: CGRect(x: 54, y: 500, width: 300, height: 14), pageIndex: 0)
        ]
        let lines1 = [
            VisualLine(text: "iii Contents", bounds: CGRect(x: 54, y: 720, width: 100, height: 14), pageIndex: 1),
            VisualLine(text: "Body text on page iii.", bounds: CGRect(x: 54, y: 500, width: 300, height: 14), pageIndex: 1)
        ]
        
        let analysis = detector.analyzeDocument(linesByPage: [0: lines0, 1: lines1], pageBounds: pageBoundsMap)
        XCTAssertTrue(analysis.recurringHeaders.contains("contents"))
        
        let classified = detector.classifyLine(line: lines0[0], pageBounds: pageBounds, analysis: analysis)
        XCTAssertEqual(classified, .pageHeader)
    }
    
    func testParagraphTrailingLinePreservedInFooterZone() {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        let lines: [VisualLine] = [
            VisualLine(
                text: "▪ A practical way of checking whether vectors x1, ..., xk in V are linearly",
                bounds: CGRect(x: 54, y: 120, width: 450, height: 12),
                pageIndex: 47
            ),
            VisualLine(
                text: "independent is to use Gaussian elimination: Write all vectors as columns",
                bounds: CGRect(x: 68, y: 105, width: 436, height: 12),
                pageIndex: 47
            ),
            VisualLine(
                text: "of a matrix A and perform Gaussian elimination until the matrix is in",
                bounds: CGRect(x: 68, y: 90, width: 436, height: 12),
                pageIndex: 47
            ),
            VisualLine(
                text: "row echelon form (the reduced row-echelon form is unnecessary here):",
                bounds: CGRect(x: 68, y: 75, width: 436, height: 12),
                pageIndex: 47
            ),
            VisualLine(
                text: "©2024 M. P. Deisenroth, A. A. Faisal, C. S. Ong. Published by Cambridge University Press (2020).",
                bounds: CGRect(x: 54, y: 35, width: 500, height: 12),
                pageIndex: 47
            )
        ]
        
        let paragraphs = ParagraphDetector.shared.detectParagraphs(
            from: lines,
            pageIndex: 47,
            pageBounds: pageBounds,
            analysis: nil
        )
        
        // We expect two blocks: the 4-line list item and the copyright footer
        XCTAssertEqual(paragraphs.count, 2)
        let listItem = paragraphs[0]
        XCTAssertEqual(listItem.blockType, .listItem)
        XCTAssertEqual(listItem.lines.count, 4)
        XCTAssertTrue(listItem.combinedText.contains("row echelon form"))
        
        let footer = paragraphs[1]
        XCTAssertEqual(footer.blockType, .pageFooter)
        XCTAssertTrue(footer.combinedText.contains("Cambridge University Press"))
    }
}

