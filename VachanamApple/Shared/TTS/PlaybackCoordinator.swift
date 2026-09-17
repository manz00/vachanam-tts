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

public enum PlaybackMode: String, Sendable {
    case liveSynthesis
    case preGenerated
}

public enum ScrolledAwayDirection: String, Sendable {
    case above
    case below
}

extension Notification.Name {
    public static let jumpToSpokenSentence = Notification.Name("jumpToSpokenSentence")
}

public class PlaybackCoordinator: ObservableObject {
    public static let shared = PlaybackCoordinator()
    
    // Playback State
    @Published public var isPlaying: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var isGenerating: Bool = false
    @Published public var playbackMode: PlaybackMode = .liveSynthesis
    @Published public var preGeneratedManifest: AudiobookManifest?
    
    // User Scroll-Away Tracking
    @Published public var isUserScrolledAway: Bool = false
    @Published public var scrolledAwayDirection: ScrolledAwayDirection = .below
    @Published public var scrolledAwayPageIndex: Int?
    @Published public var scrolledAwaySnippet: String = ""
    
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
    
    public func loadDocument(_ document: SemanticDocument, initialSentenceID: Int? = nil, initialWordID: Int? = nil) {
        stop()
        activeAudioResult = nil
        
        self.activeSemanticDocument = document
        
        if let wid = initialWordID, let word = document.word(id: wid), let sentence = document.sentence(id: word.sentenceID) {
            setCursor(forWord: word, inSentence: sentence)
            if let chunk = document.chunk(forWordID: word.globalWordID) {
                self.currentChunkID = chunk.chunkID
            }
            self.visiblePageIndex = word.pageIndex
        } else if let sid = initialSentenceID, let sentence = document.sentence(id: sid), let firstWord = sentence.words.first {
            setCursor(forWord: firstWord, inSentence: sentence)
            if let chunk = document.chunk(forSentenceID: sentence.sentenceID) {
                self.currentChunkID = chunk.chunkID
            }
            self.visiblePageIndex = firstWord.pageIndex
        } else if let sentence = document.sentences.first, let firstWord = sentence.words.first {
            setCursor(forWord: firstWord, inSentence: sentence)
            if let chunk = document.chunk(forSentenceID: sentence.sentenceID) {
                self.currentChunkID = chunk.chunkID
            }
            self.visiblePageIndex = firstWord.pageIndex
        } else {
            clearCursor()
            self.visiblePageIndex = 0
        }
        
        if let c = self.cursor {
            print("[TTS] loadDocument – starting cursor at page \(c.pageIndex), word \(c.globalWordID)")
        }
        
        // Auto-detect pre-generated audiobook bundle
        if let manifest = AudiobookBundleLoader.shared.loadBundle(for: document) {
            self.playbackMode = .preGenerated
            self.preGeneratedManifest = manifest
        } else {
            self.playbackMode = .liveSynthesis
            self.preGeneratedManifest = nil
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
        self.scope = .page(page)
        guard let doc = activeSemanticDocument else { return }
        self.visiblePageIndex = page
        onPageChanged?(page)
        
        if let firstWord = doc.firstWord(onPageIndex: page),
           let sentence = doc.sentence(id: firstWord.sentenceID),
           let chunk = doc.chunk(forWordID: firstWord.globalWordID) {
            setCursor(forWord: firstWord, inSentence: sentence)
            self.currentChunkID = chunk.chunkID
            saveCurrentProgress()
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
        self.visiblePageIndex = word.pageIndex
        onPageChanged?(word.pageIndex)
        saveCurrentProgress()
        
        // Fast-path: If user taps within the currently active chunk and audio player is active, seek immediately
        if self.currentChunkID == chunk.chunkID,
           let audioResult = self.activeAudioResult,
           audioResult.duration > 0,
           AudioPlayer.shared.hasActiveAudioPlayer,
           let wordIdxInChunk = chunk.wordIDs.firstIndex(of: wordID) {
            
            var seekTime: TimeInterval = 0.0
            if wordIdxInChunk < audioResult.wordTimestamps.count {
                seekTime = audioResult.wordTimestamps[wordIdxInChunk].startTime
            } else if !chunk.wordIDs.isEmpty {
                seekTime = (Double(wordIdxInChunk) / Double(chunk.wordIDs.count)) * audioResult.duration
            }
            
            self.isPlaying = true
            self.isPaused = false
            AudioPlayer.shared.seek(to: seekTime)
            if !AudioPlayer.shared.isPlaying {
                AudioPlayer.shared.resume()
            }
            return
        }
        
        self.currentChunkID = chunk.chunkID
        playChunk(chunkID: chunk.chunkID, startWordID: wordID)
    }
    
    public func saveCurrentProgress() {
        guard let semDoc = activeSemanticDocument else { return }
        guard let doc = AppState.shared.currentDocument,
              (doc.id == semDoc.documentID || doc.title == semDoc.title) else { return }
        let page: Int
        let wordID: Int?
        let sentenceID: Int?
        
        if isPlaying, let c = cursor {
            page = c.pageIndex
            wordID = currentWordID ?? c.globalWordID
            sentenceID = currentSentenceID ?? c.sentenceIndex
        } else if let c = cursor, c.pageIndex == visiblePageIndex {
            page = visiblePageIndex
            wordID = currentWordID ?? c.globalWordID
            sentenceID = currentSentenceID ?? c.sentenceIndex
        } else {
            page = visiblePageIndex
            wordID = nil
            sentenceID = nil
        }
        
        ReadingProgressTracker.shared.recordProgress(
            documentURL: doc.fileURL,
            title: doc.title,
            currentPage: page,
            totalPages: doc.pageCount,
            lastWordID: wordID,
            lastSentenceID: sentenceID
        )
    }
    
    public func pause() {
        saveCurrentProgress()
        AudioPlayer.shared.pause()
        isPaused = true
        isPlaying = false
    }
    
    public func stop() {
        saveCurrentProgress()
        cancelActiveTasks()
        AudioPlayer.shared.stop()
        isPlaying = false
        isPaused = false
        isGenerating = false
        isUserScrolledAway = false
        activeAudioResult = nil
    }
    
    public func jumpToSpokenSentence() {
        NotificationCenter.default.post(name: .jumpToSpokenSentence, object: nil)
        isUserScrolledAway = false
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
        AudioPlayer.shared.stop(stopAmbient: false)
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
        
        // 0. Check for Pre-generated Audiobook Bundle
        if playbackMode == .preGenerated, let manifest = preGeneratedManifest,
           let (_, exportChunk) = AudiobookBundleLoader.shared.findExportChunk(forGlobalWordID: targetWordID, in: manifest),
           let preResult = PreGeneratedPlaybackAdapter.shared.loadAudioResult(for: exportChunk, in: manifest) {
            self.isGenerating = false
            self.startAudioPlayback(result: preResult, chunk: chunk, startWordID: targetWordID, requestID: requestID)
            return
        }
        
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
            
            let chunkWords = chunk.wordIDs.compactMap { doc.word(id: $0) }
            let targetWordStrings = chunkWords.map { $0.text }
            
            do {
                let result = try await adapter.synthesize(
                    text: profile.cleanedText,
                    voice: voice,
                    speed: speed * profile.rateMultiplier,
                    pauseDuration: chunk.pauseDurationAfter,
                    targetWords: targetWordStrings
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
        
        // Ensure word timestamps strictly match chunkWords 1:1, correcting any legacy cache or misaligned counts
        let chunkWords = chunk.wordIDs.compactMap { activeSemanticDocument?.word(id: $0) }
        var playbackResult = result
        if !chunkWords.isEmpty && (result.wordTimestamps.isEmpty || result.wordTimestamps.count != chunkWords.count) && result.duration > 0 {
            let totalChars = max(chunkWords.reduce(0) { $0 + max(1, $1.text.count) }, 1)
            var currentTime: TimeInterval = 0.0
            var correctedTimestamps: [WordTimestamp] = []
            for cw in chunkWords {
                let wDuration = result.duration * (Double(max(1, cw.text.count)) / Double(totalChars))
                let endTime = currentTime + wDuration
                correctedTimestamps.append(WordTimestamp(word: cw.text, startTime: currentTime, endTime: endTime))
                currentTime = endTime
            }
            playbackResult = TTSAudioResult(
                audioData: result.audioData,
                pcmBuffer: result.pcmBuffer,
                sampleRate: result.sampleRate,
                duration: result.duration,
                wordTimestamps: correctedTimestamps
            )
        }
        self.activeAudioResult = playbackResult
        
        // Prefetch next chunk in background
        triggerPreGeneration(forChunkID: chunk.chunkID + 1)
        
        // Determine start offset if seeking into the middle of the chunk
        var startTimeOffset: TimeInterval = 0.0
        if let doc = activeSemanticDocument,
           let targetWord = doc.word(id: startWordID),
           targetWord.globalWordID != chunk.wordIDs.first,
           let wordIdxInChunk = chunk.wordIDs.firstIndex(of: startWordID) {
            
            if wordIdxInChunk < playbackResult.wordTimestamps.count {
                startTimeOffset = playbackResult.wordTimestamps[wordIdxInChunk].startTime
            } else if !chunk.wordIDs.isEmpty {
                let fraction = Double(wordIdxInChunk) / Double(chunk.wordIDs.count)
                startTimeOffset = fraction * playbackResult.duration
            }
        }
        
        // Update NowPlaying Center
        let sentenceText = activeSemanticDocument?.sentence(id: currentSentenceID ?? 0)?.text ?? "Reading"
        AudioSession.shared.updateNowPlaying(
            title: sentenceText,
            author: TTSController.shared.activeAdapterMetadata.name,
            elapsedTime: startTimeOffset,
            duration: playbackResult.duration,
            isPlaying: true
        )
        
        AudioPlayer.shared.play(result: playbackResult, speed: 1.0, startTime: startTimeOffset) { [weak self] in
            guard let self = self, self.currentRequestID == requestID else { return }
            self.handleChunkCompleted(chunkID: chunk.chunkID, requestID: requestID)
        }
    }
    
    private func speakWithAppleTTS(text: String, profile: ResolvedVoiceProfile, chunk: TTSChunk, startWordID: Int, requestID: UUID) {
        var textToSpeak = text
        var effectiveWords: [SemanticWord] = []
        
        if let doc = activeSemanticDocument {
            let chunkWords = chunk.wordIDs.compactMap { doc.word(id: $0) }
            if let startIdx = chunk.wordIDs.firstIndex(of: startWordID), startIdx > 0, startIdx < chunkWords.count {
                let remainingWords = Array(chunkWords[startIdx...])
                effectiveWords = remainingWords
                textToSpeak = remainingWords.map { $0.text }.joined(separator: " ")
            } else {
                effectiveWords = chunkWords
                textToSpeak = chunkWords.map { $0.text }.joined(separator: " ")
            }
        }
        
        // Map spoken words to their exact character ranges within textToSpeak
        var spokenWordRanges: [(word: SemanticWord, range: NSRange)] = []
        let nsText = textToSpeak as NSString
        var searchPos = 0
        for word in effectiveWords {
            let wordLen = (word.text as NSString).length
            if searchPos < nsText.length {
                let remainingLen = nsText.length - searchPos
                let match = nsText.range(
                    of: word.text,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: NSRange(location: searchPos, length: remainingLen)
                )
                if match.location != NSNotFound {
                    spokenWordRanges.append((word, match))
                    searchPos = match.location + match.length
                    continue
                }
            }
            let fallbackRange = NSRange(location: min(searchPos, nsText.length), length: min(wordLen, max(0, nsText.length - searchPos)))
            spokenWordRanges.append((word, fallbackRange))
            searchPos = min(nsText.length, searchPos + wordLen + 1)
        }
        
        AudioPlayer.shared.speakText(
            textToSpeak,
            speed: TTSController.shared.speechSpeed * profile.rateMultiplier,
            pitch: profile.pitchMultiplier,
            voice: profile.voice,
            onWordRange: { [weak self] charRange in
                guard let self = self, self.currentRequestID == requestID else { return }
                guard let doc = self.activeSemanticDocument else { return }
                
                // Match speech range to mapped spokenWordRanges
                if let matchedItem = spokenWordRanges.first(where: { NSIntersectionRange($0.range, charRange).length > 0 }) ??
                   spokenWordRanges.min(by: { abs($0.range.location - charRange.location) < abs($1.range.location - charRange.location) }) {
                    let matched = matchedItem.word
                    if self.currentWordID != matched.globalWordID,
                       let semSentence = doc.sentence(id: matched.sentenceID) {
                        self.setCursor(forWord: matched, inSentence: semSentence)
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
        
        var nextChunkID = chunkID + 1
        
        // Skip any chunk whose blockType matches active skipped types
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
        
        while nextChunkID < doc.chunks.count && skippedTypes.contains(doc.chunks[nextChunkID].blockType) {
            nextChunkID += 1
        }
        
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
                // If past the end of the last word (e.g. during trailing silence pause), hold last word;
                // during inter-word gap, hold the preceding word instead of jumping back to 0.
                let lastStart = timestamps.last?.startTime ?? 0
                matchIndex = (time >= lastStart) ? (timestamps.count - 1) : max(0, min(high, timestamps.count - 1))
            }
            
            if matchIndex < chunkWords.count {
                let word = chunkWords[matchIndex]
                let matchedStamp = timestamps[matchIndex]
                
                // Telemetry: measure highlight drift outside expected word bounds
                var driftMs: Double = 0.0
                if time < matchedStamp.startTime {
                    driftMs = (matchedStamp.startTime - time) * 1000.0
                } else if time > matchedStamp.endTime && matchIndex < timestamps.count - 1 {
                    driftMs = (time - matchedStamp.endTime) * 1000.0
                }
                if driftMs > 150.0 {
                    #if DEBUG
                    print("⚠️ [Highlight Drift] Audio: \(String(format: "%.3f", time))s vs '\(word.text)' [\(String(format: "%.3f", matchedStamp.startTime))s-\(String(format: "%.3f", matchedStamp.endTime))s] (Drift: \(String(format: "%.1f", driftMs))ms)")
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
        
        let chunkWords = chunk.wordIDs.compactMap { doc.word(id: $0) }
        let targetWordStrings = chunkWords.map { $0.text }
        
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
                pauseDuration: chunk.pauseDurationAfter,
                targetWords: targetWordStrings
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
            let pronRev = PronunciationManager.shared.revisionHash(for: doc.documentID)
            let normalizedSpokenText = TextNormalizer.shared.normalizeForSpeech(chunk.text)
            let processedSpokenText = PronunciationManager.shared.applyPronunciations(to: normalizedSpokenText, documentID: doc.documentID)
            let oldKey = TTSAudioCache.shared.makeKey(
                documentID: doc.documentID,
                modelId: adapter.metadata.id,
                voice: voice,
                speed: speed,
                text: processedSpokenText,
                pronunciationRevision: pronRev
            )
            TTSAudioCache.shared.invalidate(key: oldKey)
            
            // Also invalidate with legacy chunk.text key
            let legacyKey = TTSAudioCache.shared.makeKey(
                documentID: doc.documentID,
                modelId: adapter.metadata.id,
                voice: voice,
                speed: speed,
                text: chunk.text
            )
            TTSAudioCache.shared.invalidate(key: legacyKey)
            
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
            var sentenceItem = SentenceItem(from: sentence)
            
            // Defensive runtime check: Ensure single-line sentences don't have inflated heights
            let validWordBounds = sentence.words.map { $0.bounds }.filter { !$0.isEmpty && $0.width > 0 }
            if !validWordBounds.isEmpty {
                let wordsUnion = validWordBounds.reduce(validWordBounds[0]) { $0.union($1) }
                if sentenceItem.bounds.isEmpty || (sentenceItem.lineBounds.count == 1 && sentenceItem.bounds.height > 60) {
                    sentenceItem = SentenceItem(
                        text: sentence.text,
                        range: sentenceItem.range,
                        bounds: wordsUnion,
                        lineBounds: sentenceItem.lineBounds.isEmpty ? [wordsUnion] : sentenceItem.lineBounds,
                        words: sentenceItem.words,
                        pageIndex: sentence.primaryPageIndex,
                        sentenceIndex: sentence.sentenceID
                    )
                }
            }
            self.currentSentence = sentenceItem
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
