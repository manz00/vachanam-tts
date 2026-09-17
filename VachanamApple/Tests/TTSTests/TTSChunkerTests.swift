//
//  TTSChunkerTests.swift
//  VachanamTests
//

import XCTest
import CoreGraphics
@testable import Vachanam

final class TTSChunkerTests: XCTestCase {
    
    private func makeSentence(id: Int, words: [String]) -> SemanticSentence {
        let semanticWords = words.enumerated().map { (index, word) in
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
        let fullText = words.joined(separator: " ")
        return SemanticSentence(
            sentenceID: id,
            paragraphID: 0,
            primaryPageIndex: 0,
            pageSpans: [0],
            text: fullText,
            words: semanticWords,
            lineBoundsByPage: [0: [CGRect(x: 0, y: 0, width: 200, height: 10)]],
            boundsByPage: [0: CGRect(x: 0, y: 0, width: 200, height: 10)]
        )
    }
    
    func testChunkerEmptySentences() {
        let chunker = TTSChunker.shared
        let chunks = chunker.chunk(sentences: [])
        XCTAssertTrue(chunks.isEmpty)
    }
    
    func testChunkerRespectsWordBudget() {
        // Create 3 sentences, each with 15 words.
        // Target max words per chunk is 25.
        // Chunk 1 should have sentence 0 (15 words).
        // Sentence 1 (15 words) would push total to 30 > 25, so sentence 1 goes to Chunk 2.
        let sentence1 = makeSentence(id: 0, words: Array(repeating: "word", count: 15))
        let sentence2 = makeSentence(id: 1, words: Array(repeating: "word", count: 15))
        let sentence3 = makeSentence(id: 2, words: Array(repeating: "word", count: 15))
        
        let chunker = TTSChunker(minWordsPerChunk: 10, targetMaxWordsPerChunk: 25, maxSentencesPerChunk: 3)
        let chunks = chunker.chunk(sentences: [sentence1, sentence2, sentence3])
        
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].wordCount, 15)
        XCTAssertEqual(chunks[1].wordCount, 15)
        XCTAssertEqual(chunks[2].wordCount, 15)
    }
    
    func testChunkerGroupsSmallSentencesTogether() {
        // 2 small sentences: 5 words and 6 words.
        // Combined is 11 words <= 25 words budget and <= 2 sentences budget.
        let sentence1 = makeSentence(id: 0, words: ["This", "is", "a", "short", "sentence."])
        let sentence2 = makeSentence(id: 1, words: ["Here", "is", "another", "one", "for", "testing."])
        
        let chunker = TTSChunker(minWordsPerChunk: 10, targetMaxWordsPerChunk: 25, maxSentencesPerChunk: 2)
        let chunks = chunker.chunk(sentences: [sentence1, sentence2])
        
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].sentenceIDs, [0, 1])
        XCTAssertEqual(chunks[0].wordCount, 11)
    }
    
    func testChunkerRespectsMaxSentencesPerChunk() {
        // 3 sentences with 3 words each. Max sentences per chunk = 2.
        // Even though 9 words <= 25, sentence 3 must start a new chunk because max sentences = 2.
        let s1 = makeSentence(id: 0, words: ["one", "two", "three"])
        let s2 = makeSentence(id: 1, words: ["four", "five", "six"])
        let s3 = makeSentence(id: 2, words: ["seven", "eight", "nine"])
        
        let chunker = TTSChunker(minWordsPerChunk: 5, targetMaxWordsPerChunk: 25, maxSentencesPerChunk: 2)
        let chunks = chunker.chunk(sentences: [s1, s2, s3])
        
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].sentenceIDs, [0, 1])
        XCTAssertEqual(chunks[1].sentenceIDs, [2])
    }
}
