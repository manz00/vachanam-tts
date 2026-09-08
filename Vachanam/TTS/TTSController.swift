//
//  TTSController.swift
//  Vachanam
//
//  Central TTS orchestrator: sentences queue, synthesis, audio dispatch, and live word/sentence tracking.
//

import Foundation
import Combine
import AVFoundation

public class TTSController: ObservableObject {
    public static let shared = TTSController()
    
    @Published public var isPlaying: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var currentSentenceIndex: Int = 0
    @Published public var currentSentence: SentenceItem?
    @Published public var currentWordIndex: Int = 0
    @Published public var currentWord: WordRect?
    @Published public var speechSpeed: Float = 1.0
    @Published public var selectedVoice: String?
    @Published public var currentSentenceViewRect: CGRect?
    @Published public var isModelLoaded: Bool = false
    @Published public var isModelLoading: Bool = false
    @Published public var activeAdapterMetadata: TTSModelMetadata
    
    private var sentences: [SentenceItem] = []
    private var activeAdapter: TTSModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public var onPageCompleted: (() -> Void)?
    
    public init() {
        let initialAdapter = KokoroAdapter()
        self.activeAdapter = initialAdapter
        self.activeAdapterMetadata = initialAdapter.metadata
        setupObservers()
        
        SleepTimer.shared.onTimerFired = { [weak self] in
            self?.stop()
        }
        
        // Auto-load if active model is downloaded on device
        Task { @MainActor in
            if ModelManager.shared.isModelDownloaded(initialAdapter.metadata.id) {
                await self.loadActiveModel()
            }
        }
    }
    
    private func setupObservers() {
        // Observe ModelManager active model changes
        ModelManager.shared.$activeModelId
            .sink { [weak self] newId in
                self?.switchAdapter(to: newId)
            }
            .store(in: &cancellables)
        
        // Observe AudioPlayer playback time to synchronize words
        AudioPlayer.shared.$currentTime
            .sink { [weak self] time in
                self?.updateWordHighlight(for: time)
            }
            .store(in: &cancellables)
    }
    
    public func switchAdapter(to modelId: String) {
        if activeAdapter.isLoaded {
            activeAdapter.unloadModel()
        }
        
        switch modelId {
        case "kokoro-v1.0-en":
            activeAdapter = KokoroAdapter()
        case "apple-system-en":
            activeAdapter = AppleSystemAdapter()
        default:
            activeAdapter = KokoroAdapter()
        }
        
        self.activeAdapterMetadata = activeAdapter.metadata
        self.isModelLoaded = activeAdapter.isLoaded
        
        if ModelManager.shared.isModelDownloaded(modelId) {
            Task { @MainActor in
                await self.loadActiveModel()
            }
        } else {
            ModelManager.shared.loadedModelId = nil
        }
    }
    
    @MainActor
    public func loadActiveModel() async {
        let modelId = activeAdapter.metadata.id
        guard ModelManager.shared.isModelDownloaded(modelId) else {
            isModelLoaded = false
            return
        }
        
        isModelLoading = true
        let dir = ModelManager.shared.modelDirectory(for: modelId)
        
        do {
            try await activeAdapter.loadModel(weightsDirectory: dir)
            isModelLoaded = activeAdapter.isLoaded
            ModelManager.shared.loadedModelId = modelId
        } catch {
            print("Failed to load model \(modelId): \(error.localizedDescription)")
            isModelLoaded = false
        }
        isModelLoading = false
    }
    
    @MainActor
    public func unloadActiveModel() {
        activeAdapter.unloadModel()
        isModelLoaded = false
        if ModelManager.shared.loadedModelId == activeAdapter.metadata.id {
            ModelManager.shared.loadedModelId = nil
        }
    }
    
    public func loadSentences(_ items: [SentenceItem], startIndex: Int = 0) {
        self.sentences = items
        self.currentSentenceIndex = min(startIndex, max(items.count - 1, 0))
        if !items.isEmpty && currentSentenceIndex < items.count {
            self.currentSentence = items[currentSentenceIndex]
            self.currentWord = items[currentSentenceIndex].words.first
        } else {
            self.currentSentence = nil
            self.currentWord = nil
        }
    }
    
    public func play() {
        guard !sentences.isEmpty else { return }
        if isPaused {
            AudioPlayer.shared.resume()
            isPaused = false
            isPlaying = true
            return
        }
        
        isPlaying = true
        isPaused = false
        synthesizeAndPlayCurrentSentence()
    }
    
    public func pause() {
        AudioPlayer.shared.pause()
        isPaused = true
        isPlaying = false
    }
    
