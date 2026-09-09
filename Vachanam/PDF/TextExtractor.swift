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
    public let range: NSRange           // Range in full page text
    public let sentenceRange: NSRange   // Exact 0-based range in sentence.text
    public let bounds: CGRect           // Bounds in PDF page coordinates
    public let pageIndex: Int
    public let wordIndex: Int           // Index within sentence (0, 1, 2...)
    public let globalWordID: Int
    
    public init(
        text: String,
        range: NSRange,
        sentenceRange: NSRange = NSRange(location: 0, length: 0),
        bounds: CGRect,
        pageIndex: Int,
        wordIndex: Int = 0,
        globalWordID: Int = 0
    ) {
        self.text = text
        self.range = range
        self.sentenceRange = sentenceRange.length > 0 ? sentenceRange : NSRange(location: 0, length: text.count)
        self.bounds = bounds
        self.pageIndex = pageIndex
        self.wordIndex = wordIndex
        self.globalWordID = globalWordID
    }
    
    public init(from semanticWord: SemanticWord) {
        self.text = semanticWord.text
        self.range = semanticWord.sentenceRange
        self.sentenceRange = semanticWord.sentenceRange
        self.bounds = semanticWord.bounds
        self.pageIndex = semanticWord.pageIndex
        self.wordIndex = semanticWord.wordIndexInSentence
        self.globalWordID = semanticWord.globalWordID
    }
}

public struct SentenceItem: Identifiable, Hashable {
    public let id = UUID()
    public let text: String
    public let range: NSRange           // Range in full page text
    public let bounds: CGRect           // Overall union bounds in PDF page coordinates
    public let lineBounds: [CGRect]     // Bounding rect for each line spanned by this sentence
    public let words: [WordRect]
    public let pageIndex: Int
    public let sentenceIndex: Int
    
    public init(
        text: String,
        range: NSRange,
        bounds: CGRect,
        lineBounds: [CGRect] = [],
        words: [WordRect],
        pageIndex: Int,
        sentenceIndex: Int = 0
    ) {
        self.text = text
        self.range = range
        self.bounds = bounds
        self.lineBounds = lineBounds.isEmpty ? (bounds.isEmpty ? [] : [bounds]) : lineBounds
        self.words = words
        self.pageIndex = pageIndex
        self.sentenceIndex = sentenceIndex
    }
    
    public init(from semanticSentence: SemanticSentence) {
        self.text = semanticSentence.text
        self.range = NSRange(location: 0, length: semanticSentence.text.utf16.count)
        self.pageIndex = semanticSentence.primaryPageIndex
        self.sentenceIndex = semanticSentence.sentenceID
        self.lineBounds = semanticSentence.lineBounds(for: semanticSentence.primaryPageIndex)
        self.bounds = semanticSentence.bounds(for: semanticSentence.primaryPageIndex)
        self.words = semanticSentence.words.map { WordRect(from: $0) }
    }
}

public class TextExtractor {
    public static let shared = TextExtractor()
    
    public init() {}
    
    /// Extracts structured sentences and bounding boxes from a given PDFPage.
    public func extractSentences(from page: PDFPage, pageIndex: Int) -> [SentenceItem] {
        PDFLoggingSanitizer.suppressingStderr {
            guard let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return []
            }
            
            let tokenizer = NLTokenizer(unit: .sentence)
            tokenizer.string = pageText
            
            var sentences: [SentenceItem] = []
            let fullRange = pageText.startIndex..<pageText.endIndex
            var sIndex = 0
            
            tokenizer.enumerateTokens(in: fullRange) { tokenRange, _ in
                let sentenceString = String(pageText[tokenRange])
                let nsSentenceRange = NSRange(tokenRange, in: pageText)
                let trimmedText = sentenceString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !trimmedText.isEmpty else { return true }
                
                // Extract bounding rect and per-line bounding rects for the entire sentence
                var sentenceBounds = CGRect.zero
                var lineBounds: [CGRect] = []
                
                if let sentenceSelection = page.selection(for: nsSentenceRange) {
                    sentenceBounds = sentenceSelection.bounds(for: page)
                    let lineSelections = sentenceSelection.selectionsByLine()
                    lineBounds = lineSelections.compactMap { line in
                        let b = line.bounds(for: page)
                        return b.isEmpty ? nil : b
                    }
                }
                
                // Extract individual words within this sentence with precise 0-based sentence ranges
                let words = self.extractWords(
                    from: page,
                    sentenceText: trimmedText,
                    nsSentenceRange: nsSentenceRange,
                    pageText: pageText,
                    pageIndex: pageIndex
                )
                
                // If overall bounds was zero, unite word bounds
                if sentenceBounds == .zero && !words.isEmpty {
                    sentenceBounds = words.reduce(words[0].bounds) { $0.union($1.bounds) }
                }
                if lineBounds.isEmpty && !sentenceBounds.isEmpty {
                    lineBounds = [sentenceBounds]
                }
                
                sentences.append(SentenceItem(
                    text: trimmedText,
                    range: nsSentenceRange,
                    bounds: sentenceBounds,
                    lineBounds: lineBounds,
                    words: words,
                    pageIndex: pageIndex,
                    sentenceIndex: sIndex
                ))
                sIndex += 1
                return true
            }
            
            return sentences
        }
    }
    
    /// Extracts individual words with bounding rects inside a specified sentence.
    private func extractWords(
        from page: PDFPage,
        sentenceText: String,
        nsSentenceRange: NSRange,
        pageText: String,
        pageIndex: Int
    ) -> [WordRect] {
        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = sentenceText
        
        // Find exact location of trimmedText inside the original pageText
        let nsPageText = pageText as NSString
        let foundRange = nsPageText.range(of: sentenceText, options: [], range: nsSentenceRange)
        let baseOffset = (foundRange.location != NSNotFound) ? foundRange.location : nsSentenceRange.location
        
        var words: [WordRect] = []
        var wIdx = 0
        let sentenceRange = sentenceText.startIndex..<sentenceText.endIndex
        
        wordTokenizer.enumerateTokens(in: sentenceRange) { wordRange, _ in
            let wordText = String(sentenceText[wordRange])
            let nsSentenceWordRange = NSRange(wordRange, in: sentenceText)
            let nsPageWordRange = NSRange(location: baseOffset + nsSentenceWordRange.location, length: nsSentenceWordRange.length)
            
            var wordBounds = CGRect.zero
            if let wordSelection = page.selection(for: nsPageWordRange) {
                wordBounds = wordSelection.bounds(for: page)
            }
            
            let trimmedWord = wordText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedWord.isEmpty {
                words.append(WordRect(
                    text: trimmedWord,
                    range: nsPageWordRange,
                    sentenceRange: nsSentenceWordRange,
                    bounds: wordBounds,
                    pageIndex: pageIndex,
                    wordIndex: wIdx
                ))
                wIdx += 1
            }
            return true
        }
        
        return words
    }
}
