//
//  TTSAudioCache.swift
//  Vachanam
//
//  Two-tier content-hashed audio cache (fast in-memory LRU + persistent disk storage)
//  keyed by: documentID + model + voice + speed + text hash.
//

import Foundation
import CryptoKit
import AVFoundation

final class CachedAudioBox {
    let result: TTSAudioResult
    init(result: TTSAudioResult) {
        self.result = result
    }
}

public class TTSAudioCache: @unchecked Sendable {
    public static let shared = TTSAudioCache()
    
    private let memoryCache = NSCache<NSString, CachedAudioBox>()
    private let diskDirectory: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.vachanam.audiocache", attributes: .concurrent)
    
    public init() {
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskDirectory = cachesURL.appendingPathComponent("TTSAudioCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
        
        memoryCache.countLimit = 150 // Keep up to 150 audio chunks in RAM
    }
    
    /// Computes a stable content-hashed cache key.
    public func makeKey(
        documentID: UUID?,
        modelId: String,
        voice: String?,
        speed: Float,
        text: String,
        pronunciationRevision: String? = nil
    ) -> String {
        let docStr = documentID?.uuidString ?? "global"
        let voiceStr = voice ?? "default"
        let speedStr = String(format: "%.2f", speed)
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let revStr = pronunciationRevision ?? "default"
        
        let hashInput = "\(docStr)|\(modelId)|\(voiceStr)|\(speedStr)|\(normalizedText)|\(revStr)"
        let digest = SHA256.hash(data: Data(hashInput.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Invalidates a specific cached audio entry by key.
    public func invalidate(key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        let fileURL = diskDirectory.appendingPathComponent("\(key).wav")
        let metaURL = diskDirectory.appendingPathComponent("\(key).meta")
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: metaURL)
    }
    
    /// Retrieves cached audio result if available.
    public func retrieve(key: String) -> TTSAudioResult? {
        // 1. Check in-memory cache
        if let boxed = memoryCache.object(forKey: key as NSString) {
            return boxed.result
        }
        
        // 2. Check disk cache directly without cooperative thread blocking
        let fileURL = diskDirectory.appendingPathComponent("\(key).wav")
        let metaURL = diskDirectory.appendingPathComponent("\(key).meta")
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let audioData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        var duration: TimeInterval = 0.0
        var sampleRate: Double = 24000.0
        var timestamps: [WordTimestamp] = []
        
        if let metaData = try? Data(contentsOf: metaURL),
           let json = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any] {
            duration = json["duration"] as? Double ?? 0.0
            sampleRate = json["sampleRate"] as? Double ?? 24000.0
            if let rawStamps = json["timestamps"] as? [[String: Any]] {
                timestamps = rawStamps.compactMap { dict in
                    guard let w = dict["word"] as? String,
                          let s = dict["start"] as? Double,
                          let e = dict["end"] as? Double else { return nil }
                    return WordTimestamp(word: w, startTime: s, endTime: e)
                }
            }
        }
        
        let result = TTSAudioResult(
            audioData: audioData,
            pcmBuffer: nil,
            sampleRate: sampleRate,
            duration: duration,
            wordTimestamps: timestamps
        )
        
        // Store back to memory cache
        memoryCache.setObject(CachedAudioBox(result: result), forKey: key as NSString)
        return result
    }
    
    /// Stores an audio result in both in-memory and on-disk caches.
    public func store(key: String, result: TTSAudioResult) {
        // Store in memory
        memoryCache.setObject(CachedAudioBox(result: result), forKey: key as NSString)
        
        // Asynchronously persist to disk with atomic write
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.diskDirectory.appendingPathComponent("\(key).wav")
            let metaURL = self.diskDirectory.appendingPathComponent("\(key).meta")
            
            try? result.audioData.write(to: fileURL, options: .atomic)
            
            let meta: [String: Any] = [
                "duration": result.duration,
                "sampleRate": result.sampleRate,
                "timestamps": result.wordTimestamps.map { [
                    "word": $0.word,
                    "start": $0.startTime,
                    "end": $0.endTime
                ] }
            ]
            if let metaData = try? JSONSerialization.data(withJSONObject: meta) {
                try? metaData.write(to: metaURL, options: .atomic)
            }
        }
    }
    
    /// Clears both memory and disk caches.
    public func clearAll() {
        memoryCache.removeAllObjects()
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.diskDirectory)
            try? self.fileManager.createDirectory(at: self.diskDirectory, withIntermediateDirectories: true)
        }
    }
}
