//
//  AppleTTSWordMatchingTests.swift
//  VachanamTests
//
//  Verifies that Apple TTS word range mapping accurately maps spoken character ranges
//  to semantic words for both full-chunk and partial-chunk playback.
//

import XCTest
@testable import Vachanam

final class AppleTTSWordMatchingTests: XCTestCase {
    
    func testFullChunkSpokenWordRangesMapAccurately() {
        let words = [
            SemanticWord(globalWordID: 0, text: "The", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 0, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 0, length: 3)),
            SemanticWord(globalWordID: 1, text: "quick", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 1, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 4, length: 5)),
            SemanticWord(globalWordID: 2, text: "brown", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 2, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 10, length: 5)),
            SemanticWord(globalWordID: 3, text: "fox", pageIndex: 0, sentenceID: 0, wordIndexInSentence: 3, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 16, length: 3))
        ]
        
        let textToSpeak = words.map { $0.text }.joined(separator: " ")
        XCTAssertEqual(textToSpeak, "The quick brown fox")
        
        // Build range mapping as done in PlaybackCoordinator
        var spokenWordRanges: [(word: SemanticWord, range: NSRange)] = []
        let nsText = textToSpeak as NSString
        var searchPos = 0
        for word in words {
            let match = nsText.range(
                of: word.text,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: NSRange(location: searchPos, length: nsText.length - searchPos)
            )
            XCTAssertNotEqual(match.location, NSNotFound, "Word '\(word.text)' must be found in textToSpeak")
            spokenWordRanges.append((word, match))
            searchPos = match.location + match.length
        }
        
        // Simulate Apple TTS reporting character range for "brown" (location 10, length 5)
        let spokenBrownRange = NSRange(location: 10, length: 5)
        let matched = spokenWordRanges.first(where: { NSIntersectionRange($0.range, spokenBrownRange).length > 0 })
        XCTAssertNotNil(matched)
        XCTAssertEqual(matched?.word.text, "brown")
        XCTAssertEqual(matched?.word.globalWordID, 2)
    }
    
    func testPartialChunkSpokenWordRangesMapAccurately() {
        let chunkWords = [
            SemanticWord(globalWordID: 10, text: "First", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 0, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 0, length: 5)),
            SemanticWord(globalWordID: 11, text: "part", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 1, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 6, length: 4)),
            SemanticWord(globalWordID: 12, text: "second", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 2, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 11, length: 6)),
            SemanticWord(globalWordID: 13, text: "part", pageIndex: 0, sentenceID: 1, wordIndexInSentence: 3, bounds: .zero, lineBounds: [], sentenceRange: NSRange(location: 18, length: 4))
        ]
        
        // User starts playback mid-chunk at wordID 12 ("second")
        let startIdx = 2
        let remainingWords = Array(chunkWords[startIdx...])
        let textToSpeak = remainingWords.map { $0.text }.joined(separator: " ")
        XCTAssertEqual(textToSpeak, "second part")
        
        var spokenWordRanges: [(word: SemanticWord, range: NSRange)] = []
        let nsText = textToSpeak as NSString
        var searchPos = 0
        for word in remainingWords {
            let match = nsText.range(
                of: word.text,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: NSRange(location: searchPos, length: nsText.length - searchPos)
            )
            XCTAssertNotEqual(match.location, NSNotFound)
            spokenWordRanges.append((word, match))
            searchPos = match.location + match.length
        }
        
        // Apple TTS reports range for "second" at location 0 in the rebuilt string:
        let spokenSecondRange = NSRange(location: 0, length: 6)
        let matchedSecond = spokenWordRanges.first(where: { NSIntersectionRange($0.range, spokenSecondRange).length > 0 })
        XCTAssertNotNil(matchedSecond)
        XCTAssertEqual(matchedSecond?.word.text, "second")
        XCTAssertEqual(matchedSecond?.word.globalWordID, 12)
        
        // Apple TTS reports range for "part" at location 7 in the rebuilt string:
        let spokenPartRange = NSRange(location: 7, length: 4)
        let matchedPart = spokenWordRanges.first(where: { NSIntersectionRange($0.range, spokenPartRange).length > 0 })
        XCTAssertNotNil(matchedPart)
        XCTAssertEqual(matchedPart?.word.text, "part")
        XCTAssertEqual(matchedPart?.word.globalWordID, 13)
    }
}
