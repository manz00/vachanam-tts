//
//  DisplayedMathAndChunkingIntegrityTests.swift
//  VachanamTests
//
//  Verifies that displayed math equations, formula lines, superscripts, and continuation
//  clauses remain unified into natural paragraphs, preventing 1-word chunk stuttering.
//

import XCTest
import CoreGraphics
@testable import Vachanam

final class DisplayedMathAndChunkingIntegrityTests: XCTestCase {
    
    func testDisplayedEquationNotFragmentedIntoIsolatedBlocks() {
        let detector = ParagraphDetector.shared
        
        let lines: [VisualLine] = [
            VisualLine(text: "To summarize, all solutions of the linear equation system Ax = b are given by", bounds: CGRect(x: 50, y: 700, width: 450, height: 12), pageIndex: 0),
            VisualLine(text: "x = A", bounds: CGRect(x: 100, y: 676, width: 40, height: 12), pageIndex: 0),
            VisualLine(text: "−1", bounds: CGRect(x: 142, y: 680, width: 14, height: 8), pageIndex: 0),
            VisualLine(text: "b + \\lambda_1 x_1 + \\lambda_2 x_2", bounds: CGRect(x: 160, y: 676, width: 180, height: 12), pageIndex: 0),
            VisualLine(text: "where \\lambda_i are arbitrary real numbers.", bounds: CGRect(x: 50, y: 652, width: 300, height: 12), pageIndex: 0)
        ]
        
        let blocks = detector.detectParagraphs(from: lines, pageIndex: 0)
        
        XCTAssertEqual(blocks.count, 1, "Displayed formula and continuation clause must stay in one paragraph")
        let combined = blocks[0].combinedText
        XCTAssertTrue(combined.contains("are given by"), "Paragraph must contain the introductory clause")
        XCTAssertTrue(combined.contains("A−1") || combined.contains("A −1") || combined.contains("A^-1"), "Superscript must attach to A")
        XCTAssertTrue(combined.contains("arbitrary real numbers"), "Continuation line must be in the same paragraph")
    }
    
    func testTTSChunkerMergesShortNonStandaloneBlocks() {
        let chunker = TTSChunker(minWordsPerChunk: 10, targetMaxWordsPerChunk: 25, maxSentencesPerChunk: 3)
        
        // Simulating a tiny 1-word formula fragment followed by a continuation sentence across non-standalone blocks
        let s1 = SemanticSentence(
            sentenceID: 0,
            paragraphID: 0,
            blockID: 10,
            blockType: .paragraph,
            primaryPageIndex: 0,
            pageSpans: [0],
            text: "−1",
            words: [
                SemanticWord(globalWordID: 0, text: "−1", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 0, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 0, length: 2))
            ],
            lineBoundsByPage: [:],
            boundsByPage: [:]
        )
        
        let s2 = SemanticSentence(
            sentenceID: 1,
            paragraphID: 1,
            blockID: 11,
            blockType: .paragraph,
            primaryPageIndex: 0,
            pageSpans: [0],
            text: "+ lambda 2 times x 2 where all solutions are valid.",
            words: [
                SemanticWord(globalWordID: 1, text: "+", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 0, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 0, length: 1)),
                SemanticWord(globalWordID: 2, text: "lambda", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 1, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 2, length: 6)),
                SemanticWord(globalWordID: 3, text: "2", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 2, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 9, length: 1)),
                SemanticWord(globalWordID: 4, text: "times", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 3, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 11, length: 5)),
                SemanticWord(globalWordID: 5, text: "x", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 4, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 17, length: 1)),
                SemanticWord(globalWordID: 6, text: "2", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 5, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 19, length: 1)),
                SemanticWord(globalWordID: 7, text: "where", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 6, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 21, length: 5)),
                SemanticWord(globalWordID: 8, text: "all", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 7, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 27, length: 3)),
                SemanticWord(globalWordID: 9, text: "solutions", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 8, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 31, length: 9)),
                SemanticWord(globalWordID: 10, text: "are", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 9, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 41, length: 3)),
                SemanticWord(globalWordID: 11, text: "valid.", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 10, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 45, length: 6))
            ],
            lineBoundsByPage: [:],
            boundsByPage: [:]
        )
        
        let chunks = chunker.chunk(sentences: [s1, s2])
        XCTAssertEqual(chunks.count, 1, "Tiny 1-word fragment must merge with adjacent non-standalone sentence to reach minWordsPerChunk")
        XCTAssertFalse(chunks[0].text.hasPrefix(" "), "Chunk text must not start with whitespace")
    }
    
    func testTextNormalizerHandlesInverseWithoutCaretAndLeadingOperators() {
        let normalizer = TextNormalizer.shared
        
        // Inverse matrix without caret
        let normA = normalizer.normalizeForSpeech("A−1")
        XCTAssertTrue(normA.contains("inverse"), "A−1 should vocalize as inverse, got: \(normA)")
        
        let normAB = normalizer.normalizeForSpeech("(AB)−1")
        XCTAssertTrue(normAB.contains("inverse"), "(AB)−1 should vocalize as inverse, got: \(normAB)")
        
        // Leading plus operator
        let normPlus = normalizer.normalizeForSpeech("+ lambda 2")
        XCTAssertTrue(normPlus.hasPrefix("plus lambda 2"), "+ lambda 2 should vocalize with leading 'plus', got: \(normPlus)")
        
        // Leading comma
        let normComma = normalizer.normalizeForSpeech("        , equation 2.4")
        XCTAssertEqual(normComma, "equation 2.4", "Leading spaces and comma should be stripped, got: \(normComma)")
        
        // Collapsed whitespace
        let normSpaces = normalizer.normalizeForSpeech("A equals         matrix")
        XCTAssertEqual(normSpaces, "A equals matrix", "Multiple spaces must collapse to single space, got: \(normSpaces)")
    }
}
