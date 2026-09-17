//
//  SemanticDocument.swift
//  Vachanam
//
//  Complete 3-layer representation of a document:
//  Layer 1: PDF Layout (bounding boxes, lines, pages)
//  Layer 2: Semantic Text (paragraphs, sentences, words with global permanent IDs)
//  Layer 3: Audio Timeline (TTS chunks, word offsets, audio durations)
//

import Foundation
import CoreGraphics

public enum BlockType: String, Codable, Sendable {
    case heading
    case paragraph
    case list
    case listItem
    case quote
    case caption
    case footnote
    case pageHeader
    case pageFooter
    case pageNumber
    case tableOfContents
    case sidenote
    case symbolTable
}

public struct SemanticBlock: Identifiable, Hashable, Sendable {
    public let id: Int // Same as blockID
    public let blockID: Int
    public let type: BlockType
    public let level: Int // 1-6 for headings, 0+ for list nesting
    public let marker: String? // e.g. "•", "1.", "-"
    public let pageIndex: Int
    public let sentenceIDs: [Int]
    public let bounds: CGRect
    
    public init(
        blockID: Int,
        type: BlockType,
        level: Int = 1,
        marker: String? = nil,
        pageIndex: Int,
        sentenceIDs: [Int],
        bounds: CGRect = .zero
    ) {
        self.id = blockID
        self.blockID = blockID
        self.type = type
        self.level = level
        self.marker = marker
        self.pageIndex = pageIndex
        self.sentenceIDs = sentenceIDs
        self.bounds = bounds
    }
}

public struct SemanticWord: Identifiable, Hashable, Sendable {
    public let id: Int // Same as globalWordID
    public let globalWordID: Int
    public let text: String
    public let originalText: String
    public var spokenText: String?
    public let pageIndex: Int
    public let sentenceID: Int
    public let wordIndexInSentence: Int
    public let bounds: CGRect
    public let lineBounds: [CGRect]
    public let sentenceRange: NSRange
    public var chunkRange: NSRange
    public let isHyphenatedBreak: Bool
    
    public init(
        globalWordID: Int,
        text: String,
        originalText: String? = nil,
        spokenText: String? = nil,
        pageIndex: Int,
        sentenceID: Int,
        wordIndexInSentence: Int,
        bounds: CGRect,
        lineBounds: [CGRect] = [],
        sentenceRange: NSRange,
        chunkRange: NSRange = NSRange(location: 0, length: 0),
        isHyphenatedBreak: Bool = false
    ) {
        self.id = globalWordID
        self.globalWordID = globalWordID
        self.text = text
        self.originalText = originalText ?? text
        self.spokenText = spokenText
        self.pageIndex = pageIndex
        self.sentenceID = sentenceID
        self.wordIndexInSentence = wordIndexInSentence
        self.bounds = bounds
        self.lineBounds = lineBounds.isEmpty ? (bounds.isEmpty ? [] : [bounds]) : lineBounds
        self.sentenceRange = sentenceRange
        self.chunkRange = chunkRange
        self.isHyphenatedBreak = isHyphenatedBreak
    }
}

public struct SemanticSentence: Identifiable, Hashable, Sendable {
    public let id: Int // Same as sentenceID
    public let sentenceID: Int
    public let paragraphID: Int
    public let blockID: Int
    public let blockType: BlockType
    public let primaryPageIndex: Int
    public let pageSpans: Set<Int>
    public let text: String
    public let words: [SemanticWord]
    public let lineBoundsByPage: [Int: [CGRect]]
    public let boundsByPage: [Int: CGRect]
    
    public init(
        sentenceID: Int,
        paragraphID: Int,
        blockID: Int? = nil,
        blockType: BlockType = .paragraph,
        primaryPageIndex: Int,
        pageSpans: Set<Int>,
        text: String,
        words: [SemanticWord],
        lineBoundsByPage: [Int: [CGRect]],
        boundsByPage: [Int: CGRect]
    ) {
        self.id = sentenceID
        self.sentenceID = sentenceID
        self.paragraphID = paragraphID
        self.blockID = blockID ?? paragraphID
        self.blockType = blockType
        self.primaryPageIndex = primaryPageIndex
        self.pageSpans = pageSpans
        self.text = text
        self.words = words
        self.lineBoundsByPage = lineBoundsByPage
        self.boundsByPage = boundsByPage
    }
    
