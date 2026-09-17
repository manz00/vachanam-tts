//
//  SemanticDocumentBuilder.swift
//  Vachanam
//
//  Bridges ParsedDocument models (EPUB, Markdown, Plain Text, Web) into
//  full 3-layer SemanticDocument representations for TTS and Reader View.
//

import Foundation
import CoreGraphics
import NaturalLanguage

public class SemanticDocumentBuilder {
    public static let shared = SemanticDocumentBuilder()
    
    public init() {}
    
    /// Converts a ParsedDocument into a fully indexed SemanticDocument.
    public func build(from parsed: ParsedDocument, documentID: UUID = UUID()) -> SemanticDocument {
        return buildWithMetadata(from: parsed, documentID: documentID).document
    }
    
    /// Converts a ParsedDocument into a fully indexed SemanticDocument and returns the starting page of each chapter.
    public func buildWithMetadata(
        from parsed: ParsedDocument,
        documentID: UUID = UUID()
    ) -> (document: SemanticDocument, chapterStartPages: [Int]) {
        var allBlocks: [SemanticBlock] = []
        var allParagraphs: [SemanticParagraph] = []
        var allSentences: [SemanticSentence] = []
        var allWords: [SemanticWord] = []
        
        var nextGlobalWordID = 0
        var nextSentenceID = 0
        var nextParagraphID = 0
        var nextBlockID = 0
        
        var virtualPageIndex = 0
        var wordsOnCurrentVirtualPage = 0
        let targetWordsPerVirtualPage = 350
        var chapterStartPages: [Int] = []
        
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        let wordTokenizer = NLTokenizer(unit: .word)
        
        for (chapterIndex, chapter) in parsed.chapters.enumerated() {
            if chapterIndex > 0 && wordsOnCurrentVirtualPage > 0 {
                virtualPageIndex += 1
                wordsOnCurrentVirtualPage = 0
            }
            chapterStartPages.append(virtualPageIndex)
            
            for parsedBlock in chapter.blocks {
                let blockText = parsedBlock.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !blockText.isEmpty else { continue }
                
                let currentBlockID = nextBlockID
                nextBlockID += 1
                
                let currentParagraphID = nextParagraphID
                nextParagraphID += 1
                
                let normalizedText = TextNormalizer.shared.normalize(blockText)
                sentenceTokenizer.string = normalizedText
                
                var blockSentenceIDs: [Int] = []
                let fullRange = normalizedText.startIndex..<normalizedText.endIndex
                
                sentenceTokenizer.enumerateTokens(in: fullRange) { sRange, _ in
                    let rawSentence = String(normalizedText[sRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !rawSentence.isEmpty else { return true }
                    
                    let currentSentenceID = nextSentenceID
                    nextSentenceID += 1
                    blockSentenceIDs.append(currentSentenceID)
                    
                    // Tokenize words in sentence using reused tokenizer
                    wordTokenizer.string = rawSentence
                    var sentenceWords: [SemanticWord] = []
                    var wordIndexInSentence = 0
                    
                    let sFullRange = rawSentence.startIndex..<rawSentence.endIndex
                    
                    wordTokenizer.enumerateTokens(in: sFullRange) { wRange, _ in
                        let wordString = String(rawSentence[wRange])
                        guard !wordString.isEmpty else { return true }
                        
                        let nsRange = NSRange(wRange, in: rawSentence)
                        let wordID = nextGlobalWordID
                        nextGlobalWordID += 1
                        
                        let word = SemanticWord(
                            globalWordID: wordID,
                            text: wordString,
                            originalText: wordString,
                            spokenText: wordString,
                            pageIndex: virtualPageIndex,
                            sentenceID: currentSentenceID,
                            wordIndexInSentence: wordIndexInSentence,
                            bounds: .zero,
                            lineBounds: [],
                            sentenceRange: nsRange
                        )
                        
                        sentenceWords.append(word)
                        allWords.append(word)
                        wordIndexInSentence += 1
                        wordsOnCurrentVirtualPage += 1
                        
                        return true
                    }
                    
                    let semanticSentence = SemanticSentence(
                        sentenceID: currentSentenceID,
                        paragraphID: currentParagraphID,
                        blockID: currentBlockID,
                        blockType: parsedBlock.type,
                        primaryPageIndex: virtualPageIndex,
                        pageSpans: [virtualPageIndex],
                        text: rawSentence,
                        words: sentenceWords,
                        lineBoundsByPage: [:],
                        boundsByPage: [:]
                    )
                    allSentences.append(semanticSentence)
                    
                    if wordsOnCurrentVirtualPage >= targetWordsPerVirtualPage {
                        virtualPageIndex += 1
                        wordsOnCurrentVirtualPage = 0
                    }
                    
                    return true
                }
                
                guard !blockSentenceIDs.isEmpty else { continue }
                
                let semanticBlock = SemanticBlock(
                    blockID: currentBlockID,
                    type: parsedBlock.type,
                    level: parsedBlock.level,
                    marker: parsedBlock.marker,
                    pageIndex: virtualPageIndex,
                    sentenceIDs: blockSentenceIDs,
                    bounds: .zero
                )
                allBlocks.append(semanticBlock)
                
                let semanticParagraph = SemanticParagraph(
                    paragraphID: currentParagraphID,
                    pageIndex: virtualPageIndex,
                    sentenceIDs: blockSentenceIDs
                )
                allParagraphs.append(semanticParagraph)
            }
        }
        
        let chunks = TTSChunker.shared.chunk(sentences: allSentences, blocks: allBlocks)
        let totalPages = max(1, virtualPageIndex + 1)
        
        let semDoc = SemanticDocument(
            documentID: documentID,
            title: parsed.title,
            pageCount: totalPages,
            blocks: allBlocks,
            paragraphs: allParagraphs,
            sentences: allSentences,
            words: allWords,
            chunks: chunks
        )
        return (semDoc, chapterStartPages)
    }
}
