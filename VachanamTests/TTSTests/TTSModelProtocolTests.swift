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
            
            adapter.unloadModel()
            XCTAssertFalse(adapter.isLoaded)
        } catch TTSError.weightsNotFound {
            // Handled when running in environments without bundled models
            XCTAssertFalse(adapter.isLoaded)
        }
    }
}
