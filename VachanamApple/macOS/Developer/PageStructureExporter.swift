//
//  PageStructureExporter.swift
//  Vachanam
//
//  Serializes document layout, blocks, sentences, words, and TTS chunks into
//  human- and machine-readable JSON for rapid AI debugging and diagnostics.
//

import Foundation
import CoreGraphics
import KokoroTTS

public struct PageStructureExport: Codable, Sendable {
    public struct BlockExport: Codable, Sendable {
        public let blockID: Int
        public let type: String
        public let level: Int
        public let marker: String?
        public let sentenceIDs: [Int]
        public let bounds: [CGFloat] // [x, y, width, height]
        
        public init(blockID: Int, type: String, level: Int, marker: String?, sentenceIDs: [Int], bounds: [CGFloat]) {
            self.blockID = blockID
            self.type = type
            self.level = level
            self.marker = marker
            self.sentenceIDs = sentenceIDs
            self.bounds = bounds
        }
    }
    
    public struct WordExport: Codable, Sendable {
        public let wordID: Int
        public let text: String
        public let originalText: String
        public let spokenText: String?
        public let sentenceID: Int
        public let wordIndex: Int
        public let bounds: [CGFloat]
        
        public init(wordID: Int, text: String, originalText: String, spokenText: String?, sentenceID: Int, wordIndex: Int, bounds: [CGFloat]) {
            self.wordID = wordID
            self.text = text
            self.originalText = originalText
            self.spokenText = spokenText
            self.sentenceID = sentenceID
            self.wordIndex = wordIndex
            self.bounds = bounds
        }
    }
    
    public struct SentenceExport: Codable, Sendable {
        public let sentenceID: Int
        public let paragraphID: Int
        public let blockID: Int
        public let blockType: String
        public let rawText: String
        public let normalizedSpeechText: String
        public let verbalizedText: String
        public let phonemes: String?
        public let wordCount: Int
        public let words: [WordExport]
        
        public init(sentenceID: Int, paragraphID: Int, blockID: Int, blockType: String, rawText: String, normalizedSpeechText: String, verbalizedText: String, phonemes: String?, wordCount: Int, words: [WordExport]) {
            self.sentenceID = sentenceID
            self.paragraphID = paragraphID
            self.blockID = blockID
            self.blockType = blockType
            self.rawText = rawText
            self.normalizedSpeechText = normalizedSpeechText
            self.verbalizedText = verbalizedText
            self.phonemes = phonemes
            self.wordCount = wordCount
            self.words = words
        }
    }
    
    public struct ChunkExport: Codable, Sendable {
        public let chunkID: Int
        public let sentenceIDs: [Int]
        public let rawText: String
        public let normalizedSpeechText: String
        public let verbalizedText: String
        public let phonemes: String?
        public let wordCount: Int
        public let estimatedDuration: Double
        public let blockType: String
        
        public init(chunkID: Int, sentenceIDs: [Int], rawText: String, normalizedSpeechText: String, verbalizedText: String, phonemes: String?, wordCount: Int, estimatedDuration: Double, blockType: String) {
            self.chunkID = chunkID
            self.sentenceIDs = sentenceIDs
            self.rawText = rawText
            self.normalizedSpeechText = normalizedSpeechText
            self.verbalizedText = verbalizedText
            self.phonemes = phonemes
            self.wordCount = wordCount
            self.estimatedDuration = estimatedDuration
            self.blockType = blockType
        }
    }
    
    public let documentTitle: String
    public let pageIndex: Int
    public let pageNumber: Int
    public let pageWidth: CGFloat
    public let pageHeight: CGFloat
    public let exportedAt: String
    public let totalBlocksOnPage: Int
    public let totalSentencesOnPage: Int
    public let totalWordsOnPage: Int
    public let blocks: [BlockExport]
    public let sentences: [SentenceExport]
    public let chunks: [ChunkExport]
}

public struct ParagraphExport: Codable, Sendable {
    public let documentTitle: String
    public let pageIndex: Int
    public let pageNumber: Int
    public let sentenceIDs: [Int]
    public let blockType: String
    public let rawText: String
    public let normalizedSpeechText: String
    public let verbalizedText: String
    public let phonemes: String?
    public let wordCount: Int
    public let words: [PageStructureExport.WordExport]
    public let exportedAt: String
    public let diagnostics: [String: String]
}

public struct VoiceTestReport: Codable, Sendable {
    public let inputText: String
    public let voice: String
    public let speed: Float
    public let normalizedText: String
    public let verbalizedText: String
    public let phonemes: String?
    public let phonemeTokenCount: Int
    public let oversizedBucketTriggered: Bool
    public let audioDurationSeconds: Double?
    public let realTimeFactor: Double?
    public let success: Bool
    public let errorDescription: String?
    public let testedAt: String
}

