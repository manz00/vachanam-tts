//
//  PlaybackCoordinator.swift
//  Vachanam
//
//  Authoritative Playback Coordinator:
//  - Owns the single authoritative PlaybackCursor
//  - Enforces PlaybackScope (.document, .page, .selection)
//  - Eliminates page 1 resets by starting from visiblePageIndex
//  - Enforces strict end-of-scope stopping (no looping / wrapping)
//  - Tracks currentRequestID tokens to eliminate race conditions and stuck states
//  - Synchronizes word highlighting directly via TTS word timestamps -> globalWordID
//

import Foundation
import Combine
import CoreGraphics
import AVFoundation

public struct PlaybackCursor: Equatable, Sendable {
    public let documentID: UUID
    public var pageIndex: Int
    public var paragraphIndex: Int
    public var sentenceIndex: Int
    public var wordIndex: Int
    public var globalWordID: Int
    
    public init(
        documentID: UUID,
        pageIndex: Int,
        paragraphIndex: Int = 0,
        sentenceIndex: Int,
        wordIndex: Int,
        globalWordID: Int
    ) {
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.paragraphIndex = paragraphIndex
        self.sentenceIndex = sentenceIndex
        self.wordIndex = wordIndex
        self.globalWordID = globalWordID
    }
}

public enum PlaybackScope: Equatable, Sendable {
    case document
    case page(Int)
    case selection([Int])
    
    public var isPageOnly: Bool {
        if case .page = self { return true }
        return false
    }
    
    public var targetPageIndex: Int? {
        if case .page(let page) = self { return page }
        return nil
    }
}

public class PlaybackCoordinator: ObservableObject {
    public static let shared = PlaybackCoordinator()
    
    // Playback State
    @Published public var isPlaying: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var isGenerating: Bool = false
    
    // Authoritative Cursor & Scope
    @Published public var cursor: PlaybackCursor?
    @Published public var scope: PlaybackScope = .document
    @Published public var visiblePageIndex: Int = 0
    
    // Active Positions
    @Published public var currentWordID: Int?
    @Published public var currentSentenceID: Int?
    @Published public var currentChunkID: Int?
    @Published public var currentWord: WordRect?
    @Published public var currentSentence: SentenceItem?
    @Published public var currentSentenceIndex: Int = 0
    @Published public var currentWordIndex: Int = 0
    
    // Document
    public private(set) var activeSemanticDocument: SemanticDocument?
    
    // Concurrency Tokens
    public private(set) var currentRequestID: UUID = UUID()
    private var generationTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    
    // Active Audio Result & Timings
    private var activeAudioResult: TTSAudioResult?
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    public var onPageChanged: ((Int) -> Void)?
    public var onPageCompleted: (() -> Void)?
    
    public init() {
        setupAudioTimeObserver()
    }
    
