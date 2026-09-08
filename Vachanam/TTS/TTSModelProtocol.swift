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

public protocol TTSModelProtocol: AnyObject {
    var metadata: TTSModelMetadata { get }
    var isLoaded: Bool { get }
    
    func loadModel(weightsDirectory: URL) async throws
    func unloadModel()
    func synthesize(text: String, voice: String?, speed: Float) async throws -> TTSAudioResult
    func streamSynthesize(text: String, voice: String?, speed: Float) -> AsyncThrowingStream<TTSAudioResult, Error>
}

public extension TTSModelProtocol {
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
