//
//  AudiobookGenerator.swift
//  Vachanam
//
//  Batch audiobook synthesis engine generating complete .m4a audio chapters,
//  per-word timing indexes, and bundle manifests for instant playback and sync.
//

import Foundation
import Combine
import CoreGraphics
import AVFoundation

public class AudiobookGenerator: ObservableObject {
    public static let shared = AudiobookGenerator()
    
    @Published public var isGenerating: Bool = false
    @Published public var currentChapterIndex: Int = 0
    @Published public var totalChapters: Int = 0
    @Published public var currentChunkIndex: Int = 0
    @Published public var totalChunks: Int = 0
    @Published public var progressFraction: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var lastGeneratedManifest: AudiobookManifest?
    
    private var activeTask: Task<Void, Error>?
    
    public init() {}
    
    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        DispatchQueue.main.async {
            self.isGenerating = false
            self.statusMessage = "Cancelled"
        }
    }
    
    /// Generates a complete audiobook bundle for the given SemanticDocument.
    public func generateAudiobook(
        for document: SemanticDocument,
        adapter: TTSModelProtocol = TTSController.shared.currentAdapter,
        voice: String? = TTSController.shared.selectedVoice,
        speed: Float = TTSController.shared.speechSpeed,
        overwrite: Bool = false
    ) async throws -> AudiobookManifest {
        let docHash = iCloudSyncManager.shared.computeHash(for: document)
        let bundleDir = iCloudSyncManager.shared.bundleDirectory(for: docHash)
        let fileManager = FileManager.default
        
        try fileManager.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        
        await MainActor.run {
            self.isGenerating = true
            self.currentChunkIndex = 0
            self.progressFraction = 0.0
            self.statusMessage = "Preparing document chapters..."
        }
        
        // 1. Group sentences into logical chapters
        let chapterSentenceGroups = groupSentencesIntoChapters(document: document)
        let totalChap = chapterSentenceGroups.count
        
        await MainActor.run {
            self.totalChapters = totalChap
        }
        
        // Calculate total export chunks
        var chapterExportChunkPlans: [[(chunkIndex: Int, sentences: [SemanticSentence])]] = []
        var globalChunkCounter = 0
        
        for sentences in chapterSentenceGroups {
            var plans: [(chunkIndex: Int, sentences: [SemanticSentence])] = []
            var currentBatch: [SemanticSentence] = []
            var currentWords = 0
            
            for sentence in sentences {
                currentBatch.append(sentence)
                currentWords += sentence.words.count
                // Target ~50-80 words per export chunk (~30-45s of speech)
                if currentWords >= 60 {
                    plans.append((globalChunkCounter, currentBatch))
                    globalChunkCounter += 1
                    currentBatch.removeAll()
                    currentWords = 0
                }
            }
            if !currentBatch.isEmpty {
                plans.append((globalChunkCounter, currentBatch))
                globalChunkCounter += 1
            }
            chapterExportChunkPlans.append(plans)
        }
        
        let totalExportChunks = max(globalChunkCounter, 1)
        await MainActor.run {
            self.totalChunks = totalExportChunks
        }
        
        var chapterManifests: [AudiobookChapterManifest] = []
        var totalAudioDuration: TimeInterval = 0.0
        var allIndexedWords: [AudiobookIndexedWord] = []
        
        // 2. Process Chapters and Chunks
        for (chapIdx, plans) in chapterExportChunkPlans.enumerated() {
            try Task.checkCancellation()
            
            let chapNumber = chapIdx + 1
            let chapDirName = String(format: "chapter-%02d", chapNumber)
            let chapAudioDir = bundleDir.appendingPathComponent("chapters/\(chapDirName)", isDirectory: true)
            let chapTimingsDir = bundleDir.appendingPathComponent("timings/\(chapDirName)", isDirectory: true)
            
            try fileManager.createDirectory(at: chapAudioDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: chapTimingsDir, withIntermediateDirectories: true)
            
            var exportChunksForChapter: [AudiobookExportChunk] = []
            let chapterStartPage = plans.first?.sentences.first?.primaryPageIndex ?? 0
            let chapterEndPage = plans.last?.sentences.last?.primaryPageIndex ?? chapterStartPage
            
            await MainActor.run {
                self.currentChapterIndex = chapNumber
                self.statusMessage = "Synthesizing Chapter \(chapNumber) of \(totalChap)..."
            }
            
            for plan in plans {
                try Task.checkCancellation()
                
                let chunkFileName = String(format: "chunk-%03d", plan.chunkIndex + 1)
                let audioRelativePath = "chapters/\(chapDirName)/\(chunkFileName).m4a"
                let timingsRelativePath = "timings/\(chapDirName)/\(chunkFileName).json"
                
                let audioDestURL = bundleDir.appendingPathComponent(audioRelativePath)
                let timingsDestURL = bundleDir.appendingPathComponent(timingsRelativePath)
                
                let chunkSentences = plan.sentences
                let chunkWords = chunkSentences.flatMap { $0.words }
                guard let firstWord = chunkWords.first, let lastWord = chunkWords.last else { continue }
                
                let chunkText = chunkSentences.map { $0.text }.joined(separator: " ")
                
                // Synthesize audio
                let audioResult: TTSAudioResult
                if !overwrite && fileManager.fileExists(atPath: audioDestURL.path) && fileManager.fileExists(atPath: timingsDestURL.path) {
                    let duration = (try? AVAudioFile(forReading: audioDestURL).length).map { Double($0) / 24000.0 } ?? 1.0
                    audioResult = TTSAudioResult(audioData: Data(), pcmBuffer: nil, sampleRate: 24000.0, duration: duration, wordTimestamps: [])
                } else {
                    let normalizedSpoken = TextNormalizer.shared.normalizeForSpeech(chunkText)
                    let processedSpoken = PronunciationManager.shared.applyPronunciations(to: normalizedSpoken, documentID: document.documentID)
                    
                    let profile = VoiceProfileResolver.shared.resolve(
                        modelId: adapter.metadata.id,
                        voiceName: voice,
                        text: processedSpoken
                    )
                    
                    let targetWordStrings = chunkWords.map { $0.text }
                    audioResult = try await adapter.synthesize(
                        text: profile.cleanedText,
                        voice: voice,
                        speed: speed,
                        targetWords: targetWordStrings
                    )
                    
                    // Encode to AAC M4A
                    try AudioEncoder.shared.encodeToM4A(result: audioResult, destinationURL: audioDestURL)
                    
                    // Generate word timestamps aligned with chunk words
                    var timingWords: [AudiobookWordTimestamp] = []
                    if audioResult.wordTimestamps.count == chunkWords.count {
                        for (idx, cw) in chunkWords.enumerated() {
                            let ts = audioResult.wordTimestamps[idx]
                            timingWords.append(AudiobookWordTimestamp(
                                globalWordID: cw.globalWordID,
                                text: cw.text,
                                startTime: ts.startTime,
                                endTime: ts.endTime
                            ))
                        }
                    } else {
                        let totalChars = max(chunkWords.reduce(0) { $0 + max(1, $1.text.count) }, 1)
                        var curTime: TimeInterval = 0.0
                        for cw in chunkWords {
                            let wDuration = audioResult.duration * (Double(max(1, cw.text.count)) / Double(totalChars))
                            let endTime = curTime + wDuration
                            timingWords.append(AudiobookWordTimestamp(
                                globalWordID: cw.globalWordID,
                                text: cw.text,
                                startTime: curTime,
                                endTime: endTime
                            ))
                            curTime = endTime
                        }
                    }
                    
                    let chunkTimings = AudiobookChunkTimings(
                        chunkIndex: plan.chunkIndex,
                        chapterIndex: chapIdx,
                        words: timingWords
                    )
                    let timingData = try JSONEncoder().encode(chunkTimings)
                    try timingData.write(to: timingsDestURL)
                }
                
                totalAudioDuration += audioResult.duration
                
                let exportChunk = AudiobookExportChunk(
                    index: plan.chunkIndex,
                    chapterIndex: chapIdx,
                    audioM4A: audioRelativePath,
                    audioOpus: nil,
                    timingsPath: timingsRelativePath,
                    duration: audioResult.duration,
                    startGlobalWordID: firstWord.globalWordID,
                    endGlobalWordID: lastWord.globalWordID,
                    sentenceIDs: chunkSentences.map { $0.sentenceID }
                )
                exportChunksForChapter.append(exportChunk)
                
                // Add to document index
                for cw in chunkWords {
                    allIndexedWords.append(AudiobookIndexedWord(
                        globalWordID: cw.globalWordID,
                        page: cw.pageIndex,
                        paragraphIndex: 0,
                        sentenceIndex: cw.sentenceID,
                        chunkIndex: plan.chunkIndex,
                        chapterIndex: chapIdx,
                        pdfBoundingBox: cw.bounds.isEmpty ? nil : PDFBoxGeometry(rect: cw.bounds)
                    ))
                }
                
                await MainActor.run {
                    self.currentChunkIndex = plan.chunkIndex + 1
                    self.progressFraction = Double(self.currentChunkIndex) / Double(totalExportChunks)
                }
            }
            
            let chapterTitle = "Chapter \(chapNumber)"
            chapterManifests.append(AudiobookChapterManifest(
                index: chapIdx,
                title: chapterTitle,
                startPage: chapterStartPage,
                endPage: chapterEndPage,
                chunks: exportChunksForChapter
            ))
        }
        
        // 3. Write document_index.json
        let docIndex = AudiobookDocumentIndex(words: allIndexedWords)
        let indexURL = bundleDir.appendingPathComponent("document_index.json")
        let indexData = try JSONEncoder().encode(docIndex)
        try indexData.write(to: indexURL)
        
        // 4. Write manifest.json
        let manifest = AudiobookManifest(
            version: 1,
            documentHash: docHash,
            title: document.title,
            author: nil,
            generatedAt: Date(),
            model: adapter.metadata.id,
            voice: voice,
            speed: speed,
            sampleRate: 24000.0,
            totalDuration: totalAudioDuration,
            totalChunks: totalExportChunks,
            chapters: chapterManifests
        )
        
        let manifestURL = bundleDir.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: manifestURL)
        
        // Refresh sync manager
        iCloudSyncManager.shared.refreshAvailableBundles()
        
        await MainActor.run {
            self.isGenerating = false
            self.lastGeneratedManifest = manifest
            self.statusMessage = "Audiobook generated successfully!"
        }
        
        return manifest
    }
    
    // MARK: - Helpers
    
    private func groupSentencesIntoChapters(document: SemanticDocument) -> [[SemanticSentence]] {
        if document.sentences.isEmpty { return [] }
        
        // Check if blocks have headings to delineate chapters
        var chapters: [[SemanticSentence]] = []
        var currentChapter: [SemanticSentence] = []
        
        for sentence in document.sentences {
            if sentence.blockType == .heading && !currentChapter.isEmpty {
                chapters.append(currentChapter)
                currentChapter.removeAll()
            }
            currentChapter.append(sentence)
        }
        
        if !currentChapter.isEmpty {
            chapters.append(currentChapter)
        }
        
        return chapters.isEmpty ? [document.sentences] : chapters
    }
}
