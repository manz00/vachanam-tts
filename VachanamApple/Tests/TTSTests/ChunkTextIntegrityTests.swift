//
//  ChunkTextIntegrityTests.swift
//  VachanamTests
//
//  Verifies that TTSChunker preserves inter-sentence spacing cleanly without duplicate spaces
//  or stray whitespace.
//

import XCTest
@testable import Vachanam

final class ChunkTextIntegrityTests: XCTestCase {
    
    func testChunkTextJoinsWithSingleCleanSpace() {
        let chunker = TTSChunker(minWordsPerChunk: 5, targetMaxWordsPerChunk: 30, maxSentencesPerChunk: 2)
        
        let s1 = SemanticSentence(
            sentenceID: 0,
            paragraphID: 0,
            blockID: 0,
            blockType: .paragraph,
            primaryPageIndex: 0,
            pageSpans: [0],
            text: "First sentence ends here.  \n",
            words: [
                SemanticWord(globalWordID: 0, text: "First", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 0, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 0, length: 5)),
                SemanticWord(globalWordID: 1, text: "sentence", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 1, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 6, length: 8)),
                SemanticWord(globalWordID: 2, text: "ends", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 2, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 15, length: 4)),
                SemanticWord(globalWordID: 3, text: "here", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 3, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 20, length: 4))
            ],
            lineBoundsByPage: [:],
            boundsByPage: [:]
        )
        
        let s2 = SemanticSentence(
            sentenceID: 1,
            paragraphID: 0,
            blockID: 0,
            blockType: .paragraph,
            primaryPageIndex: 0,
            pageSpans: [0],
            text: "   Second sentence begins immediately.",
            words: [
                SemanticWord(globalWordID: 4, text: "Second", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 0, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 0, length: 6)),
                SemanticWord(globalWordID: 5, text: "sentence", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 1, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 7, length: 8)),
                SemanticWord(globalWordID: 6, text: "begins", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 2, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 16, length: 6)),
                SemanticWord(globalWordID: 7, text: "immediately", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 3, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 23, length: 11))
            ],
            lineBoundsByPage: [:],
            boundsByPage: [:]
        )
        
        let chunks = chunker.chunk(sentences: [s1, s2])
        XCTAssertEqual(chunks.count, 1, "Expected 1 chunk for two short sentences")
        
        guard let chunk = chunks.first else { return }
        XCTAssertEqual(chunk.text, "First sentence ends here. Second sentence begins immediately.")
        XCTAssertFalse(chunk.text.contains("  "), "Chunk text must not contain double spaces")
        XCTAssertFalse(chunk.text.hasPrefix(" "), "Chunk text must not start with whitespace")
        XCTAssertFalse(chunk.text.hasSuffix(" "), "Chunk text must not end with whitespace")
    }
}
