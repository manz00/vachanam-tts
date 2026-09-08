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
    
    private var sentences: [SentenceItem] = []
    private var activeAdapter: TTSModelProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public var onPageCompleted: (() -> Void)?
    
    public init() {
        self.activeAdapter = KokoroAdapter()
        setupObservers()
        
        SleepTimer.shared.onTimerFired = { [weak self] in
            self?.stop()
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
        switch modelId {
        case "kokoro-v1.0-en":
            activeAdapter = KokoroAdapter()
        case "qwen3-tts-0.6b-en":
            activeAdapter = Qwen3TTSAdapter()
        case "chatterbox-turbo-en":
            activeAdapter = ChatterboxAdapter()
        case "cosyvoice3-0.5b":
            activeAdapter = CosyVoice3Adapter()
        default:
            activeAdapter = KokoroAdapter()
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
        
        if ModelManager.shared.isModelDownloaded(activeAdapter.metadata.id) {
            Task { @MainActor in
                do {
                    let result = try await self.activeAdapter.synthesize(text: sentence.text, voice: self.selectedVoice, speed: self.speechSpeed)
                    
                    AudioSession.shared.updateNowPlaying(
                        title: sentence.text,
                        author: self.activeAdapter.metadata.name,
                        elapsedTime: 0,
                        duration: result.duration,
                        isPlaying: true
                    )
                    
                    AudioPlayer.shared.play(result: result, speed: self.speechSpeed) { [weak self] in
                        self?.nextSentence()
                    }
                } catch {
                    print("Synthesis error: \(error.localizedDescription)")
                    self.nextSentence()
                }
            }
        } else {
            // Instant, crystal-clear speech synthesis fallback with exact word tracking
            AudioSession.shared.updateNowPlaying(
                title: sentence.text,
                author: "System Voice",
                elapsedTime: 0,
                duration: Double(sentence.text.count) * 0.06,
                isPlaying: true
            )
            
            AudioPlayer.shared.speakText(
                sentence.text,
                speed: self.speechSpeed,
                onWordRange: { [weak self] range in
                    guard let self = self, let s = self.currentSentence else { return }
                    if let matched = s.words.first(where: { NSIntersectionRange($0.range, range).length > 0 }) {
                        self.currentWord = matched
                    }
                },
                onComplete: { [weak self] in
                    self?.nextSentence()
                }
            )
        }
    }
    
    private func updateWordHighlight(for time: TimeInterval) {
        guard let sentence = currentSentence, !sentence.words.isEmpty else { return }
        
        let totalDuration = AudioPlayer.shared.currentDuration
        guard totalDuration > 0 else { return }
        
        // Determine active word index based on playback time ratio
        let progressFraction = time / totalDuration
        let targetIndex = min(Int(Double(sentence.words.count) * progressFraction), sentence.words.count - 1)
        
        if targetIndex != currentWordIndex && targetIndex >= 0 {
            currentWordIndex = targetIndex
            currentWord = sentence.words[targetIndex]
        }
    }
}
