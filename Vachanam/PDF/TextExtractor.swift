//
//  TextExtractor.swift
//  Vachanam
//
//  Extracts structured text, sentences, and words with geometric bounding boxes from PDF pages.
//

import Foundation
import PDFKit
import NaturalLanguage

public struct WordRect: Identifiable, Hashable {
    public let id = UUID()
    public let text: String
    public let range: NSRange
    public let bounds: CGRect
    public let pageIndex: Int
    
    public init(text: String, range: NSRange, bounds: CGRect, pageIndex: Int) {
        self.text = text
        self.range = range
        self.bounds = bounds
        self.pageIndex = pageIndex
    }
}

public struct SentenceItem: Identifiable, Hashable {
    public let id = UUID()
    public let text: String
    public let range: NSRange
    public let bounds: CGRect
    public let words: [WordRect]
    public let pageIndex: Int
    
    public init(text: String, range: NSRange, bounds: CGRect, words: [WordRect], pageIndex: Int) {
        self.text = text
        self.range = range
        self.bounds = bounds
        self.words = words
        self.pageIndex = pageIndex
    }
}

public class TextExtractor {
    public static let shared = TextExtractor()
    
    public init() {}
    
    /// Extracts structured sentences and bounding boxes from a given PDFPage.
    public func extractSentences(from page: PDFPage, pageIndex: Int) -> [SentenceItem] {
        guard let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let nsString = pageText as NSString
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = pageText
        
        var sentences: [SentenceItem] = []
        let fullRange = pageText.startIndex..<pageText.endIndex
        
        tokenizer.enumerateTokens(in: fullRange) { tokenRange, _ in
            let sentenceString = String(pageText[tokenRange])
            let nsSentenceRange = NSRange(tokenRange, in: pageText)
            
            // Extract bounding rect for the entire sentence
            var sentenceBounds = CGRect.zero
            if let sentenceSelection = page.selection(for: nsSentenceRange) {
                sentenceBounds = sentenceSelection.bounds(for: page)
            }
            
            // Extract individual words within this sentence
            let words = self.extractWords(from: page, in: nsSentenceRange, pageText: pageText, pageIndex: pageIndex)
            
            // If overall bounds was zero, unite word bounds
            if sentenceBounds == .zero && !words.isEmpty {
                sentenceBounds = words.reduce(words[0].bounds) { $0.union($1.bounds) }
            }
            
            let trimmedText = sentenceString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                sentences.append(SentenceItem(
                    text: trimmedText,
                    range: nsSentenceRange,
                    bounds: sentenceBounds,
                    words: words,
                    pageIndex: pageIndex
                ))
            }
            
            return true
        }
        
        return sentences
    }
    
    /// Extracts individual words with bounding rects inside a specified range on a page.
    private func extractWords(from page: PDFPage, in range: NSRange, pageText: String, pageIndex: Int) -> [WordRect] {
        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = pageText
        
        guard let swiftRange = Range(range, in: pageText) else { return [] }
        var words: [WordRect] = []
        
        wordTokenizer.enumerateTokens(in: swiftRange) { wordRange, _ in
            let wordText = String(pageText[wordRange])
            let nsWordRange = NSRange(wordRange, in: pageText)
            
            var wordBounds = CGRect.zero
            if let wordSelection = page.selection(for: nsWordRange) {
                wordBounds = wordSelection.bounds(for: page)
            }
            
            let trimmedWord = wordText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedWord.isEmpty {
                words.append(WordRect(
                    text: trimmedWord,
                    range: nsWordRange,
                    bounds: wordBounds,
                    pageIndex: pageIndex
                ))
            }
            return true
        }
        
        return words
    }
}
