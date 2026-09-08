//
//  TTSController.swift
//  Vachanam
//
//  Central TTS Playback Coordinator & Model Manager:
//  - 3-Layer architecture (PDF Layout, Semantic Text, Audio Timeline)
//  - Stable globalWordID and sentenceID indexing across pages
//  - Two-tier content-hashed audio caching
//  - Rolling background pre-generation of upcoming chunks
//  - Full task cancellation (latest user action wins, no stuck playback)
//

import Foundation
import Combine
import AVFoundation
import CoreGraphics

public class TTSController: ObservableObject {
    public static let shared = TTSController()
    
    // Playback State (Synchronized with PlaybackCoordinator)
    @Published public var isPlaying: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var isGenerating: Bool = false
    
    // Stable Global Indexing
    @Published public var currentWordID: Int?
    @Published public var currentSentenceID: Int?
    @Published public var currentChunkID: Int?
    
    // Backward-compatible properties for existing views
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
    
    // Access to PlaybackCoordinator
    public var coordinator: PlaybackCoordinator { PlaybackCoordinator.shared }
    
    public var activeSemanticDocument: SemanticDocument? {
        PlaybackCoordinator.shared.activeSemanticDocument
    }
    
    private var activeAdapter: TTSModelProtocol
    public var currentAdapter: TTSModelProtocol { activeAdapter }
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    public var onPageCompleted: (() -> Void)?
    public var onPageChanged: ((Int) -> Void)?
    
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
        
        // Observe PlaybackCoordinator properties
        let coord = PlaybackCoordinator.shared
        
        coord.$isPlaying
            .receive(on: RunLoop.main)
            .assign(to: &$isPlaying)
        
        coord.$isPaused
            .receive(on: RunLoop.main)
            .assign(to: &$isPaused)
        
        coord.$isGenerating
            .receive(on: RunLoop.main)
            .assign(to: &$isGenerating)
        
        coord.$currentWordID
            .receive(on: RunLoop.main)
            .assign(to: &$currentWordID)
        
        coord.$currentSentenceID
            .receive(on: RunLoop.main)
            .assign(to: &$currentSentenceID)
        
        coord.$currentChunkID
            .receive(on: RunLoop.main)
            .assign(to: &$currentChunkID)
        
        coord.$currentSentence
            .receive(on: RunLoop.main)
            .assign(to: &$currentSentence)
        
        coord.$currentSentenceIndex
            .receive(on: RunLoop.main)
            .assign(to: &$currentSentenceIndex)
        
        coord.$currentWord
            .receive(on: RunLoop.main)
            .assign(to: &$currentWord)
        
        coord.$currentWordIndex
            .receive(on: RunLoop.main)
            .assign(to: &$currentWordIndex)
        
        coord.onPageChanged = { [weak self] page in
            self?.onPageChanged?(page)
        }
        
        coord.onPageCompleted = { [weak self] in
            self?.onPageCompleted?()
        }
    }
    
    // MARK: - Model Management
    
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
    
    // MARK: - Document Loading & Playback Forwarding
    
    /// Loads a full SemanticDocument into the PlaybackCoordinator.
    public func loadDocument(_ document: SemanticDocument, initialSentenceID: Int = 0) {
        PlaybackCoordinator.shared.loadDocument(document, initialSentenceID: initialSentenceID)
    }
    
    /// Legacy array-based sentence loader for backward compatibility.
    public func loadSentences(_ items: [SentenceItem], startIndex: Int = 0) {
        self.currentSentenceIndex = min(startIndex, max(items.count - 1, 0))
        if !items.isEmpty && currentSentenceIndex < items.count {
            self.currentSentence = items[currentSentenceIndex]
            self.currentWord = items[currentSentenceIndex].words.first
            self.currentSentenceID = items[currentSentenceIndex].sentenceIndex
            self.currentWordID = items[currentSentenceIndex].words.first?.globalWordID
        } else {
            self.currentSentence = nil
            self.currentWord = nil
            self.currentSentenceID = nil
            self.currentWordID = nil
        }
    }
    
    public func play() {
        PlaybackCoordinator.shared.play()
    }
    
    public func play(scope: PlaybackScope) {
        PlaybackCoordinator.shared.play(scope: scope)
    }
    
    public func play(page: Int) {
        PlaybackCoordinator.shared.play(page: page)
    }
    
    public func pause() {
        PlaybackCoordinator.shared.pause()
    }
    
    public func stop() {
        PlaybackCoordinator.shared.stop()
    }
    
    public func jumpTo(globalWordID: Int) {
        PlaybackCoordinator.shared.play(fromWordID: globalWordID)
    }
    
    public func jumpTo(sentenceID: Int) {
        guard let doc = activeSemanticDocument,
              let sentence = doc.sentence(id: sentenceID),
              let firstWord = sentence.words.first else {
            return
        }
        PlaybackCoordinator.shared.play(fromWordID: firstWord.globalWordID)
    }
    
    public func nextSentence() {
        PlaybackCoordinator.shared.nextSentence()
    }
    
    public func previousSentence() {
        PlaybackCoordinator.shared.previousSentence()
    }
}
