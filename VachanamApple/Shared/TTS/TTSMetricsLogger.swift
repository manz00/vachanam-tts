//
//  TTSMetricsLogger.swift
//  Vachanam
//
//  Stage-by-stage latency and execution profiling for Core ML & neural TTS stages:
//  Misaki phonemization, Duration CoreML, Acoustic/Decoder, and Audio dispatch.
//

import Foundation
import Combine

public struct SynthesisTimingMetrics: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let modelId: String
    public let textSnippet: String
    public let characterCount: Int
    public let wordCount: Int
    public let audioDuration: TimeInterval
    
    // Stage latencies in milliseconds
    public let textProcessingMs: Double
    public let phonemizationMs: Double
    public let modelInferenceMs: Double
    public let audioPostProcessingMs: Double
    public let totalLatencyMs: Double
    
    public var realTimeFactor: Double {
        guard audioDuration > 0 else { return 0.0 }
        return (totalLatencyMs / 1000.0) / audioDuration
    }
    
    public init(
        modelId: String,
        textSnippet: String,
        characterCount: Int,
        wordCount: Int,
        audioDuration: TimeInterval,
        textProcessingMs: Double,
        phonemizationMs: Double,
        modelInferenceMs: Double,
        audioPostProcessingMs: Double,
        totalLatencyMs: Double
    ) {
        self.timestamp = Date()
        self.modelId = modelId
        self.textSnippet = textSnippet
        self.characterCount = characterCount
        self.wordCount = wordCount
        self.audioDuration = audioDuration
        self.textProcessingMs = textProcessingMs
        self.phonemizationMs = phonemizationMs
        self.modelInferenceMs = modelInferenceMs
        self.audioPostProcessingMs = audioPostProcessingMs
        self.totalLatencyMs = totalLatencyMs
    }
}

public class TTSMetricsLogger: ObservableObject, @unchecked Sendable {
    public static let shared = TTSMetricsLogger()
    
    @Published public var lastMetrics: SynthesisTimingMetrics?
    @Published public var history: [SynthesisTimingMetrics] = []
    
    private let maxHistoryCount = 50
    private let lock = NSLock()
    
    public init() {}
    
    public func record(metrics: SynthesisTimingMetrics) {
        lock.lock()
        defer { lock.unlock() }
        
        DispatchQueue.main.async {
            self.lastMetrics = metrics
            self.history.append(metrics)
            if self.history.count > self.maxHistoryCount {
                self.history.removeFirst()
            }
        }
        
        #if DEBUG
        print("⏱ [TTS Profiler] '\(metrics.textSnippet.prefix(25))...' | Total: \(String(format: "%.1f", metrics.totalLatencyMs))ms (Text: \(String(format: "%.1f", metrics.textProcessingMs))ms, Phone: \(String(format: "%.1f", metrics.phonemizationMs))ms, Model: \(String(format: "%.1f", metrics.modelInferenceMs))ms, Audio: \(String(format: "%.1f", metrics.audioPostProcessingMs))ms) | RTF: \(String(format: "%.2fx", metrics.realTimeFactor))")
        #endif
    }
}
