//
//  AudioEncoder.swift
//  Vachanam
//
//  Encodes TTS PCM buffers into compressed AAC .m4a files for audiobook distribution.
//

import Foundation
import AVFoundation

public class AudioEncoder {
    public static let shared = AudioEncoder()
    
    public init() {}
    
    /// Encodes a TTSAudioResult into an AAC .m4a file at the specified URL.
    public func encodeToM4A(result: TTSAudioResult, destinationURL: URL) throws {
        let sampleRate = result.sampleRate > 0 ? result.sampleRate : 24000.0
        
        // Remove destination if it already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Ensure parent directory exists
        let parentDir = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        // Prepare PCM buffer
        let pcmBuffer: AVAudioPCMBuffer
        if let existing = result.pcmBuffer {
            pcmBuffer = existing
        } else {
            pcmBuffer = try createPCMBuffer(from: result.audioData, sampleRate: sampleRate)
        }
        
        // AAC settings for audiobook compression
        let aacSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000 // 64kbps mono AAC is crystal clear for speech and very compact
        ]
        
        let audioFile = try AVAudioFile(
            forWriting: destinationURL,
            settings: aacSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        
        try audioFile.write(from: pcmBuffer)
    }
    
    /// Reconstructs an AVAudioPCMBuffer from raw 16-bit PCM data.
    private func createPCMBuffer(from data: Data, sampleRate: Double) throws -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioEncoder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate PCM buffer"])
        }
        
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        
        data.withUnsafeBytes { raw in
            let int16Ptr = raw.bindMemory(to: Int16.self)
            for i in 0..<Int(frameCount) {
                channel[i] = Float(int16Ptr[i]) / 32767.0
            }
        }
        
        return buffer
    }
}