    /// Line bounds specifically for a given page index.
    public func lineBounds(for pageIndex: Int) -> [CGRect] {
        lineBoundsByPage[pageIndex] ?? []
    }
    
    /// Overall bounds for a given page index.
    public func bounds(for pageIndex: Int) -> CGRect {
        boundsByPage[pageIndex] ?? .zero
    }
}

public struct SemanticParagraph: Identifiable, Hashable, Sendable {
    public let id: Int // Same as paragraphID
    public let paragraphID: Int
    public let pageIndex: Int
    public let sentenceIDs: [Int]
    
    public init(paragraphID: Int, pageIndex: Int, sentenceIDs: [Int]) {
        self.id = paragraphID
        self.paragraphID = paragraphID
        self.pageIndex = pageIndex
        self.sentenceIDs = sentenceIDs
    }
}

public struct TTSChunk: Identifiable, Hashable, Sendable {
    public let id: Int // Same as chunkID
    public let chunkID: Int
    public let sentenceIDs: [Int]
    public let wordIDs: [Int]
    public let primaryPageIndex: Int
    public let pageSpans: Set<Int>
    public let text: String
    public let wordCount: Int
    public let estimatedDuration: TimeInterval
    public let blockID: Int?
    public let blockType: BlockType
    public let pauseDurationAfter: TimeInterval
    
    public init(
        chunkID: Int,
        sentenceIDs: [Int],
        wordIDs: [Int],
        primaryPageIndex: Int = 0,
        pageSpans: Set<Int> = [],
        text: String,
        wordCount: Int,
        estimatedDuration: TimeInterval,
        blockID: Int? = nil,
        blockType: BlockType = .paragraph,
        pauseDurationAfter: TimeInterval = 0.0
    ) {
        self.id = chunkID
        self.chunkID = chunkID
        self.sentenceIDs = sentenceIDs
        self.wordIDs = wordIDs
        self.primaryPageIndex = primaryPageIndex
        self.pageSpans = pageSpans.isEmpty ? [primaryPageIndex] : pageSpans
        self.text = text
        self.wordCount = wordCount
        self.estimatedDuration = estimatedDuration
        self.blockID = blockID
        self.blockType = blockType
        self.pauseDurationAfter = pauseDurationAfter
    }
}

public class SemanticDocument: ObservableObject, @unchecked Sendable {
    public let documentID: UUID
    public let title: String
    public let pageCount: Int
    
    public let blocks: [SemanticBlock]
    public let paragraphs: [SemanticParagraph]
    public let sentences: [SemanticSentence]
    public let words: [SemanticWord]
    public let chunks: [TTSChunk]
    
    // Fast lookup caches
    private let wordsByID: [Int: SemanticWord]
    private let sentencesByID: [Int: SemanticSentence]
    private let blocksByID: [Int: SemanticBlock]
    private let chunksByID: [Int: TTSChunk]
    private let sentenceToChunkMap: [Int: Int] // sentenceID -> chunkID
    private let wordToChunkMap: [Int: Int]     // wordID -> chunkID
    private let wordsByPage: [Int: [SemanticWord]]
    private let blocksByPage: [Int: [SemanticBlock]]
    
    public init(
        documentID: UUID = UUID(),
        title: String,
        pageCount: Int,
        blocks: [SemanticBlock] = [],
        paragraphs: [SemanticParagraph],
        sentences: [SemanticSentence],
        words: [SemanticWord],
        chunks: [TTSChunk]
    ) {
        self.documentID = documentID
        self.title = title
        self.pageCount = pageCount
        self.paragraphs = paragraphs
        self.sentences = sentences
        self.words = words
        self.chunks = chunks
        
        let effectiveBlocks: [SemanticBlock]
        if !blocks.isEmpty {
            effectiveBlocks = blocks
        } else {
            effectiveBlocks = paragraphs.map { p in
                SemanticBlock(
                    blockID: p.paragraphID,
                    type: .paragraph,
                    pageIndex: p.pageIndex,
                    sentenceIDs: p.sentenceIDs
                )
            }
        }
        self.blocks = effectiveBlocks
        
        var bMap: [Int: SemanticBlock] = [:]
        var bByPage: [Int: [SemanticBlock]] = [:]
        for b in effectiveBlocks {
            bMap[b.blockID] = b
            bByPage[b.pageIndex, default: []].append(b)
        }
        self.blocksByID = bMap
        self.blocksByPage = bByPage
        
        var wMap: [Int: SemanticWord] = [:]
        var wByPage: [Int: [SemanticWord]] = [:]
        for w in words {
            wMap[w.globalWordID] = w
            wByPage[w.pageIndex, default: []].append(w)
        }
        self.wordsByID = wMap
        self.wordsByPage = wByPage
        
        var sMap: [Int: SemanticSentence] = [:]
        for s in sentences {
            sMap[s.sentenceID] = s
        }
        self.sentencesByID = sMap
        
        var cMap: [Int: TTSChunk] = [:]
        var sToC: [Int: Int] = [:]
        var wToC: [Int: Int] = [:]
        for c in chunks {
            cMap[c.chunkID] = c
            for sID in c.sentenceIDs {
                sToC[sID] = c.chunkID
            }
            for wID in c.wordIDs {
                wToC[wID] = c.chunkID
            }
        }
        self.chunksByID = cMap
        self.sentenceToChunkMap = sToC
        self.wordToChunkMap = wToC
    }
    