public enum PageStructureExporter {
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    public static func exportPage(pageIndex: Int, document: ReaderDocument) -> PageStructureExport {
        let semDoc = document.semanticDocument
        let title = document.title
        let pageNum = pageIndex + 1
        let pdfPage = document.pdfDocument.page(at: pageIndex)
        let pageBounds = pdfPage?.bounds(for: .mediaBox) ?? .zero
        
        let allSentences = semDoc?.sentences ?? []
        let pageSentences = allSentences.filter { $0.primaryPageIndex == pageIndex || $0.pageSpans.contains(pageIndex) }
        
        let allBlocks = semDoc?.blocks ?? []
        let pageBlocks = allBlocks.filter { $0.pageIndex == pageIndex }
        
        let allWords = semDoc?.words ?? []
        let pageWords = allWords.filter { $0.pageIndex == pageIndex }
        
        let allChunks = semDoc != nil ? TTSChunker.shared.chunk(sentences: allSentences) : []
        let pageChunks = allChunks.filter { $0.primaryPageIndex == pageIndex || $0.pageSpans.contains(pageIndex) }
        
        let phonemizer = KokoroMisakiPhonemizer()
        
        let blockExports: [PageStructureExport.BlockExport] = pageBlocks.map { b in
            PageStructureExport.BlockExport(
                blockID: b.blockID,
                type: b.type.rawValue,
                level: b.level,
                marker: b.marker,
                sentenceIDs: b.sentenceIDs,
                bounds: [b.bounds.origin.x, b.bounds.origin.y, b.bounds.size.width, b.bounds.size.height]
            )
        }
        
        let sentenceExports: [PageStructureExport.SentenceExport] = pageSentences.map { s in
            let words = s.words.filter { $0.pageIndex == pageIndex }.map { w in
                PageStructureExport.WordExport(
                    wordID: w.globalWordID,
                    text: w.text,
                    originalText: w.originalText,
                    spokenText: w.spokenText,
                    sentenceID: w.sentenceID,
                    wordIndex: w.wordIndexInSentence,
                    bounds: [w.bounds.origin.x, w.bounds.origin.y, w.bounds.size.width, w.bounds.size.height]
                )
            }
            let normalized = TextNormalizer.shared.normalizeForSpeech(s.text)
            let verbalized = KokoroMisakiPhonemizer.verbalizeNumbers(in: normalized)
            let phonemes = try? phonemizer.phonemize(verbalized).phonemes
            
            return PageStructureExport.SentenceExport(
                sentenceID: s.sentenceID,
                paragraphID: s.paragraphID,
                blockID: s.blockID,
                blockType: s.blockType.rawValue,
                rawText: s.text,
                normalizedSpeechText: normalized,
                verbalizedText: verbalized,
                phonemes: phonemes,
                wordCount: s.words.count,
                words: words
            )
        }
        
        let chunkExports: [PageStructureExport.ChunkExport] = pageChunks.map { c in
            let normalized = TextNormalizer.shared.normalizeForSpeech(c.text)
            let verbalized = KokoroMisakiPhonemizer.verbalizeNumbers(in: normalized)
            let phonemes = try? phonemizer.phonemize(verbalized).phonemes
            
            return PageStructureExport.ChunkExport(
                chunkID: c.chunkID,
                sentenceIDs: c.sentenceIDs,
                rawText: c.text,
                normalizedSpeechText: normalized,
                verbalizedText: verbalized,
                phonemes: phonemes,
                wordCount: c.wordCount,
                estimatedDuration: c.estimatedDuration,
                blockType: c.blockType.rawValue
            )
        }
        
        return PageStructureExport(
            documentTitle: title,
            pageIndex: pageIndex,
            pageNumber: pageNum,
            pageWidth: pageBounds.width,
            pageHeight: pageBounds.height,
            exportedAt: isoFormatter.string(from: Date()),
            totalBlocksOnPage: blockExports.count,
            totalSentencesOnPage: sentenceExports.count,
            totalWordsOnPage: pageWords.count,
            blocks: blockExports,
            sentences: sentenceExports,
            chunks: chunkExports
        )
    }
    
    public static func exportParagraph(sentence: SemanticSentence, document: ReaderDocument) -> ParagraphExport {
        let phonemizer = KokoroMisakiPhonemizer()
        let normalized = TextNormalizer.shared.normalizeForSpeech(sentence.text)
        let verbalized = KokoroMisakiPhonemizer.verbalizeNumbers(in: normalized)
        let phonemeResult = try? phonemizer.phonemize(verbalized)
        
        let wordExports = sentence.words.map { w in
            PageStructureExport.WordExport(
                wordID: w.globalWordID,
                text: w.text,
                originalText: w.originalText,
                spokenText: w.spokenText,
                sentenceID: w.sentenceID,
                wordIndex: w.wordIndexInSentence,
                bounds: [w.bounds.origin.x, w.bounds.origin.y, w.bounds.size.width, w.bounds.size.height]
            )
        }
        
        var diagnostics: [String: String] = [:]
        diagnostics["characterCount"] = "\(sentence.text.count)"
        diagnostics["wordCount"] = "\(sentence.words.count)"
        diagnostics["blockType"] = sentence.blockType.rawValue
        diagnostics["primaryPageIndex"] = "\(sentence.primaryPageIndex)"
        if let res = phonemeResult {
            diagnostics["phonemeLength"] = "\(res.phonemes.utf16.count)"
            diagnostics["droppedTokens"] = "\(res.droppedTokens)"
            diagnostics["exceeds128DurationBucket"] = res.phonemes.utf16.count + 2 > 128 ? "true" : "false"
        } else {
            diagnostics["phonemizerStatus"] = "Failed to produce phonemes"
        }
        
        return ParagraphExport(
            documentTitle: document.title,
            pageIndex: sentence.primaryPageIndex,
            pageNumber: sentence.primaryPageIndex + 1,
            sentenceIDs: [sentence.sentenceID],
            blockType: sentence.blockType.rawValue,
            rawText: sentence.text,
            normalizedSpeechText: normalized,
            verbalizedText: verbalized,
            phonemes: phonemeResult?.phonemes,
            wordCount: sentence.words.count,
            words: wordExports,
            exportedAt: isoFormatter.string(from: Date()),
            diagnostics: diagnostics
        )
    }
    
    public static func exportJSONString<T: Encodable>(from value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
    
    public static func writeTemporaryJSONFile(filename: String, jsonString: String) -> URL? {
        let sanitizedName = filename.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(sanitizedName)
        do {
            try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }
}
