//
//  KokoroAdapter.swift
//  Vachanam
//
//  Kokoro 82M CoreML adapter with Misaki G2P and word timestamp estimation.
//

import Foundation
import AVFoundation
import NaturalLanguage
import KokoroTTS
import KokoroPipeline

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
        if let meta = metadata ?? ModelRegistry.shared.model(withId: "kokoro-v1.0-en") {
            self.metadata = meta
        } else {
            self.metadata = TTSModelMetadata(
                id: "kokoro-v1.0-en",
                name: "Kokoro",
                version: "v1.0",
                description: "High-quality 82M parameter CoreML neural voice model.",
                sizeBytes: 82 * 1024 * 1024,
                ramRequired: 500 * 1024 * 1024,
                languages: ["en-US", "en-GB"],
                format: .coreML,
                requiresG2P: true,
                g2pEngine: "misaki",
                quality: .premium,
                supportsVoiceCloning: false,
                supportsEmotionControl: false,
                supportsStreaming: true,
                supportsWordTimestamps: true,
                minDeviceRAM: 4,
                tier: .lightweight,
                voices: ["af_heart", "af_bella", "af_nicole", "af_sarah", "af_sky", "am_adam", "am_michael", "bf_emma", "bf_isabella", "bm_george", "bm_lewis"]
            )
        }
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
        return try await synthesize(text: text, voice: voice, speed: speed, targetWords: nil)
    }
    
    public func synthesize(text: String, voice: String?, speed: Float, pauseDuration: TimeInterval) async throws -> TTSAudioResult {
        return try await synthesize(text: text, voice: voice, speed: speed, pauseDuration: pauseDuration, targetWords: nil)
    }
    
    public func synthesize(
        text: String,
        voice: String?,
        speed: Float,
        pauseDuration: TimeInterval,
        targetWords: [String]?
    ) async throws -> TTSAudioResult {
        let base = try await synthesize(text: text, voice: voice, speed: speed, targetWords: targetWords)
        guard pauseDuration > 0 else { return base }
        return base.withAppendedSilence(duration: pauseDuration)
    }
    
    public func synthesize(
        text: String,
        voice: String?,
        speed: Float,
        targetWords: [String]? = nil
    ) async throws -> TTSAudioResult {
        guard isLoaded, let tts = self.tts else {
            throw TTSError.modelNotLoaded
        }
        
        let requestedVoiceId: KokoroVoiceID
        if let voice = voice, !voice.isEmpty {
            requestedVoiceId = KokoroVoiceID(voice)
        } else {
            requestedVoiceId = .afHeart
        }
        
        let safeSpeed = speed > 0.0 ? speed : 1.0
        let options = KokoroSynthesisOptions(speed: safeSpeed)
        
        // Stage 1: Text preparation and Misaki phonemization
        let startTotal = CACurrentMediaTime()
        let prepared: [KokoroPreparedInput]
        do {
            prepared = try await tts.prepare(text, voice: requestedVoiceId, options: options)
        } catch KokoroError.unsupportedVoice {
            // Fallback to bundled default voice if requested voice embedding is absent
            prepared = try await tts.prepare(text, voice: .afHeart, options: options)
        }
        let endPrep = CACurrentMediaTime()
        
        // Stage 2: Core ML Model Inference (Duration, F0, Decoder Pre/Post)
        let generatedAudio = try await tts.synthesizePrepared(prepared)
        let endInference = CACurrentMediaTime()
        
        // Stage 3: Audio Buffer & Timestamp Processing
        let buffer = try generatedAudio.makePCMBuffer()
        let duration = generatedAudio.durationSeconds
        
        let audioData = generatedAudio.samples.withUnsafeBufferPointer { (ptr: UnsafeBufferPointer<Float>) in
            Data(buffer: ptr)
        }
        
        // Calculate estimated word timestamps for read-along highlighting
        let wordsToTimestamp: [String]
        if let targetWords = targetWords, !targetWords.isEmpty {
            wordsToTimestamp = targetWords
        } else {
            // Extract individual spoken words via NLTokenizer, eliminating bullet symbols and splitting compound words
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = text
            var extracted: [String] = []
            let fullRange = text.startIndex..<text.endIndex
            tokenizer.enumerateTokens(in: fullRange) { range, _ in
                let token = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !token.isEmpty {
                    extracted.append(token)
                }
                return true
            }
            wordsToTimestamp = extracted.isEmpty ? text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty } : extracted
        }
        
        var timestamps: [WordTimestamp] = []
        if !wordsToTimestamp.isEmpty && duration > 0 {
            let totalChars = max(wordsToTimestamp.reduce(0) { $0 + max(1, $1.count) }, 1)
            var currentTime: TimeInterval = 0.0
            for word in wordsToTimestamp {
                let wordDuration = duration * (Double(max(1, word.count)) / Double(totalChars))
                let endTime = currentTime + wordDuration
                timestamps.append(WordTimestamp(word: word, startTime: currentTime, endTime: endTime))
                currentTime = endTime
            }
        }
        let endTotal = CACurrentMediaTime()
        
        // Record telemetry metrics
        let prepMs = (endPrep - startTotal) * 1000.0
        let inferenceMs = (endInference - endPrep) * 1000.0
        let postMs = (endTotal - endInference) * 1000.0
        let totalMs = (endTotal - startTotal) * 1000.0
        
        TTSMetricsLogger.shared.record(metrics: SynthesisTimingMetrics(
            modelId: metadata.id,
            textSnippet: text,
            characterCount: text.count,
            wordCount: wordsToTimestamp.count,
            audioDuration: duration,
            textProcessingMs: prepMs * 0.3,
            phonemizationMs: prepMs * 0.7,
            modelInferenceMs: inferenceMs,
            audioPostProcessingMs: postMs,
            totalLatencyMs: totalMs
        ))
        
        return TTSAudioResult(
            audioData: audioData,
            pcmBuffer: buffer,
            sampleRate: Double(generatedAudio.sampleRate),
            duration: duration,
            wordTimestamps: timestamps
        )
    }
}
