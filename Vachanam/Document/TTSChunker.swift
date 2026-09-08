//
//  TTSChunker.swift
//  Vachanam
//
//  Groups semantic sentences into optimal ~40–80 word (1–3 sentence) chunks for fast TTS inference,
//  low latency first audio, and instantaneous seeking.
//

import Foundation

public class TTSChunker {
    public static let shared = TTSChunker()
    
    public let minWordsPerChunk: Int
    public let targetMaxWordsPerChunk: Int
    public let maxSentencesPerChunk: Int
    
    public init(
        minWordsPerChunk: Int = 10,
        targetMaxWordsPerChunk: Int = 25,
        maxSentencesPerChunk: Int = 2
    ) {
        self.minWordsPerChunk = minWordsPerChunk
        self.targetMaxWordsPerChunk = targetMaxWordsPerChunk
        self.maxSentencesPerChunk = maxSentencesPerChunk
    }
    
    /// Groups an array of semantic sentences into TTSChunk objects,
    /// enforcing strict block boundaries and assigning boundary pause durations.
    public func chunk(sentences: [SemanticSentence], blocks: [SemanticBlock] = []) -> [TTSChunk] {
        guard !sentences.isEmpty else { return [] }
        
        var chunks: [TTSChunk] = []
        var currentChunkID = 0
        
        var currentSentenceIDs: [Int] = []
        var currentWordIDs: [Int] = []
        var currentTexts: [String] = []
        var currentPageSpans: Set<Int> = []
        var currentPrimaryPage = 0
        var currentWordCount = 0
        var currentBlockID: Int? = nil
        var currentBlockType: BlockType = .paragraph
        
        func pauseDuration(for type: BlockType, isLastChunkOfBlock: Bool) -> TimeInterval {
            switch type {
            case .heading:
                return 0.6
            case .listItem, .list:
                return 0.4
            case .quote:
                return 0.5
            case .caption, .footnote:
                return 0.4
            case .paragraph:
                return isLastChunkOfBlock ? 0.5 : 0.1
            }
        }
        
        func finalizeCurrentChunk(isLastChunkOfBlock: Bool) {
            guard !currentSentenceIDs.isEmpty else { return }
            let combinedText = currentTexts.joined(separator: " ")
            let estimatedDuration = Double(currentWordCount) / 2.8 // ~168 words per minute
            let pause = pauseDuration(for: currentBlockType, isLastChunkOfBlock: isLastChunkOfBlock)
            
            chunks.append(TTSChunk(
                chunkID: currentChunkID,
                sentenceIDs: currentSentenceIDs,
                wordIDs: currentWordIDs,
                primaryPageIndex: currentPrimaryPage,
                pageSpans: currentPageSpans,
                text: combinedText,
                wordCount: currentWordCount,
                estimatedDuration: max(estimatedDuration, 0.5) + pause,
                blockID: currentBlockID,
                blockType: currentBlockType,
                pauseDurationAfter: pause
            ))
            currentChunkID += 1
            currentSentenceIDs.removeAll()
            currentWordIDs.removeAll()
            currentTexts.removeAll()
            currentPageSpans.removeAll()
            currentWordCount = 0
            currentBlockID = nil
            currentBlockType = .paragraph
        }
        
        for (index, sentence) in sentences.enumerated() {
            let sentenceWordCount = sentence.words.count
            let sBlockID = sentence.blockID
            let sBlockType = sentence.blockType
            
            // Boundary checks:
            // 1. If currently accumulating and sentence belongs to a new block, finalize!
            let isNewBlock = (currentBlockID != nil && currentBlockID != sBlockID)
            
            // 2. Standalone blocks (headings and list items) must never be merged with other sentences!
            let isStandaloneType = (sBlockType == .heading || sBlockType == .listItem)
            let currentIsStandalone = (currentBlockType == .heading || currentBlockType == .listItem)
            
            // 3. Word and sentence count budget within paragraph
            let wouldExceedWords = (currentWordCount + sentenceWordCount) > targetMaxWordsPerChunk
            let wouldExceedSentences = currentSentenceIDs.count >= maxSentencesPerChunk
            
            if !currentSentenceIDs.isEmpty && (isNewBlock || isStandaloneType || currentIsStandalone || wouldExceedWords || wouldExceedSentences) {
                // If isNewBlock, then the current chunk is the last chunk of its block
                finalizeCurrentChunk(isLastChunkOfBlock: isNewBlock || currentIsStandalone)
            }
            
            if currentSentenceIDs.isEmpty {
                currentPrimaryPage = sentence.primaryPageIndex
                currentBlockID = sBlockID
                currentBlockType = sBlockType
            }
            
            currentSentenceIDs.append(sentence.sentenceID)
            currentWordIDs.append(contentsOf: sentence.words.map { $0.globalWordID })
            currentPageSpans.formUnion(sentence.pageSpans)
            currentTexts.append(sentence.text)
            currentWordCount += sentenceWordCount
            
            // Check if next sentence will belong to a different block or if this is the last sentence
            let nextSentence = (index + 1 < sentences.count) ? sentences[index + 1] : nil
            let isEndOfDocument = (nextSentence == nil)
            let isEndOfBlock = isEndOfDocument || (nextSentence?.blockID != sBlockID)
            
            // If this is a standalone block, finalize immediately
            if isStandaloneType {
                finalizeCurrentChunk(isLastChunkOfBlock: true)
            } else if isEndOfBlock && !currentSentenceIDs.isEmpty {
                // When reaching the end of a block (like paragraph), finalize with the paragraph boundary pause
                finalizeCurrentChunk(isLastChunkOfBlock: true)
            }
        }
        
        finalizeCurrentChunk(isLastChunkOfBlock: true)
        return chunks
    }
}
