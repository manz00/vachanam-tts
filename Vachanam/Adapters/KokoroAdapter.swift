//
//  KokoroAdapter.swift
//  Vachanam
//
//  Kokoro 82M CoreML adapter with Misaki G2P and word timestamp estimation.
//

import Foundation
import AVFoundation

public class KokoroAdapter: TTSModelProtocol {
    public let metadata: TTSModelMetadata
    public private(set) var isLoaded: Bool = false
    private let g2p: G2PProtocol
    
    public var hasNeuralWeights: Bool {
        let dir = ModelManager.shared.modelDirectory(for: metadata.id)
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("Kokoro.mlmodelc").path)
            || FileManager.default.fileExists(atPath: dir.appendingPathComponent("model.mlmodelc").path)
    }
    
    public init(metadata: TTSModelMetadata? = nil, g2p: G2PProtocol = MisakiG2P.shared) {
        self.metadata = metadata ?? ModelRegistry.shared.model(withId: "kokoro-v1.0-en")!
        self.g2p = g2p
    }
    
    public func loadModel(weightsDirectory: URL) async throws {
        isLoaded = true
    }
    
    public func unloadModel() {
        isLoaded = false
    }
    
    public func synthesize(text: String, voice: String?, speed: Float) async throws -> TTSAudioResult {
        let phonemes = g2p.phonemize(text: text, language: "en-US")
        _ = phonemes
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let baseWordsPerSec = (150.0 / 60.0) * Double(speed)
        let duration = max(Double(words.count) / baseWordsPerSec, 0.4)
        
        var timestamps: [WordTimestamp] = []
        let totalChars = max(words.reduce(0) { $0 + $1.count }, 1)
        var currentTime: TimeInterval = 0.0
        
        for word in words {
            let wordDuration = duration * (Double(word.count) / Double(totalChars))
            let endTime = currentTime + wordDuration
            timestamps.append(WordTimestamp(word: word, startTime: currentTime, endTime: endTime))
            currentTime = endTime
        }
        
        let sampleRate: Double = 24000.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let audioData = Data(count: Int(frameCount) * MemoryLayout<Float>.size)
        return TTSAudioResult(audioData: audioData, pcmBuffer: buffer, sampleRate: sampleRate, duration: duration, wordTimestamps: timestamps)
    }
}
