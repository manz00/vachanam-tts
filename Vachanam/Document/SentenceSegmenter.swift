//
//  SentenceSegmenter.swift
//  Vachanam
//
//  Segments reconstructed paragraphs into clean sentences, assigning stable global IDs
//  and mapping words back to accurate PDF page bounding boxes.
//

import Foundation
import CoreGraphics
@preconcurrency import PDFKit
import NaturalLanguage

public final class SentenceSegmenter: @unchecked Sendable {
    public static let shared = SentenceSegmenter()
    
    public init() {}
    
    /// Asynchronously parses a PDF document by offloading extraction to a dedicated GCD queue.
    /// This prevents PDFKit's internal accessibility calls from executing inside a Swift Concurrency
    /// cooperative task context, eliminating AXCoreUtilities' `unsafeForcedSync` warnings and thread starvation.
    public func parseDocumentAsync(pdfDocument: PDFDocument, title: String, documentID: UUID = UUID()) async -> SemanticDocument {
        nonisolated(unsafe) let pdf = pdfDocument
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let doc = self.parseDocument(pdfDocument: pdf, title: title, documentID: documentID)
                continuation.resume(returning: doc)
            }
        }
    }
    
    /// Parses a PDF document into a fully indexed SemanticDocument.
    public func parseDocument(pdfDocument: PDFDocument, title: String, documentID: UUID = UUID()) -> SemanticDocument {
        let pageCount = pdfDocument.pageCount
        var allBlocks: [SemanticBlock] = []
        var allParagraphs: [SemanticParagraph] = []
        var allSentences: [SemanticSentence] = []
        var allWords: [SemanticWord] = []
        
        var nextGlobalWordID = 0
        var nextSentenceID = 0
        var nextParagraphID = 0
        var nextBlockID = 0
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            guard let pageString = page.string, !pageString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            // Extract visual lines from PDFKit line selections
            let visualLines = extractVisualLines(from: page, pageIndex: pageIndex)
            
            // Cluster into coherent raw paragraphs and semantic blocks
            let rawParagraphs = ParagraphDetector.shared.detectParagraphs(from: visualLines, pageIndex: pageIndex)
            
            var pageSearchOffset = 0
            let nsPageString = pageString as NSString
            
            for rawPara in rawParagraphs {
                let paragraphText = rawPara.combinedText
                guard !paragraphText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                
                let currentBlockID = nextBlockID
                nextBlockID += 1
                
                let normalizedText = TextNormalizer.shared.normalize(paragraphText)
                let sentenceTokenizer = NLTokenizer(unit: .sentence)
                sentenceTokenizer.string = normalizedText
                
                var paragraphSentenceIDs: [Int] = []
                let fullRange = normalizedText.startIndex..<normalizedText.endIndex
                
                sentenceTokenizer.enumerateTokens(in: fullRange) { sRange, _ in
                    let rawSentence = String(normalizedText[sRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !rawSentence.isEmpty else { return true }
                    
                    let currentSentenceID = nextSentenceID
                    nextSentenceID += 1
                    paragraphSentenceIDs.append(currentSentenceID)
                    
                    // Extract words within this sentence using forward-scanning on pageString
                    let (sentenceWords, lineBounds, unionBounds, newOffset) = self.extractWordsForSentence(
                        sentenceText: rawSentence,
                        page: page,
                        nsPageString: nsPageString,
                        pageIndex: pageIndex,
                        sentenceID: currentSentenceID,
                        startWordID: nextGlobalWordID,
                        searchOffset: pageSearchOffset
                    )
                    
                    pageSearchOffset = newOffset
                    nextGlobalWordID += sentenceWords.count
                    allWords.append(contentsOf: sentenceWords)
                    
                    let sentenceItem = SemanticSentence(
                        sentenceID: currentSentenceID,
                        paragraphID: nextParagraphID,
                        blockID: currentBlockID,
                        blockType: rawPara.blockType,
                        primaryPageIndex: pageIndex,
                        pageSpans: [pageIndex],
                        text: rawSentence,
                        words: sentenceWords,
                        lineBoundsByPage: [pageIndex: lineBounds],
                        boundsByPage: [pageIndex: unionBounds]
                    )
                    allSentences.append(sentenceItem)
                    return true
                }
                
                if !paragraphSentenceIDs.isEmpty {
                    allBlocks.append(SemanticBlock(
                        blockID: currentBlockID,
                        type: rawPara.blockType,
                        level: rawPara.level,
                        marker: rawPara.marker,
                        pageIndex: pageIndex,
                        sentenceIDs: paragraphSentenceIDs,
                        bounds: rawPara.bounds
                    ))
                    allParagraphs.append(SemanticParagraph(
                        paragraphID: nextParagraphID,
                        pageIndex: pageIndex,
                        sentenceIDs: paragraphSentenceIDs
                    ))
                    nextParagraphID += 1
                }
            }
        }
        
        // Chunk sentences into semantic TTS chunks respecting block boundaries
        let chunks = TTSChunker.shared.chunk(sentences: allSentences, blocks: allBlocks)
        
        return SemanticDocument(
            documentID: documentID,
            title: title,
            pageCount: pageCount,
            blocks: allBlocks,
            paragraphs: allParagraphs,
            sentences: allSentences,
            words: allWords,
            chunks: chunks
        )
    }
    
    // MARK: - Private Helpers
    
    private func extractVisualLines(from page: PDFPage, pageIndex: Int) -> [VisualLine] {
        guard let pageString = page.string else { return [] }
        let fullNSRange = NSRange(location: 0, length: (pageString as NSString).length)
        guard let fullSelection = page.selection(for: fullNSRange) else { return [] }
        
        let lineSelections = fullSelection.selectionsByLine()
        return lineSelections.compactMap { lineSel in
            guard let lineStr = lineSel.string, !lineStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return VisualLine(text: lineStr, bounds: lineSel.bounds(for: page), pageIndex: pageIndex)
        }
    }
    
    private func extractWordsForSentence(
        sentenceText: String,
        page: PDFPage,
        nsPageString: NSString,
        pageIndex: Int,
        sentenceID: Int,
        startWordID: Int,
        searchOffset: Int
    ) -> ([SemanticWord], [CGRect], CGRect, Int) {
        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = sentenceText
        
        var words: [SemanticWord] = []
        var wordID = startWordID
        var wordIdxInSentence = 0
        var currentOffset = min(searchOffset, nsPageString.length)
        let pageLength = nsPageString.length
        
        let fullSentenceRange = sentenceText.startIndex..<sentenceText.endIndex
        
        wordTokenizer.enumerateTokens(in: fullSentenceRange) { wRange, _ in
            let wText = String(sentenceText[wRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !wText.isEmpty else { return true }
            
            let nsSentenceRange = NSRange(wRange, in: sentenceText)
            
            // Forward-match the word in nsPageString starting from currentOffset
            var wordBounds = CGRect.zero
            var wordLineBounds: [CGRect] = []
            var isHyphenated = false
            
            // 1. Exact match attempt
            let searchLength = min(pageLength - currentOffset, 500)
            let searchSubrange = NSRange(location: currentOffset, length: max(0, searchLength))
            var matchRange = NSRange(location: NSNotFound, length: 0)
            if searchSubrange.length > 0 {
                matchRange = nsPageString.range(
                    of: wText,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchSubrange
                )
            }
            
            if matchRange.location != NSNotFound {
                if let sel = page.selection(for: matchRange) {
                    wordBounds = sel.bounds(for: page)
                    wordLineBounds = sel.selectionsByLine().map { $0.bounds(for: page) }
                }
                currentOffset = matchRange.location + matchRange.length
            } else {
                // 2. Check for hyphenated break in page string (e.g. "probabil-" and "ity")
                var foundHyphenSplit = false
                if wText.count > 3 {
                    for prefixLen in stride(from: wText.count - 2, through: 2, by: -1) {
                        let prefix = String(wText.prefix(prefixLen))
                        let prefixHyphen = prefix + "-"
                        let pSearchLen = min(pageLength - currentOffset, 300)
                        guard pSearchLen > 0 else { break }
                        let pRange = nsPageString.range(
                            of: prefixHyphen,
                            options: [.caseInsensitive],
                            range: NSRange(location: currentOffset, length: pSearchLen)
                        )
                        if pRange.location != NSNotFound {
                            let suffix = String(wText.suffix(wText.count - prefixLen))
                            let afterPrefix = pRange.location + pRange.length
                            let sSearchLen = min(pageLength - afterPrefix, 100)
                            if sSearchLen > 0 {
                                let sRange = nsPageString.range(
                                    of: suffix,
                                    options: [.caseInsensitive],
                                    range: NSRange(location: afterPrefix, length: sSearchLen)
                                )
                                if sRange.location != NSNotFound {
                                    let sel1 = page.selection(for: pRange)
                                    let sel2 = page.selection(for: sRange)
                                    let b1 = sel1?.bounds(for: page) ?? .zero
                                    let b2 = sel2?.bounds(for: page) ?? .zero
                                    wordBounds = b1.isEmpty ? b2 : (b2.isEmpty ? b1 : b1.union(b2))
                                    wordLineBounds = [b1, b2].filter { !$0.isEmpty }
                                    isHyphenated = true
                                    currentOffset = sRange.location + sRange.length
                                    foundHyphenSplit = true
                                    break
                                }
                            }
                        }
                    }
                }
                
                // 3. Fallback: wider search on the page
                if !foundHyphenSplit {
                    let fallbackRange = nsPageString.range(of: wText, options: [.caseInsensitive])
                    if fallbackRange.location != NSNotFound, let sel = page.selection(for: fallbackRange) {
                        wordBounds = sel.bounds(for: page)
                        wordLineBounds = sel.selectionsByLine().map { $0.bounds(for: page) }
                        currentOffset = max(currentOffset, fallbackRange.location + fallbackRange.length)
                    }
                }
            }
            
            let sWord = SemanticWord(
                globalWordID: wordID,
                text: wText,
                pageIndex: pageIndex,
                sentenceID: sentenceID,
                wordIndexInSentence: wordIdxInSentence,
                bounds: wordBounds,
                lineBounds: wordLineBounds.isEmpty ? (wordBounds.isEmpty ? [] : [wordBounds]) : wordLineBounds,
                sentenceRange: nsSentenceRange,
                isHyphenatedBreak: isHyphenated
            )
            
            words.append(sWord)
            wordID += 1
            wordIdxInSentence += 1
            return true
        }
        
        // Compute line bounds and union bounds
        var lineBounds: [CGRect] = []
        let validBounds = words.flatMap { $0.lineBounds }.filter { !$0.isEmpty }
        var unionBounds = CGRect.zero
        if !validBounds.isEmpty {
            unionBounds = validBounds.reduce(validBounds[0]) { $0.union($1) }
            
            // Group word rects into lines by comparing Y-centers
            var lineGroups: [[CGRect]] = []
            for rect in validBounds.sorted(by: { $0.minY > $1.minY }) {
                if let groupIdx = lineGroups.firstIndex(where: { group in
                    let groupMidY = group[0].midY
                    return abs(groupMidY - rect.midY) < (rect.height * 0.5)
                }) {
                    lineGroups[groupIdx].append(rect)
                } else {
                    lineGroups.append([rect])
                }
            }
            
            lineBounds = lineGroups.map { grp in
                grp.reduce(grp[0]) { $0.union($1) }
            }
        }
        
        return (words, lineBounds, unionBounds, currentOffset)
    }
}
