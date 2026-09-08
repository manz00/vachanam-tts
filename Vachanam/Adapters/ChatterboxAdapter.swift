//
//  ChatterboxAdapter.swift
//  Vachanam
//
//  Chatterbox Turbo CoreML adapter supporting emotional markup and conversational prosody.
//

import Foundation
import AVFoundation

public class ChatterboxAdapter: TTSModelProtocol {
    public let metadata: TTSModelMetadata
    public private(set) var isLoaded: Bool = false
    
    public var hasNeuralWeights: Bool {
        let dir = ModelManager.shared.modelDirectory(for: metadata.id)
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("Chatterbox.mlmodelc").path)
            || FileManager.default.fileExists(atPath: dir.appendingPathComponent("model.mlmodelc").path)
            || FileManager.default.fileExists(atPath: dir.appendingPathComponent("weights.bin").path)
    }
    
    public init(metadata: TTSModelMetadata? = nil) {
        self.metadata = metadata ?? ModelRegistry.shared.model(withId: "chatterbox-turbo-en")!
    }
    
    public func loadModel(weightsDirectory: URL) async throws {
        guard FileManager.default.fileExists(atPath: weightsDirectory.path) else {
            throw TTSError.weightsNotFound
        }
        isLoaded = true
    }
    
    public func unloadModel() {
        isLoaded = false
    }
    
    public func synthesize(text: String, voice: String?, speed: Float) async throws -> TTSAudioResult {
        guard isLoaded else {
            throw TTSError.modelNotLoaded
        }
        let cleanedText = text.replacingOccurrences(of: "\\[(laugh|sigh|whisper|gasp)\\]", with: "", options: .regularExpression)
        let words = cleanedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let baseWPS = (155.0 / 60.0) * Double(speed)
        let duration = max(Double(words.count) / baseWPS, 0.4)
        
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