    // MARK: - Lookups
    
    public func block(id: Int) -> SemanticBlock? {
        blocksByID[id]
    }
    
    public func blocks(forPageIndex pageIndex: Int) -> [SemanticBlock] {
        blocksByPage[pageIndex] ?? []
    }
    
    public func word(id: Int) -> SemanticWord? {
        wordsByID[id]
    }
    
    public func sentence(id: Int) -> SemanticSentence? {
        sentencesByID[id]
    }
    
    public func chunk(id: Int) -> TTSChunk? {
        chunksByID[id]
    }
    
    public func chunk(forSentenceID sentenceID: Int) -> TTSChunk? {
        guard let chunkID = sentenceToChunkMap[sentenceID] else { return nil }
        return chunksByID[chunkID]
    }
    
    public func chunk(forWordID wordID: Int) -> TTSChunk? {
        guard let chunkID = wordToChunkMap[wordID] else { return nil }
        return chunksByID[chunkID]
    }
    
    public func chunks(forPageIndex pageIndex: Int) -> [TTSChunk] {
        chunks.filter { $0.pageSpans.contains(pageIndex) }
    }
    
    public func firstWord(onPageIndex pageIndex: Int) -> SemanticWord? {
        wordsByPage[pageIndex]?.first
    }
    
    public func lastWord(onPageIndex pageIndex: Int) -> SemanticWord? {
        wordsByPage[pageIndex]?.last
    }
    
    public func sentences(forPageIndex pageIndex: Int) -> [SemanticSentence] {
        sentences.filter { $0.pageSpans.contains(pageIndex) }
    }
    
    public func words(forPageIndex pageIndex: Int) -> [SemanticWord] {
        wordsByPage[pageIndex] ?? []
    }
    
    /// Spatial hit-testing: finds the word at a given point on a specific PDF page.
    public func findWord(at point: CGPoint, onPageIndex pageIndex: Int, hitPadding: CGFloat = 12.0, maxSearchRadius: CGFloat = 36.0) -> SemanticWord? {
        guard let pageWords = wordsByPage[pageIndex], !pageWords.isEmpty else { return nil }
        
        // Exact bounds match first (checking both bounding box and line slices)
        for word in pageWords {
            if word.bounds.contains(point) || word.lineBounds.contains(where: { $0.contains(point) }) {
                return word
            }
        }
        
        // Match with hit padding (finger touch on iPad or mouse click nearby)
        var closestWord: SemanticWord? = nil
        var minDistance: CGFloat = .infinity
        
        for word in pageWords {
            let paddedBounds = word.bounds.insetBy(dx: -hitPadding, dy: -hitPadding)
            let isPaddedMatch = paddedBounds.contains(point) || word.lineBounds.contains(where: { $0.insetBy(dx: -hitPadding, dy: -hitPadding).contains(point) })
            if isPaddedMatch {
                let center = CGPoint(x: word.bounds.midX, y: word.bounds.midY)
                let dist = hypot(point.x - center.x, point.y - center.y)
                if dist < minDistance {
                    minDistance = dist
                    closestWord = word
                }
            }
        }
        
        if let found = closestWord {
            return found
        }
        
        // Fallback: If tapped near a word (e.g. within maxSearchRadius)
        for word in pageWords {
            let center = CGPoint(x: word.bounds.midX, y: word.bounds.midY)
            let dist = hypot(point.x - center.x, point.y - center.y)
            if dist < maxSearchRadius && dist < minDistance {
                minDistance = dist
                closestWord = word
            }
        }
        
        return closestWord
    }
}
