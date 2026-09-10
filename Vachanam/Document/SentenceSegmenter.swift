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
        
        // Pass 1: Extract visual lines and page dimensions across the entire document
        // to enable cross-page repetition detection (e.g. running headers & footers)
        var visualLinesByPage: [Int: [VisualLine]] = [:]
        var pageBoundsByPage: [Int: CGRect] = [:]
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            pageBoundsByPage[pageIndex] = page.bounds(for: .cropBox)
            visualLinesByPage[pageIndex] = extractVisualLines(from: page, pageIndex: pageIndex)
        }
        let documentAnalysis = PageFurnitureDetector.shared.analyzeDocument(
            linesByPage: visualLinesByPage,
            pageBounds: pageBoundsByPage
        )
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            guard let pageString = page.string, !pageString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            let visualLines = visualLinesByPage[pageIndex] ?? []
            let pageBounds = pageBoundsByPage[pageIndex] ?? page.bounds(for: .cropBox)
            
            // Cluster into coherent raw paragraphs and semantic blocks with furniture intelligence
            let rawParagraphs = ParagraphDetector.shared.detectParagraphs(
                from: visualLines,
                pageIndex: pageIndex,
                pageBounds: pageBounds,
                analysis: documentAnalysis
            )
            
            var pageSearchOffset = 0
            let nsPageString = pageString as NSString
            
            for rawPara in rawParagraphs {
                let paragraphText = rawPara.combinedText
                guard !paragraphText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                
                let currentBlockID = nextBlockID
                nextBlockID += 1
                
                let normalizedText = TextNormalizer.shared.normalize(paragraphText)
                
                // Protect decimal numbers (e.g. 2.0, 0.5) from being treated as sentence boundaries
                var decimalProtectedText = normalizedText.replacingOccurrences(
                    of: #"(?<=\d)\.(?=\d)"#,
                    with: "__DECIMAL_POINT__",
                    options: .regularExpression
                )
                
                // Protect periods immediately preceding an equation tag (e.g. "... . equation 2.67" or "... . (2.67)")
                // so that equation labels remain attached to the preceding equation clause rather than forming an isolated orphan sentence.
                decimalProtectedText = decimalProtectedText.replacingOccurrences(
                    of: #"\.\s+(equation\s+\d+|(?:\(\d+(?:__DECIMAL_POINT__\d+)?\)))"#,
                    with: ", $1",
                    options: .regularExpression
                )
                
                let sentenceTokenizer = NLTokenizer(unit: .sentence)
                sentenceTokenizer.string = decimalProtectedText
                
                var paragraphSentenceIDs: [Int] = []
                let fullRange = decimalProtectedText.startIndex..<decimalProtectedText.endIndex
                
                struct SentenceTokenInfo {
                    let text: String
                    let range: Range<String.Index>
                }
                var sentenceTokens: [SentenceTokenInfo] = []
                sentenceTokenizer.enumerateTokens(in: fullRange) { sRange, _ in
                    let tokenText = String(decimalProtectedText[sRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let rawSentence = tokenText.replacingOccurrences(of: "__DECIMAL_POINT__", with: ".")
                    if !rawSentence.isEmpty {
                        sentenceTokens.append(SentenceTokenInfo(text: rawSentence, range: sRange))
                    }
                    return true
                }
                
                let paraMinOffset = rawPara.characterRange?.location ?? pageSearchOffset
                let paraMaxOffset = rawPara.characterRange.map { min(nsPageString.length, $0.location + $0.length + 30) } ?? nsPageString.length
                var currentParaOffset = paraMinOffset
                
                for sIdx in 0..<sentenceTokens.count {
                    let sInfo = sentenceTokens[sIdx]
                    let rawSentence = sInfo.text
                    let currentSentenceID = nextSentenceID
                    nextSentenceID += 1
                    paragraphSentenceIDs.append(currentSentenceID)
                    
                    // Determine precise start of current sentence within the paragraph
                    let firstWord = rawSentence.components(separatedBy: .whitespacesAndNewlines).first(where: { !$0.isEmpty }) ?? ""
                    var sentenceStartOffset = currentParaOffset
                    if !firstWord.isEmpty && currentParaOffset < paraMaxOffset {
                        let searchLen = min(max(0, paraMaxOffset - currentParaOffset), 120)
                        if searchLen > 0 {
                            let match = nsPageString.range(
                                of: firstWord,
                                options: [.caseInsensitive, .diacriticInsensitive],
                                range: NSRange(location: currentParaOffset, length: searchLen)
                            )
                            if match.location != NSNotFound {
                                sentenceStartOffset = match.location
                            }
                        }
                    }
                    
                    // Determine upper bound (start of next sentence or paragraph boundary) to prevent bleed
                    var nextSentenceStart = paraMaxOffset
                    if sIdx + 1 < sentenceTokens.count {
                        let nextSentenceText = sentenceTokens[sIdx + 1].text
                        let nextFirstWord = nextSentenceText.components(separatedBy: .whitespacesAndNewlines).first(where: { !$0.isEmpty }) ?? ""
                        if !nextFirstWord.isEmpty {
                            let estMinSearch = sentenceStartOffset + max(1, (rawSentence as NSString).length - 10)
                            let searchStart = max(sentenceStartOffset + 1, min(estMinSearch, paraMaxOffset))
                            let searchLen = max(0, min(paraMaxOffset - searchStart, 160))
                            if searchLen > 0 {
                                let match = nsPageString.range(
                                    of: nextFirstWord,
                                    options: [.caseInsensitive, .diacriticInsensitive],
                                    range: NSRange(location: searchStart, length: searchLen)
                                )
                                if match.location != NSNotFound {
                                    nextSentenceStart = match.location
                                }
                            }
                        }
                    }
                    let sentenceMaxOffset = min(paraMaxOffset, nextSentenceStart)
                    
                    // Extract words strictly bounded within this sentence's boundaries
                    let (sentenceWords, lineBounds, unionBounds, newOffset) = self.extractWordsForSentence(
                        sentenceText: rawSentence,
                        page: page,
                        nsPageString: nsPageString,
                        pageIndex: pageIndex,
                        sentenceID: currentSentenceID,
                        startWordID: nextGlobalWordID,
                        sentenceMinOffset: sentenceStartOffset,
                        sentenceMaxOffset: sentenceMaxOffset,
                        paraBounds: rawPara.bounds
                    )
                    
                    currentParaOffset = max(currentParaOffset, max(sentenceStartOffset, newOffset))
                    pageSearchOffset = max(pageSearchOffset, newOffset)
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
        
        // Determine skipped block types based on user accessibility preferences
        var skippedTypes: Set<BlockType> = []
        if AccessibilityManager.shared.skipHeadersAndFooters {
            skippedTypes.insert(.pageHeader)
            skippedTypes.insert(.pageFooter)
        }
        if AccessibilityManager.shared.skipPageNumbers {
            skippedTypes.insert(.pageNumber)
        }
        if AccessibilityManager.shared.skipFootnotes {
            skippedTypes.insert(.footnote)
        }
        if AccessibilityManager.shared.skipCaptions {
            skippedTypes.insert(.caption)
        }
        if AccessibilityManager.shared.skipSidenotes {
            skippedTypes.insert(.sidenote)
        }
        if AccessibilityManager.shared.skipSymbolTables {
            skippedTypes.insert(.symbolTable)
        }
        
        // Chunk sentences into semantic TTS chunks respecting block boundaries and skip preferences
        let chunks = TTSChunker.shared.chunk(
            sentences: allSentences,
            blocks: allBlocks,
            skippedBlockTypes: skippedTypes
        )
        
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
        guard fullNSRange.length > 0, let fullSelection = page.selection(for: fullNSRange) else { return [] }
        
        let lineSelections = fullSelection.selectionsByLine()
        return lineSelections.compactMap { (lineSel: PDFSelection) -> VisualLine? in
            guard let lineStr = lineSel.string, !lineStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            let r: NSRange? = lineSel.pages.contains(page) ? lineSel.range(at: 0, on: page) : nil
            return VisualLine(text: lineStr, bounds: lineSel.bounds(for: page), pageIndex: pageIndex, pageRange: r)
        }
    }
    
    private func extractWordsForSentence(
        sentenceText: String,
        page: PDFPage,
        nsPageString: NSString,
        pageIndex: Int,
        sentenceID: Int,
        startWordID: Int,
        sentenceMinOffset: Int,
        sentenceMaxOffset: Int,
        paraBounds: CGRect
    ) -> ([SemanticWord], [CGRect], CGRect, Int) {
        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.string = sentenceText
        
        var words: [SemanticWord] = []
        var wordID = startWordID
        var wordIdxInSentence = 0
        var currentOffset = min(sentenceMinOffset, nsPageString.length)
        let boundMaxOffset = min(sentenceMaxOffset, nsPageString.length)
        
        let allowedSpatialBounds = paraBounds.isEmpty ? CGRect(x: 0, y: 0, width: 10000, height: 10000) : paraBounds.insetBy(dx: -8, dy: -8)
        var lastValidWordBounds: CGRect = .zero
        var minMatchedOffset = Int.max
        var maxMatchedOffset = sentenceMinOffset
        
        let fullSentenceRange = sentenceText.startIndex..<sentenceText.endIndex
        
        wordTokenizer.enumerateTokens(in: fullSentenceRange) { wRange, _ in
            let wText = String(sentenceText[wRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !wText.isEmpty else { return true }
            
            let nsSentenceRange = NSRange(wRange, in: sentenceText)
            
            var wordBounds = CGRect.zero
            var wordLineBounds: [CGRect] = []
            var isHyphenated = false
            
            // 1. Forward-search attempt within strict sentence window (max 60 chars ahead)
            let searchLength = min(max(0, boundMaxOffset - currentOffset), 60)
            let searchSubrange = NSRange(location: currentOffset, length: max(0, searchLength))
            var matchRange = NSRange(location: NSNotFound, length: 0)
            if searchSubrange.length > 0 {
                matchRange = nsPageString.range(
                    of: wText,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchSubrange
                )
            }
            
            // Validate match against paragraph spatial bounds
            if matchRange.location != NSNotFound, let sel = page.selection(for: matchRange) {
                let candidateBounds = sel.bounds(for: page)
                if allowedSpatialBounds.contains(CGPoint(x: candidateBounds.midX, y: candidateBounds.midY)) {
                    wordBounds = candidateBounds
                    wordLineBounds = sel.selectionsByLine().map { $0.bounds(for: page) }
                    currentOffset = matchRange.location + matchRange.length
                    minMatchedOffset = min(minMatchedOffset, matchRange.location)
                    maxMatchedOffset = max(maxMatchedOffset, currentOffset)
                }
            }
            
            // 2. If not matched, check for hyphenated word split (e.g. "probabil-" and "ity")
            if wordBounds.isEmpty && wText.count > 3 {
                for prefixLen in stride(from: wText.count - 2, through: 2, by: -1) {
                    let prefix = String(wText.prefix(prefixLen))
                    let prefixHyphen = prefix + "-"
                    let pSearchLen = min(max(0, boundMaxOffset - currentOffset), 40)
                    guard pSearchLen > 0 else { break }
                    let pRange = nsPageString.range(
                        of: prefixHyphen,
                        options: [.caseInsensitive],
                        range: NSRange(location: currentOffset, length: pSearchLen)
                    )
                    if pRange.location != NSNotFound {
                        let suffix = String(wText.suffix(wText.count - prefixLen))
                        let afterPrefix = pRange.location + pRange.length
                        let sSearchLen = min(max(0, boundMaxOffset - afterPrefix), 40)
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
                                let combined = b1.isEmpty ? b2 : (b2.isEmpty ? b1 : b1.union(b2))
                                if allowedSpatialBounds.contains(CGPoint(x: combined.midX, y: combined.midY)) {
                                    wordBounds = combined
                                    wordLineBounds = [b1, b2].filter { !$0.isEmpty }
                                    isHyphenated = true
                                    currentOffset = sRange.location + sRange.length
                                    minMatchedOffset = min(minMatchedOffset, pRange.location)
                                    maxMatchedOffset = max(maxMatchedOffset, currentOffset)
                                    break
                                }
                            }
                        }
                    }
                }
            }
            
            // 3. Local forward search strictly starting from currentOffset within remaining sentence window
            if wordBounds.isEmpty {
                let startLoc = currentOffset
                let localSearchLen = min(max(0, boundMaxOffset - startLoc), 100)
                if localSearchLen > 0 {
                    let localSearchRange = NSRange(location: startLoc, length: localSearchLen)
                    let localMatch = nsPageString.range(
                        of: wText,
                        options: [.caseInsensitive, .diacriticInsensitive],
                        range: localSearchRange
                    )
                    if localMatch.location != NSNotFound, let sel = page.selection(for: localMatch) {
                        let candidateBounds = sel.bounds(for: page)
                        if allowedSpatialBounds.contains(CGPoint(x: candidateBounds.midX, y: candidateBounds.midY)) {
                            wordBounds = candidateBounds
                            wordLineBounds = sel.selectionsByLine().map { $0.bounds(for: page) }
                            currentOffset = localMatch.location + localMatch.length
                            minMatchedOffset = min(minMatchedOffset, localMatch.location)
                            maxMatchedOffset = max(maxMatchedOffset, currentOffset)
                        }
                    }
                }
            }
            
            // 4. Fallback: synthesize adjacent bounds without drifting search offset
            if wordBounds.isEmpty {
                if !lastValidWordBounds.isEmpty {
                    let estX = lastValidWordBounds.maxX + 4
                    let estWidth = CGFloat(max(wText.count, 1)) * 7.5
                    wordBounds = CGRect(
                        x: estX,
                        y: lastValidWordBounds.minY,
                        width: min(estWidth, 80),
                        height: lastValidWordBounds.height
                    )
                } else if !paraBounds.isEmpty {
                    wordBounds = CGRect(
                        x: paraBounds.minX,
                        y: paraBounds.maxY - 18,
                        width: CGFloat(max(wText.count, 1)) * 7.5,
                        height: 16
                    )
                }
                wordLineBounds = [wordBounds]
            } else {
                lastValidWordBounds = wordBounds
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
        // Authoritative sentence character range in page
        let sentencePageRange: NSRange
        if minMatchedOffset != Int.max && maxMatchedOffset > minMatchedOffset {
            sentencePageRange = NSRange(location: minMatchedOffset, length: maxMatchedOffset - minMatchedOffset)
        } else {
            let start = min(sentenceMinOffset, boundMaxOffset)
            sentencePageRange = NSRange(location: start, length: max(0, min(boundMaxOffset, currentOffset) - start))
        }
        
        var lineBounds: [CGRect] = []
        var unionBounds = CGRect.zero
        
        // Authoritative PDFKit Selection for Sentence
        if sentencePageRange.length > 0 &&
           sentencePageRange.location >= 0 &&
           (sentencePageRange.location + sentencePageRange.length) <= nsPageString.length,
           let sentenceSel = page.selection(for: sentencePageRange) {
            let selLines = sentenceSel.selectionsByLine()
            let selLineBounds = selLines.map { $0.bounds(for: page) }.filter { !$0.isEmpty && $0.width > 0 && $0.height > 0 }
            let selUnion = sentenceSel.bounds(for: page)
            
            if !selLineBounds.isEmpty && (paraBounds.isEmpty || allowedSpatialBounds.intersects(selUnion)) {
                lineBounds = selLineBounds.map { b in
                    paraBounds.isEmpty ? b : b.intersection(allowedSpatialBounds)
                }.filter { !$0.isEmpty && $0.width > 0 && $0.height > 0 }
                
                if !lineBounds.isEmpty {
                    unionBounds = lineBounds.reduce(lineBounds[0]) { $0.union($1) }
                }
            }
        }
        
        // Fallback to word-level bounds if selection-based line bounds were empty
        if lineBounds.isEmpty {
            let validBounds = words.flatMap { $0.lineBounds }.filter { rect in
                !rect.isEmpty && (paraBounds.isEmpty || allowedSpatialBounds.intersects(rect))
            }
            if !validBounds.isEmpty {
                unionBounds = validBounds.reduce(validBounds[0]) { $0.union($1) }
                
                var lineGroups: [[CGRect]] = []
                for rect in validBounds.sorted(by: { $0.minY > $1.minY }) {
                    if let groupIdx = lineGroups.firstIndex(where: { group in
                        abs(group[0].midY - rect.midY) < (rect.height * 0.5)
                    }) {
                        lineGroups[groupIdx].append(rect)
                    } else {
                        lineGroups.append([rect])
                    }
                }
                
                lineBounds = lineGroups.map { grp in
                    let u = grp.reduce(grp[0]) { $0.union($1) }
                    return paraBounds.isEmpty ? u : u.intersection(allowedSpatialBounds)
                }.filter { !$0.isEmpty && $0.width > 0 && $0.height > 0 }
            }
        }
        
        // Validate words against sentence Y-bounds to eliminate vertical outliers
        if !lineBounds.isEmpty {
            let sentenceMinY = (lineBounds.map { $0.minY }.min() ?? 0) - 4
            let sentenceMaxY = (lineBounds.map { $0.maxY }.max() ?? 0) + 4
            let validYRange = sentenceMinY...sentenceMaxY
            
            for i in 0..<words.count {
                let w = words[i]
                if !w.bounds.isEmpty && !validYRange.contains(w.bounds.midY) {
                    if let nearestLine = lineBounds.min(by: { abs($0.midY - w.bounds.midY) < abs($1.midY - w.bounds.midY) }) {
                        let clampedY = max(nearestLine.minY, min(nearestLine.maxY - 14, w.bounds.minY))
                        let adjustedBounds = CGRect(x: w.bounds.minX, y: clampedY, width: w.bounds.width, height: min(w.bounds.height, nearestLine.height))
                        words[i] = SemanticWord(
                            globalWordID: w.globalWordID,
                            text: w.text,
                            pageIndex: w.pageIndex,
                            sentenceID: w.sentenceID,
                            wordIndexInSentence: w.wordIndexInSentence,
                            bounds: adjustedBounds,
                            lineBounds: [adjustedBounds],
                            sentenceRange: w.sentenceRange,
                            isHyphenatedBreak: w.isHyphenatedBreak
                        )
                    }
                }
            }
        }
        
        return (words, lineBounds, unionBounds, max(currentOffset, maxMatchedOffset))
    }
}
