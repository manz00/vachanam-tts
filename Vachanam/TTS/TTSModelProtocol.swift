//
//  TTSModelProtocol.swift
//  Vachanam
//
//  Abstraction protocol for pluggable on-device TTS model adapters.
//

import Foundation
import AVFoundation

public struct WordTimestamp: Identifiable, Equatable, Codable {
    public var id: String { "\(word)_\(startTime)" }
    public let word: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    
    public init(word: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.word = word
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct TTSAudioResult {
    public let audioData: Data
    public let pcmBuffer: AVAudioPCMBuffer?
    public let sampleRate: Double
    public let duration: TimeInterval
    public let wordTimestamps: [WordTimestamp]
    
    public init(audioData: Data, pcmBuffer: AVAudioPCMBuffer? = nil, sampleRate: Double = 24000.0, duration: TimeInterval, wordTimestamps: [WordTimestamp] = []) {
        self.audioData = audioData
        self.pcmBuffer = pcmBuffer
        self.sampleRate = sampleRate
        self.duration = duration
        self.wordTimestamps = wordTimestamps
    }
}

public extension TTSAudioResult {
    /// Returns a new audio result with the specified seconds of silent audio appended.
    func withAppendedSilence(duration: TimeInterval) -> TTSAudioResult {
        guard duration > 0 else { return self }
        
        let silentSampleCount = Int(sampleRate * duration)
        guard silentSampleCount > 0 else { return self }
        
        var newAudioData = self.audioData
        let zeroBytes = [UInt8](repeating: 0, count: silentSampleCount * MemoryLayout<Float>.size)
        newAudioData.append(contentsOf: zeroBytes)
        
        var newPCMBuffer: AVAudioPCMBuffer? = nil
        if let oldBuf = self.pcmBuffer,
           let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: oldBuf.format.channelCount, interleaved: false),
           let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: oldBuf.frameLength + AVAudioFrameCount(silentSampleCount)) {
            
            buf.frameLength = oldBuf.frameLength + AVAudioFrameCount(silentSampleCount)
            for ch in 0..<Int(format.channelCount) {
                if let src = oldBuf.floatChannelData?[ch], let dst = buf.floatChannelData?[ch] {
                    memcpy(dst, src, Int(oldBuf.frameLength) * MemoryLayout<Float>.size)
                    memset(dst + Int(oldBuf.frameLength), 0, silentSampleCount * MemoryLayout<Float>.size)
                }
            }
            newPCMBuffer = buf
        }
        
        return TTSAudioResult(
            audioData: newAudioData,
            pcmBuffer: newPCMBuffer,
            sampleRate: self.sampleRate,
            duration: self.duration + duration,
            wordTimestamps: self.wordTimestamps
        )
    }
}

public enum TTSError: LocalizedError {
    case modelNotLoaded
    case weightsNotFound
    case synthesisFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "TTS model is not loaded"
        case .weightsNotFound:
            return "Neural weights package (.mlmodelc) not found on device"
        case .synthesisFailed(let msg):
            return "Synthesis failed: \(msg)"
        }
    }
}

public protocol TTSModelProtocol: AnyObject {
    var metadata: TTSModelMetadata { get }
    var isLoaded: Bool { get }
    var hasNeuralWeights: Bool { get }
    
    func loadModel(weightsDirectory: URL) async throws
    func unloadModel()
    func synthesize(text: String, voice: String?, speed: Float) async throws -> TTSAudioResult
    func synthesize(text: String, voice: String?, speed: Float, pauseDuration: TimeInterval) async throws -> TTSAudioResult
    func streamSynthesize(text: String, voice: String?, speed: Float) -> AsyncThrowingStream<TTSAudioResult, Error>
}

public extension TTSModelProtocol {
    var hasNeuralWeights: Bool { false }
    
    func synthesize(text: String, voice: String?, speed: Float, pauseDuration: TimeInterval) async throws -> TTSAudioResult {
        let base = try await synthesize(text: text, voice: voice, speed: speed)
        guard pauseDuration > 0 else { return base }
        return base.withAppendedSilence(duration: pauseDuration)
    }
    
    func streamSynthesize(text: String, voice: String?, speed: Float) -> AsyncThrowingStream<TTSAudioResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await self.synthesize(text: text, voice: voice, speed: speed)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
