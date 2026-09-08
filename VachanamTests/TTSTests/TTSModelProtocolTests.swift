//
//  TTSModelProtocolTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class TTSModelProtocolTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        setenv("MLX_METAL_GPU_ARCH", "appleg14g", 0)
    }
    
    func testKokoroSynthesis() async throws {
        let adapter = KokoroAdapter()
        let bundleURL = Bundle.main.url(forResource: "KokoroModels", withExtension: nil)
        let modelsDir = bundleURL ?? URL(fileURLWithPath: "/tmp")
        
        do {
            try await adapter.loadModel(weightsDirectory: modelsDir)
            XCTAssertTrue(adapter.isLoaded)
            
            let sampleText = "Accessibility empowers every reader with voice."
            let result = try await adapter.synthesize(text: sampleText, voice: "af_heart", speed: 1.0)
            
            XCTAssertGreaterThan(result.duration, 0.0)
            XCTAssertFalse(result.audioData.isEmpty)
            XCTAssertNotNil(result.pcmBuffer)
            XCTAssertEqual(result.sampleRate, 24000.0)
            XCTAssertFalse(result.wordTimestamps.isEmpty)
            
            // Test af_bella voice
            let resultBella = try await adapter.synthesize(text: "Hello from Bella.", voice: "af_bella", speed: 1.0)
            XCTAssertGreaterThan(resultBella.duration, 0.0)
            
            // Test bf_emma voice
            let resultEmma = try await adapter.synthesize(text: "Good day from Emma.", voice: "bf_emma", speed: 1.0)
            XCTAssertGreaterThan(resultEmma.duration, 0.0)
            
            // Test unbundled voice gracefully falls back without throwing unsupportedVoice
            let resultFallback = try await adapter.synthesize(text: "Fallback test.", voice: "unknown_voice_xyz", speed: 1.0)
            XCTAssertGreaterThan(resultFallback.duration, 0.0)
            
            adapter.unloadModel()
            XCTAssertFalse(adapter.isLoaded)
        } catch TTSError.weightsNotFound {
            // Handled when running in environments without bundled models
            XCTAssertFalse(adapter.isLoaded)
        }
    }
}
