//
//  KokoroAdapter.swift
//  Vachanam
//
//  Kokoro 82M CoreML adapter with Misaki G2P and word timestamp estimation.
//

import Foundation
import AVFoundation
import KokoroTTS

public class KokoroAdapter: TTSModelProtocol {
    public let metadata: TTSModelMetadata
    public private(set) var isLoaded: Bool = false
    private let g2p: G2PProtocol
    
    private var tts: KokoroTTS?
    
    private static let initializeEnvironment: Void = {
        setenv("MLX_METAL_GPU_ARCH", "appleg14g", 0)
    }()
    
    public var hasNeuralWeights: Bool {
        if let bundleURL = Bundle.main.url(forResource: "KokoroModels", withExtension: nil) {
            let manifest = bundleURL.appendingPathComponent("KokoroRuntimeManifest.json")
            return FileManager.default.fileExists(atPath: manifest.path)
        }
        return false
    }
    
    public init(metadata: TTSModelMetadata? = nil, g2p: G2PProtocol = MisakiG2P.shared) {
        _ = Self.initializeEnvironment
        self.metadata = metadata ?? ModelRegistry.shared.model(withId: "kokoro-v1.0-en")!
        self.g2p = g2p
    }
    
    public func loadModel(weightsDirectory: URL) async throws {
        _ = Self.initializeEnvironment
        let manifestFile = weightsDirectory.appendingPathComponent("KokoroRuntimeManifest.json")
        let modelsURL: URL
        if FileManager.default.fileExists(atPath: manifestFile.path) {
            modelsURL = weightsDirectory
        } else if let bundleURL = Bundle.main.url(forResource: "KokoroModels", withExtension: nil) {
            modelsURL = bundleURL
        } else {
            throw TTSError.weightsNotFound
        }
        
        let resources = KokoroResourceProvider.directory(modelsURL)
        self.tts = try await KokoroTTS.load(resources: resources)
        
        // Warm up Misaki phonemizer
        _ = g2p.phonemize(text: "Kokoro neural reader ready", language: "en-US")
        
        // Prewarm the CoreML pipeline
        try? await self.tts?.prewarm(text: "Hello world.", voice: .afHeart)
        
        isLoaded = true
    }
    
    public func unloadModel() {
        self.tts = nil
        isLoaded = false
    }
    
    public func synthesize(text: String, voice: String?, speed: Float) async throws -> TTSAudioResult {
        guard isLoaded, let tts = self.tts else {
            throw TTSError.modelNotLoaded
        }
        
        let voiceId: KokoroVoiceID
        if let voice = voice, !voice.isEmpty {
            voiceId = KokoroVoiceID(voice)
        } else {
            voiceId = .afHeart
        }
        
        let safeSpeed = speed > 0.0 ? speed : 1.0
        let options = KokoroSynthesisOptions(speed: safeSpeed)
        
        let generatedAudio = try await tts.synthesize(text, voice: voiceId, options: options)
        let buffer = try generatedAudio.makePCMBuffer()
        let duration = generatedAudio.durationSeconds
        
        let audioData = generatedAudio.samples.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
        
        // Calculate estimated word timestamps for read-along highlighting
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var timestamps: [WordTimestamp] = []
        if !words.isEmpty && duration > 0 {
            let totalChars = max(words.reduce(0) { $0 + $1.count }, 1)
            var currentTime: TimeInterval = 0.0
            for word in words {
                let wordDuration = duration * (Double(word.count) / Double(totalChars))
                let endTime = currentTime + wordDuration
                timestamps.append(WordTimestamp(word: word, startTime: currentTime, endTime: endTime))
                currentTime = endTime
            }
        }
        
        return TTSAudioResult(
            audioData: audioData,
            pcmBuffer: buffer,
            sampleRate: Double(generatedAudio.sampleRate),
            duration: duration,
            wordTimestamps: timestamps
        )
    }
}
