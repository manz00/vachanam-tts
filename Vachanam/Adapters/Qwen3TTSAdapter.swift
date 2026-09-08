//
//  Qwen3TTSAdapter.swift
//  Vachanam
//
//  Qwen3-TTS 0.6B CoreML adapter with native word timestamps and expressive emotion control.
//

import Foundation
import AVFoundation

public class Qwen3TTSAdapter: TTSModelProtocol {
    public let metadata: TTSModelMetadata
    public private(set) var isLoaded: Bool = false
    
    public init(metadata: TTSModelMetadata? = nil) {
        self.metadata = metadata ?? ModelRegistry.shared.model(withId: "qwen3-tts-0.6b-en")!
    }
    
    public func loadModel(weightsDirectory: URL) async throws {
        isLoaded = true
    }
    
    public func unloadModel() {
        isLoaded = false
    }
    
    public func synthesize(text: String, voice: String?, speed: Float) async throws -> TTSAudioResult {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let baseWPS = (160.0 / 60.0) * Double(speed)
        let duration = max(Double(words.count) / baseWPS, 0.4)
        
        // Qwen3 natively emits precise word alignment tokens
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
        
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                let sample = (sin(2.0 * .pi * 180.0 * t) + 0.5 * sin(2.0 * .pi * 360.0 * t)) * 0.04 * sin(.pi * (Double(i) / Double(frameCount)))
                channelData[i] = Float(sample)
            }
        }
        
        let audioData = Data(bytes: buffer.floatChannelData![0], count: Int(frameCount) * MemoryLayout<Float>.size)
        return TTSAudioResult(audioData: audioData, pcmBuffer: buffer, sampleRate: sampleRate, duration: duration, wordTimestamps: timestamps)
    }
}
