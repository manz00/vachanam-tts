//
//  AppleSystemAdapter.swift
//  Vachanam
//

import Foundation

public class AppleSystemAdapter: TTSModelProtocol {
    public var metadata: TTSModelMetadata {
        ModelRegistry.shared.model(withId: "apple-system-en") ?? TTSModelMetadata(
            id: "apple-system-en",
            name: "Apple Natural",
            version: "Built-in",
            description: "Built-in iOS speech synthesis.",
            sizeBytes: 0,
            ramRequired: 0,
            languages: ["en-US"],
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
            voices: []
        )
    }
    
    public var isLoaded: Bool = true
    public var hasNeuralWeights: Bool = false // Prevents neural synthesis fallback
    
    public init() {}
    
    public func loadModel(weightsDirectory: URL) async throws {
        // Built-in, nothing to load
    }
    
    public func unloadModel() {
        // Built-in, nothing to unload
    }
    
    public func synthesize(text: String, voice: String?, speed: Float) async throws -> TTSAudioResult {
        throw TTSError.synthesisFailed("Apple System Adapter bypasses neural synthesis and uses AVSpeechSynthesizer directly.")
    }
}
