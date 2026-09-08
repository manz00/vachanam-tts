//
//  ModelRegistry.swift
//  Vachanam
//
//  Loads and catalogues the available on-device TTS models.
//

import Foundation

public struct RegistryContainer: Codable {
    public let registryVersion: String
    public let models: [TTSModelMetadata]
}

public class ModelRegistry {
    public static let shared = ModelRegistry()
    
    public private(set) var availableModels: [TTSModelMetadata] = []
    
    public init() {
        loadRegistry()
    }
    
    public func model(withId id: String) -> TTSModelMetadata? {
        availableModels.first { $0.id == id }
    }
    
    private func loadRegistry() {
        if let url = Bundle.main.url(forResource: "model_registry", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let container = try? JSONDecoder().decode(RegistryContainer.self, from: data) {
            self.availableModels = container.models
            return
        }
        
        // Fallback default definitions
        self.availableModels = [
            TTSModelMetadata(
                id: "apple-system-en",
                name: "Apple Natural",
                version: "Built-in",
                description: "Built-in iOS speech synthesis. Fast, zero download, works offline.",
                sizeBytes: 0,
                ramRequired: 0,
                languages: ["en-US", "en-GB", "en-AU", "en-IE", "en-ZA"],
                format: .coreML,
                requiresG2P: false,
                g2pEngine: nil,
                quality: .standard,
                supportsVoiceCloning: false,
                supportsEmotionControl: false,
                supportsStreaming: true,
                supportsWordTimestamps: true,
                minDeviceRAM: 0,
                tier: .lightweight,
                voices: ["samantha", "alex", "victoria", "daniel", "karen"]
            ),
            TTSModelMetadata(
                id: "kokoro-v1.0-en",
                name: "Kokoro",
                version: "1.0",
                description: "Fast, lightweight English narration. Runs on all devices. Best for long-form reading.",
                sizeBytes: 88_000_000,
                ramRequired: 300_000_000,
                languages: ["en-US", "en-GB"],
                format: .coreML,
                requiresG2P: true,
                g2pEngine: "misaki",
                quality: .standard,
                supportsVoiceCloning: false,
                supportsEmotionControl: false,
                supportsStreaming: false,
                supportsWordTimestamps: false,
                minDeviceRAM: 4,
                tier: .lightweight,
                voices: ["af_heart", "af_bella", "am_michael", "am_adam", "bf_emma", "bm_george"]
            ),
            TTSModelMetadata(
                id: "qwen3-tts-0.6b-en",
                name: "Qwen3-TTS",
                version: "0.6B",
                description: "Premium quality with voice cloning & emotional control. Requires 8GB+ RAM.",
                sizeBytes: 2_520_000_000,
                ramRequired: 4_000_000_000,
                languages: ["en-US"],
                format: .coreML,
                requiresG2P: false,
                g2pEngine: nil,
                quality: .premium,
                supportsVoiceCloning: true,
                supportsEmotionControl: true,
                supportsStreaming: true,
                supportsWordTimestamps: true,
                minDeviceRAM: 8,
                tier: .heavy,
                voices: ["qwen_natural_neutral", "qwen_warm_narrator", "qwen_expressive_female"]
            ),
            TTSModelMetadata(
                id: "chatterbox-turbo-en",
                name: "Chatterbox",
                version: "Turbo",
                description: "Expressive speech with emotion tags ([laugh], [sigh]). Voice cloning from 5s audio.",
                sizeBytes: 1_500_000_000,
                ramRequired: 3_500_000_000,
                languages: ["en-US", "en-GB"],
                format: .coreML,
                requiresG2P: false,
                g2pEngine: nil,
                quality: .premium,
                supportsVoiceCloning: true,
                supportsEmotionControl: true,
                supportsStreaming: false,
                supportsWordTimestamps: false,
                minDeviceRAM: 8,
                tier: .heavy,
                voices: ["cb_expressive_male", "cb_expressive_female", "cb_storyteller"]
            ),
            TTSModelMetadata(
                id: "cosyvoice3-0.5b",
                name: "CosyVoice 3",
                version: "0.5B-4bit",
                description: "High-quality multilingual TTS with voice cloning. 4-bit quantized for on-device.",
                sizeBytes: 1_200_000_000,
                ramRequired: 2_500_000_000,
                languages: ["en-US"],
                format: .mlx,
                requiresG2P: false,
                g2pEngine: nil,
                quality: .premium,
                supportsVoiceCloning: true,
                supportsEmotionControl: false,
                supportsStreaming: true,
                supportsWordTimestamps: true,
                minDeviceRAM: 8,
                tier: .heavy,
                voices: ["cv_balanced_warm", "cv_clear_academic", "cv_soft_story"]
            )
        ]
    }
}
