//
//  TTSChunkerQualityTests.swift
//  VachanamTests
//

import XCTest
import CoreGraphics
@testable import Vachanam

final class TTSChunkerQualityTests: XCTestCase {
    
    private func makeSentence(id: Int, blockID: Int, blockType: BlockType, text: String) -> SemanticSentence {
        let words = text.components(separatedBy: .whitespaces).enumerated().map { (index, w) in
            SemanticWord(
                globalWordID: id * 100 + index,
                text: w,
                pageIndex: 0,
                sentenceID: id,
                wordIndexInSentence: index,
                bounds: CGRect(x: 0, y: 0, width: 20, height: 10),
                sentenceRange: NSRange(location: 0, length: w.count)
            )
        }
        return SemanticSentence(
            sentenceID: id,
            paragraphID: blockID,
            blockID: blockID,
            blockType: blockType,
            primaryPageIndex: 0,
            pageSpans: [0],
            text: text,
            words: words,
            lineBoundsByPage: [0: [CGRect(x: 0, y: 0, width: 200, height: 10)]],
            boundsByPage: [0: CGRect(x: 0, y: 0, width: 200, height: 10)]
        )
    }
    
    func testHeadingNeverMergedWithBodyParagraph() {
        let heading = makeSentence(id: 0, blockID: 0, blockType: .heading, text: "Chapter 1: The Foundations")
        let body1 = makeSentence(id: 1, blockID: 1, blockType: .paragraph, text: "This is the first sentence.")
        let body2 = makeSentence(id: 2, blockID: 1, blockType: .paragraph, text: "This is the second sentence.")
        
        let chunker = TTSChunker(minWordsPerChunk: 5, targetMaxWordsPerChunk: 50, maxSentencesPerChunk: 5)
        let chunks = chunker.chunk(sentences: [heading, body1, body2])
        
        // Heading must be isolated in chunk 0
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].blockType, .heading)
        XCTAssertEqual(chunks[0].sentenceIDs, [0])
        XCTAssertEqual(chunks[0].pauseDurationAfter, 0.6)
        
        // Body sentences grouped in chunk 1
        XCTAssertEqual(chunks[1].blockType, .paragraph)
        XCTAssertEqual(chunks[1].sentenceIDs, [1, 2])
        XCTAssertEqual(chunks[1].pauseDurationAfter, 0.5)
    }
    
    func testListItemsAreStandaloneUnits() {
        let item1 = makeSentence(id: 0, blockID: 0, blockType: .listItem, text: "• First bullet item.")
        let item2 = makeSentence(id: 1, blockID: 1, blockType: .listItem, text: "• Second bullet item.")
        let item3 = makeSentence(id: 2, blockID: 2, blockType: .listItem, text: "• Third bullet item.")
        
        let chunker = TTSChunker(minWordsPerChunk: 5, targetMaxWordsPerChunk: 50, maxSentencesPerChunk: 5)
        let chunks = chunker.chunk(sentences: [item1, item2, item3])
        
        // Each list item must be its own chunk with boundary pause
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].blockType, .listItem)
        XCTAssertEqual(chunks[0].pauseDurationAfter, 0.4)
        XCTAssertEqual(chunks[1].blockType, .listItem)
        XCTAssertEqual(chunks[1].pauseDurationAfter, 0.4)
        XCTAssertEqual(chunks[2].blockType, .listItem)
        XCTAssertEqual(chunks[2].pauseDurationAfter, 0.4)
    }
}
