//
//  TTSModelProtocolTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class TTSModelProtocolTests: XCTestCase {
    
    func testKokoroSynthesis() async throws {
        let adapter = KokoroAdapter()
        try await adapter.loadModel(weightsDirectory: URL(fileURLWithPath: "/tmp"))
        XCTAssertTrue(adapter.isLoaded)
        
        let sampleText = "Accessibility empowers every reader with voice."
        let result = try await adapter.synthesize(text: sampleText, voice: "af_heart", speed: 1.0)
        
        XCTAssertGreaterThan(result.duration, 0.0)
        XCTAssertFalse(result.audioData.isEmpty)
        XCTAssertEqual(result.wordTimestamps.count, 6)
        XCTAssertEqual(result.wordTimestamps.first?.word, "Accessibility")
        
        adapter.unloadModel()
        XCTAssertFalse(adapter.isLoaded)
    }
    
    func testQwen3Timestamps() async throws {
        let adapter = Qwen3TTSAdapter()
        try await adapter.loadModel(weightsDirectory: URL(fileURLWithPath: "/tmp"))
        XCTAssertTrue(adapter.isLoaded)
        
        let sampleText = "Reading aloud enhances comprehension."
        let result = try await adapter.synthesize(text: sampleText, voice: nil, speed: 1.0)
        
        XCTAssertGreaterThan(result.duration, 0.0)
        XCTAssertEqual(result.wordTimestamps.count, 4)
        XCTAssertEqual(result.wordTimestamps.last?.word, "comprehension.")
        
        adapter.unloadModel()
        XCTAssertFalse(adapter.isLoaded)
    }
    
    func testChatterboxEmotionTags() async throws {
        let adapter = ChatterboxAdapter()
        try await adapter.loadModel(weightsDirectory: URL(fileURLWithPath: "/tmp"))
        XCTAssertTrue(adapter.isLoaded)
        
        let sampleText = "This is exciting [laugh] and wonderful!"
        let result = try await adapter.synthesize(text: sampleText, voice: nil, speed: 1.0)
        
        XCTAssertGreaterThan(result.duration, 0.0)
        XCTAssertFalse(result.wordTimestamps.contains(where: { $0.word.contains("[laugh]") }))
        
        adapter.unloadModel()
        XCTAssertFalse(adapter.isLoaded)
    }
    
    func testCosyVoice3Synthesis() async throws {
        let adapter = CosyVoice3Adapter()
        try await adapter.loadModel(weightsDirectory: URL(fileURLWithPath: "/tmp"))
        XCTAssertTrue(adapter.isLoaded)
        
        let sampleText = "Fast high quality neural speech."
        let result = try await adapter.synthesize(text: sampleText, voice: nil, speed: 1.25)
        
        XCTAssertGreaterThan(result.duration, 0.0)
        XCTAssertEqual(result.wordTimestamps.count, 5)
        
        adapter.unloadModel()
        XCTAssertFalse(adapter.isLoaded)
    }
}
