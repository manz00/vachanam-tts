//
//  PreGeneratedPlaybackAdapter.swift
//  Vachanam
//
//  Loads pre-generated audio chunks and word timestamps from disk/iCloud for instant zero-latency playback.
//

import Foundation
import AVFoundation

public class PreGeneratedPlaybackAdapter: ObservableObject {
    public static let shared = PreGeneratedPlaybackAdapter()
    
    public init() {}
    
    /// Loads the audio result and word timestamps for an export chunk.
    public func loadAudioResult(
        for chunk: AudiobookExportChunk,
        in manifest: AudiobookManifest
    ) -> TTSAudioResult? {
        let audioURL = AudiobookBundleLoader.shared.audioURL(for: chunk, in: manifest)
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return nil }
        
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return nil
            }
            try audioFile.read(into: pcmBuffer)
            
            // Load word timestamps
            let timings = AudiobookBundleLoader.shared.loadTimings(for: chunk, in: manifest)
            let wordTimestamps: [WordTimestamp] = timings?.words.map {
                WordTimestamp(word: $0.text, startTime: $0.startTime, endTime: $0.endTime)
            } ?? []
            
            let duration = Double(frameCount) / format.sampleRate
            
            // Raw PCM 16-bit data
            var pcm16Data = Data()
            if let channelData = pcmBuffer.floatChannelData?[0] {
                var samples = [Int16](repeating: 0, count: Int(frameCount))
                for i in 0..<Int(frameCount) {
                    let s = max(-1.0, min(1.0, channelData[i]))
                    samples[i] = Int16(s * 32767.0)
                }
                samples.withUnsafeBytes { pcm16Data.append(contentsOf: $0) }
            }
            
            return TTSAudioResult(
                audioData: pcm16Data,
                pcmBuffer: pcmBuffer,
                sampleRate: format.sampleRate,
                duration: duration,
                wordTimestamps: wordTimestamps
            )
        } catch {
            print("PreGeneratedPlaybackAdapter failed to read \(audioURL.path): \(error.localizedDescription)")
            return nil
        }
    }
}
