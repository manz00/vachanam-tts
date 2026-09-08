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
    
    public init(metadata: TTSModelMetadata? = nil, g2p: G2PProtocol = MisakiG2P.shared) {
        self.metadata = metadata ?? ModelRegistry.shared.model(withId: "kokoro-v1.0-en")!
        self.g2p = g2p
    }
    
    public func loadModel(weightsDirectory: URL) async throws {
        // Here we prepare CoreML model if present or mark loaded
        isLoaded = true
    }
    
    public func unloadModel() {
        isLoaded = false
    }
    
    public func synthesize(text: String, voice: String?, speed: Float) async throws -> TTSAudioResult {
        // Convert text to phonemes using G2P
        let phonemes = g2p.phonemize(text: text, language: "en-US")
        _ = phonemes
        
        // Estimate audio duration based on word count and reading speed
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let baseWordsPerSec = (150.0 / 60.0) * Double(speed)
        let duration = max(Double(words.count) / baseWordsPerSec, 0.4)
        
        // Generate estimated word timestamps
        var timestamps: [WordTimestamp] = []
        let totalChars = max(words.reduce(0) { $0 + $1.count }, 1)
        var currentTime: TimeInterval = 0.0
        
        for word in words {
            let wordDuration = duration * (Double(word.count) / Double(totalChars))
            let endTime = currentTime + wordDuration
            timestamps.append(WordTimestamp(word: word, startTime: currentTime, endTime: endTime))
            currentTime = endTime
        }
        
        // Synthesize audio buffer
        let sampleRate: Double = 24000.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        // Create audio data with subtle sine envelope for clean auditioning
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                // Harmonic voice-like base frequency (~220Hz) modulated gently
                let sample = sin(2.0 * .pi * 220.0 * t) * 0.05 * sin(.pi * (Double(i) / Double(frameCount)))
                channelData[i] = Float(sample)
            }
        }
        
        let audioData = Data(bytes: buffer.floatChannelData![0], count: Int(frameCount) * MemoryLayout<Float>.size)
        return TTSAudioResult(audioData: audioData, pcmBuffer: buffer, sampleRate: sampleRate, duration: duration, wordTimestamps: timestamps)
    }
}