    private func setupAudioTimeObserver() {
        AudioPlayer.shared.$currentTime
            .sink { [weak self] time in
                self?.updateWordHighlight(for: time)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Document Loading
    
    public func loadDocument(_ document: SemanticDocument, initialSentenceID: Int = 0) {
        stop()
        
        self.activeSemanticDocument = document
        
        let targetSentenceID = min(max(initialSentenceID, 0), max(document.sentences.count - 1, 0))
        if let sentence = document.sentence(id: targetSentenceID), let firstWord = sentence.words.first {
            setCursor(forWord: firstWord, inSentence: sentence)
            if let chunk = document.chunk(forSentenceID: sentence.sentenceID) {
                self.currentChunkID = chunk.chunkID
            }
        } else {
            clearCursor()
        }
    }
    
    // MARK: - Visible Page Synchronization
    
    public func setVisiblePageIndex(_ pageIndex: Int) {
        guard pageIndex != visiblePageIndex, pageIndex >= 0 else { return }
        self.visiblePageIndex = pageIndex
    }
    
    // MARK: - Playback Control
    
    public func play() {
        guard let doc = activeSemanticDocument else { return }
        
        if isPaused {
            AudioPlayer.shared.resume()
            isPaused = false
            isPlaying = true
            return
        }
        
        // Rule: If cursor is missing or on a different page than visiblePageIndex,
        // start from the first word of visiblePageIndex. Do NOT jump to page 1!
        if cursor == nil || cursor?.pageIndex != visiblePageIndex {
            if let firstWordOnPage = doc.firstWord(onPageIndex: visiblePageIndex),
               let sentence = doc.sentence(id: firstWordOnPage.sentenceID) {
                setCursor(forWord: firstWordOnPage, inSentence: sentence)
                if let chunk = doc.chunk(forWordID: firstWordOnPage.globalWordID) {
                    self.currentChunkID = chunk.chunkID
                }
            }
        }
        
        let targetChunkID = currentChunkID ?? doc.chunk(forWordID: cursor?.globalWordID ?? 0)?.chunkID ?? 0
        playChunk(chunkID: targetChunkID, startWordID: cursor?.globalWordID)
    }
    
    public func play(scope: PlaybackScope) {
        self.scope = scope
        switch scope {
        case .document:
            play()
        case .page(let page):
            play(page: page)
        case .selection(let wordIDs):
            if let firstID = wordIDs.first {
                play(fromWordID: firstID)
            }
        }
    }
    
    public func play(page: Int) {
        guard let doc = activeSemanticDocument else { return }
        self.scope = .page(page)
        self.visiblePageIndex = page
        
        if let firstWord = doc.firstWord(onPageIndex: page),
           let sentence = doc.sentence(id: firstWord.sentenceID),
           let chunk = doc.chunk(forWordID: firstWord.globalWordID) {
            setCursor(forWord: firstWord, inSentence: sentence)
            self.currentChunkID = chunk.chunkID
            playChunk(chunkID: chunk.chunkID, startWordID: firstWord.globalWordID)
        }
    }
    
    public func play(fromWordID wordID: Int) {
        guard let doc = activeSemanticDocument,
              let word = doc.word(id: wordID),
              let sentence = doc.sentence(id: word.sentenceID),
              let chunk = doc.chunk(forWordID: wordID) else {
            return
        }
        
        setCursor(forWord: word, inSentence: sentence)
        self.currentChunkID = chunk.chunkID
        
        // Update visible page to match user's explicit selection
        self.visiblePageIndex = word.pageIndex
        onPageChanged?(word.pageIndex)
        
        playChunk(chunkID: chunk.chunkID, startWordID: wordID)
    }
    
    public func pause() {
        AudioPlayer.shared.pause()
        isPaused = true
        isPlaying = false
    }
    
    public func stop() {
        cancelActiveTasks()
        AudioPlayer.shared.stop()
        isPlaying = false
        isPaused = false
        isGenerating = false
        activeAudioResult = nil
    }
    
    public func nextSentence() {
        guard let doc = activeSemanticDocument else { return }
        let nextID = (currentSentenceID ?? 0) + 1
        guard nextID < doc.sentences.count else {
            stop()
            onPageCompleted?()
            return
        }
        
        if let sentence = doc.sentence(id: nextID), let firstWord = sentence.words.first {
            // Scope check
            if case .page(let p) = scope, !sentence.pageSpans.contains(p) {
                stop()
                onPageCompleted?()
                return
            }
            play(fromWordID: firstWord.globalWordID)
        }
    }
    
    public func previousSentence() {
        guard let doc = activeSemanticDocument else { return }
        let prevID = (currentSentenceID ?? 0) - 1
        guard prevID >= 0, let sentence = doc.sentence(id: prevID), let firstWord = sentence.words.first else {
            return
        }
        
        if case .page(let p) = scope, !sentence.pageSpans.contains(p) {
            return
        }
        play(fromWordID: firstWord.globalWordID)
    }
    
    // MARK: - Chunk Playback & Scope Enforcement
    
    private func playChunk(chunkID: Int, startWordID: Int? = nil) {
        guard let doc = activeSemanticDocument,
              let chunk = doc.chunk(id: chunkID) else {
            stop()
            return
        }
        
        // Check scope boundaries before starting chunk
        if case .page(let targetPage) = scope {
            if !chunk.pageSpans.contains(targetPage) {
                stop()
                onPageCompleted?()
                return
            }
        }
        
        cancelActiveTasks()
        let requestID = UUID()
        self.currentRequestID = requestID
        
        self.isPlaying = true
        self.isPaused = false
        self.isGenerating = true
        self.currentChunkID = chunkID
        
        // Resolve target word
        let targetWordID = startWordID ?? chunk.wordIDs.first ?? 0
        if let targetWord = doc.word(id: targetWordID),
           let sentence = doc.sentence(id: targetWord.sentenceID) {
            setCursor(forWord: targetWord, inSentence: sentence)
        }
        
        let adapter = TTSController.shared.currentAdapter
        let voice = TTSController.shared.selectedVoice
        let speed = TTSController.shared.speechSpeed
        
        let pronRev = PronunciationManager.shared.revisionHash(for: doc.documentID)
        let normalizedSpokenText = TextNormalizer.shared.normalizeForSpeech(chunk.text)
        let processedSpokenText = PronunciationManager.shared.applyPronunciations(to: normalizedSpokenText, documentID: doc.documentID)
        
        // 1. Check Audio Cache
        let cacheKey = TTSAudioCache.shared.makeKey(
            documentID: doc.documentID,
            modelId: adapter.metadata.id,
            voice: voice,
            speed: speed,
            text: processedSpokenText,
            pronunciationRevision: pronRev
        )
        
        if let cachedResult = TTSAudioCache.shared.retrieve(key: cacheKey) {
            self.isGenerating = false
            self.startAudioPlayback(result: cachedResult, chunk: chunk, startWordID: targetWordID, requestID: requestID)
            return
        }
        
        // 2. Synthesize Chunk Asynchronously
        generationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Auto-load neural model if needed
            if !adapter.isLoaded && ModelManager.shared.isModelDownloaded(adapter.metadata.id) {
                await TTSController.shared.loadActiveModel()
            }
            
            guard self.currentRequestID == requestID else { return }
            
            let profile = VoiceProfileResolver.shared.resolve(
                modelId: adapter.metadata.id,
                voiceName: voice,
                text: processedSpokenText
            )
            
            // Fallback to system TTS if requested or weights not present
            if adapter.metadata.id == "apple-system-en" || !adapter.isLoaded || !adapter.hasNeuralWeights {
                self.isGenerating = false
                self.speakWithAppleTTS(
                    text: profile.cleanedText,
                    profile: profile,
                    chunk: chunk,
                    startWordID: targetWordID,
                    requestID: requestID
                )
                return
            }
            
            do {
                let result = try await adapter.synthesize(
                    text: profile.cleanedText,
                    voice: voice,
                    speed: speed * profile.rateMultiplier,
                    pauseDuration: chunk.pauseDurationAfter
                )
                
                guard self.currentRequestID == requestID else { return }
                
                TTSAudioCache.shared.store(key: cacheKey, result: result)
                self.isGenerating = false
                self.startAudioPlayback(result: result, chunk: chunk, startWordID: targetWordID, requestID: requestID)
            } catch {
                guard self.currentRequestID == requestID else { return }
                print("Neural synthesis failed, falling back: \(error.localizedDescription)")
                self.isGenerating = false
                self.speakWithAppleTTS(
                    text: profile.cleanedText,
                    profile: profile,
                    chunk: chunk,
                    startWordID: targetWordID,
                    requestID: requestID
                )
            }
        }
    }
    
    private func startAudioPlayback(result: TTSAudioResult, chunk: TTSChunk, startWordID: Int, requestID: UUID) {
        guard currentRequestID == requestID else { return }
        self.activeAudioResult = result
        
        // Prefetch next chunk in background
        triggerPreGeneration(forChunkID: chunk.chunkID + 1)
        
        // Determine start offset if seeking into the middle of the chunk
        var startTimeOffset: TimeInterval = 0.0
        if let doc = activeSemanticDocument,
           let targetWord = doc.word(id: startWordID),
           targetWord.globalWordID != chunk.wordIDs.first {
            
            if let stamp = result.wordTimestamps.first(where: { $0.word == targetWord.text }) {
                startTimeOffset = stamp.startTime
            } else if let wordIdxInChunk = chunk.wordIDs.firstIndex(of: startWordID), !chunk.wordIDs.isEmpty {
                let fraction = Double(wordIdxInChunk) / Double(chunk.wordIDs.count)
                startTimeOffset = fraction * result.duration
            }
        }
        
        // Update NowPlaying Center
        let sentenceText = activeSemanticDocument?.sentence(id: currentSentenceID ?? 0)?.text ?? "Reading"
        AudioSession.shared.updateNowPlaying(
            title: sentenceText,
            author: TTSController.shared.activeAdapterMetadata.name,
            elapsedTime: startTimeOffset,
            duration: result.duration,
            isPlaying: true
        )
        
        AudioPlayer.shared.play(result: result, speed: 1.0, startTime: startTimeOffset) { [weak self] in
            guard let self = self, self.currentRequestID == requestID else { return }
            self.handleChunkCompleted(chunkID: chunk.chunkID, requestID: requestID)
        }
    }
    
    private func speakWithAppleTTS(text: String, profile: ResolvedVoiceProfile, chunk: TTSChunk, startWordID: Int, requestID: UUID) {
        AudioPlayer.shared.speakText(
            text,
            speed: TTSController.shared.speechSpeed * profile.rateMultiplier,
            pitch: profile.pitchMultiplier,
            voice: profile.voice,
            onWordRange: { [weak self] charRange in
                guard let self = self, self.currentRequestID == requestID else { return }
                guard let doc = self.activeSemanticDocument else { return }
                
                // Map speech range to semantic word
                let chunkWords = chunk.wordIDs.compactMap { doc.word(id: $0) }
                if let matched = chunkWords.first(where: { NSIntersectionRange($0.sentenceRange, charRange).length > 0 }) {
                    if self.currentWordID != matched.globalWordID {
                        self.setCursor(forWord: matched, inSentence: doc.sentence(id: matched.sentenceID)!)
                    }
                }
            },
            onComplete: { [weak self] in
                guard let self = self, self.currentRequestID == requestID else { return }
                self.handleChunkCompleted(chunkID: chunk.chunkID, requestID: requestID)
            }
        )
    }
    
    private func handleChunkCompleted(chunkID: Int, requestID: UUID) {
        guard currentRequestID == requestID, let doc = activeSemanticDocument else { return }
        
        let nextChunkID = chunkID + 1
        
        // Strict boundary check: End of document
        guard nextChunkID < doc.chunks.count else {
            stop()
            onPageCompleted?()
            return
        }
        
        let nextChunk = doc.chunks[nextChunkID]
        
        // Strict boundary check: Single-page scope
        if case .page(let targetPage) = scope {
            if !nextChunk.pageSpans.contains(targetPage) {
                stop()
                onPageCompleted?()
                return
            }
        }
        
        // Advance to next chunk
        playChunk(chunkID: nextChunkID)
    }
    
    // MARK: - Word Tracking & Highlighting
    
    private func updateWordHighlight(for time: TimeInterval) {
        guard isPlaying,
              let doc = activeSemanticDocument,
              let chunkID = currentChunkID,
              let chunk = doc.chunk(id: chunkID),
              !chunk.wordIDs.isEmpty else {
            return
        }
        
        let chunkWords = chunk.wordIDs.compactMap { doc.word(id: $0) }
        guard !chunkWords.isEmpty else { return }
        
        // 1. Fast binary-search lookup in generated neural word timestamps
        if let timestamps = activeAudioResult?.wordTimestamps, !timestamps.isEmpty {
            var low = 0
            var high = timestamps.count - 1
            var matchIndex = -1
            
            while low <= high {
                let mid = (low + high) / 2
                let stamp = timestamps[mid]
                if time < stamp.startTime {
                    high = mid - 1
                } else if time >= stamp.endTime && mid < timestamps.count - 1 {
                    low = mid + 1
                } else {
                    matchIndex = mid
                    break
                }
            }
            
            if matchIndex < 0 {
                // If past the end of the last word (e.g. during trailing silence pause), hold last word
                matchIndex = (time >= timestamps.last!.startTime) ? (timestamps.count - 1) : 0
            }
            
            if matchIndex < chunkWords.count {
                let word = chunkWords[matchIndex]
                let matchedStamp = timestamps[matchIndex]
                
                // Telemetry: measure highlight drift against expected word time
                let expectedWordCenter = (matchedStamp.startTime + matchedStamp.endTime) / 2.0
                let driftMs = abs(time - expectedWordCenter) * 1000.0
                if driftMs > 150.0 && time < matchedStamp.endTime {
                    #if DEBUG
                    print("⚠️ [Highlight Drift] Audio: \(String(format: "%.3f", time))s vs '\(word.text)' center: \(String(format: "%.3f", expectedWordCenter))s (Drift: \(String(format: "%.1f", driftMs))ms)")
                    #endif
                }
                
                if currentWordID != word.globalWordID {
                    if let s = doc.sentence(id: word.sentenceID) {
                        setCursor(forWord: word, inSentence: s)
                    }
                }
            }
            return
        }
        
        // 2. Fallback to proportional character timing
        let totalDuration = AudioPlayer.shared.currentDuration
        guard totalDuration > 0 else { return }
        
        let totalChars = max(chunkWords.reduce(0) { $0 + $1.text.count }, 1)
        var accumulated: TimeInterval = 0.0
        
        for (idx, word) in chunkWords.enumerated() {
            let wordDuration = totalDuration * (Double(word.text.count) / Double(totalChars))
            if time >= accumulated && (time < (accumulated + wordDuration) || idx == chunkWords.count - 1) {
                if currentWordID != word.globalWordID {
                    if let s = doc.sentence(id: word.sentenceID) {
                        setCursor(forWord: word, inSentence: s)
                    }
                }
                return
            }
            accumulated += wordDuration
        }
    }
    
    // MARK: - Pre-Generation
    
    private func triggerPreGeneration(forChunkID chunkID: Int) {
        guard let doc = activeSemanticDocument,
              let chunk = doc.chunk(id: chunkID) else {
            return
        }
        
        // Respect scope
        if case .page(let p) = scope, !chunk.pageSpans.contains(p) {
            return
        }
        
        let adapter = TTSController.shared.currentAdapter
        guard adapter.isLoaded, adapter.hasNeuralWeights else { return }
        
        let voice = TTSController.shared.selectedVoice
        let speed = TTSController.shared.speechSpeed
        let modelId = adapter.metadata.id
        
        let pronRev = PronunciationManager.shared.revisionHash(for: doc.documentID)
        let normalizedSpokenText = TextNormalizer.shared.normalizeForSpeech(chunk.text)
        let processedSpokenText = PronunciationManager.shared.applyPronunciations(to: normalizedSpokenText, documentID: doc.documentID)
        
        let cacheKey = TTSAudioCache.shared.makeKey(
            documentID: doc.documentID,
            modelId: modelId,
            voice: voice,
            speed: speed,
            text: processedSpokenText,
            pronunciationRevision: pronRev
        )
        
        if TTSAudioCache.shared.retrieve(key: cacheKey) != nil {
            return
        }
        
        prefetchTask?.cancel()
        prefetchTask = Task.detached(priority: .utility) {
            let profile = VoiceProfileResolver.shared.resolve(
                modelId: modelId,
                voiceName: voice,
                text: processedSpokenText
            )
            
            if let result = try? await adapter.synthesize(
                text: profile.cleanedText,
                voice: voice,
                speed: speed * profile.rateMultiplier,
                pauseDuration: chunk.pauseDurationAfter
            ) {
                TTSAudioCache.shared.store(key: cacheKey, result: result)
            }
        }
    }
    
    // MARK: - Pronunciation Correction
    
    public func fixPronunciation(
        for word: SemanticWord,
        spokenReplacement: String,
        scope: PronunciationScope
    ) {
        guard let doc = activeSemanticDocument else { return }
        let rule = PronunciationRule(
            match: word.text,
            spokenText: spokenReplacement,
            scope: scope,
            documentID: (scope == .book) ? doc.documentID : nil,
            note: "User correction"
        )
        PronunciationManager.shared.addRule(rule)
        
        // Invalidate cached audio for the chunk containing this word
        if let chunk = doc.chunk(forWordID: word.globalWordID) {
            let adapter = TTSController.shared.currentAdapter
            let voice = TTSController.shared.selectedVoice
            let speed = TTSController.shared.speechSpeed
            let oldKey = TTSAudioCache.shared.makeKey(
                documentID: doc.documentID,
                modelId: adapter.metadata.id,
                voice: voice,
                speed: speed,
                text: chunk.text
            )
            TTSAudioCache.shared.invalidate(key: oldKey)
            
            // If currently playing this chunk, immediately replay from this word
            if currentChunkID == chunk.chunkID && isPlaying {
                play(fromWordID: word.globalWordID)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func setCursor(forWord word: SemanticWord, inSentence sentence: SemanticSentence) {
        let newCursor = PlaybackCursor(
            documentID: activeSemanticDocument?.documentID ?? UUID(),
            pageIndex: word.pageIndex,
            paragraphIndex: sentence.paragraphID,
            sentenceIndex: sentence.sentenceID,
            wordIndex: word.wordIndexInSentence,
            globalWordID: word.globalWordID
        )
        self.cursor = newCursor
        self.currentWordID = word.globalWordID
        self.currentWord = WordRect(from: word)
        self.currentWordIndex = word.wordIndexInSentence
        
        if self.currentSentenceID != sentence.sentenceID {
            self.currentSentenceID = sentence.sentenceID
            self.currentSentenceIndex = sentence.sentenceID
            self.currentSentence = SentenceItem(from: sentence)
        }
        
        // If playing and word moves to another page, notify page change
        if isPlaying && word.pageIndex != visiblePageIndex {
            self.visiblePageIndex = word.pageIndex
            onPageChanged?(word.pageIndex)
        }
    }
    
    private func clearCursor() {
        self.cursor = nil
        self.currentWordID = nil
        self.currentWord = nil
        self.currentSentenceID = nil
        self.currentSentence = nil
        self.currentChunkID = nil
    }
    
    private func cancelActiveTasks() {
        generationTask?.cancel()
        generationTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
        isGenerating = false
    }
}