    public func stop() {
        AudioPlayer.shared.stop()
        isPlaying = false
        isPaused = false
        currentWord = nil
    }
    
    public func nextSentence() {
        guard currentSentenceIndex < sentences.count - 1 else {
            onPageCompleted?()
            return
        }
        currentSentenceIndex += 1
        currentSentence = sentences[currentSentenceIndex]
        currentWordIndex = 0
        currentWord = currentSentence?.words.first
        
        if isPlaying {
            synthesizeAndPlayCurrentSentence()
        }
    }
    
    public func previousSentence() {
        guard currentSentenceIndex > 0 else { return }
        currentSentenceIndex -= 1
        currentSentence = sentences[currentSentenceIndex]
        currentWordIndex = 0
        currentWord = currentSentence?.words.first
        
        if isPlaying {
            synthesizeAndPlayCurrentSentence()
        }
    }
    
    private func synthesizeAndPlayCurrentSentence() {
        guard currentSentenceIndex < sentences.count else {
            isPlaying = false
            onPageCompleted?()
            return
        }
        
        let sentence = sentences[currentSentenceIndex]
        currentSentence = sentence
        currentWordIndex = 0
        currentWord = sentence.words.first
        
        Task { @MainActor in
            // Auto-load model if downloaded and not yet in memory
            if !self.activeAdapter.isLoaded && ModelManager.shared.isModelDownloaded(self.activeAdapter.metadata.id) {
                await self.loadActiveModel()
            }
            
            self.speakSentence(sentence)
        }
    }
    
    private func speakSentence(_ sentence: SentenceItem) {
        let profile = VoiceProfileResolver.shared.resolve(
            modelId: activeAdapter.metadata.id,
            voiceName: selectedVoice,
            text: sentence.text
        )
        
        let voiceDisplay = selectedVoice?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Natural"
        let loadedSuffix = isModelLoaded ? " • Loaded" : ""
        AudioSession.shared.updateNowPlaying(
            title: profile.cleanedText,
            author: "\(activeAdapter.metadata.name) (\(voiceDisplay))\(loadedSuffix)",
            elapsedTime: 0,
            duration: Double(profile.cleanedText.count) * 0.06,
            isPlaying: true
        )
        
        // If Apple System is selected or neural weights missing, fallback to AVSpeechSynthesizer
        if activeAdapter.metadata.id == "apple-system-en" || !activeAdapter.isLoaded || !activeAdapter.hasNeuralWeights {
            speakWithAppleTTS(profile: profile)
            return
        }
        
        // Use neural adapter
        Task { @MainActor in
            do {
                let result = try await activeAdapter.synthesize(
                    text: profile.cleanedText,
                    voice: selectedVoice,
                    speed: self.speechSpeed * profile.rateMultiplier
                )
                
                AudioPlayer.shared.play(result: result, speed: 1.0) { [weak self] in
                    self?.nextSentence()
                }
            } catch {
                print("Neural synthesis failed: \(error.localizedDescription)")
                self.speakWithAppleTTS(profile: profile)
            }
        }
    }
    
    private func speakWithAppleTTS(profile: ResolvedVoiceProfile) {
        AudioPlayer.shared.speakText(
            profile.cleanedText,
            speed: self.speechSpeed * profile.rateMultiplier,
            pitch: profile.pitchMultiplier,
            voice: profile.voice,
            onWordRange: { [weak self] charRange in
                guard let self = self, let s = self.currentSentence else { return }
                if let matched = s.words.first(where: { NSIntersectionRange($0.sentenceRange, charRange).length > 0 }) {
                    self.currentWord = matched
                    self.currentWordIndex = matched.wordIndex
                }
            },
            onComplete: { [weak self] in
                self?.nextSentence()
            }
        )
    }
    
    private func updateWordHighlight(for time: TimeInterval) {
        guard let sentence = currentSentence, !sentence.words.isEmpty else { return }
        
        let totalDuration = AudioPlayer.shared.currentDuration
        guard totalDuration > 0 else { return }
        
        // Character-weighted proportional word highlight tracking
        let totalChars = max(sentence.words.reduce(0) { $0 + $1.text.count }, 1)
        var accumulatedTime: TimeInterval = 0.0
        
        for (idx, word) in sentence.words.enumerated() {
            let wordDuration = totalDuration * (Double(word.text.count) / Double(totalChars))
            if time >= accumulatedTime && (time < (accumulatedTime + wordDuration) || idx == sentence.words.count - 1) {
                if currentWordIndex != idx {
                    currentWordIndex = idx
                    currentWord = word
                }
                return
            }
            accumulatedTime += wordDuration
        }
    }
}
