//
//  DeviceCapabilityTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class DeviceCapabilityTests: XCTestCase {
    
    func testLowRAMDeviceFiltering() {
        let lowRamCap = DeviceCapability(simulatedRAMGB: 4)
        XCTAssertEqual(lowRamCap.physicalRAMGigabytes, 4)
        
        let kokoro = ModelRegistry.shared.model(withId: "kokoro-v1.0-en")!
        
        XCTAssertTrue(lowRamCap.canRun(model: kokoro))
    }
    
    func testStandardRAMDevice() {
        let standardCap = DeviceCapability(simulatedRAMGB: 8)
        let kokoro = ModelRegistry.shared.model(withId: "kokoro-v1.0-en")!
        
        XCTAssertTrue(standardCap.canRun(model: kokoro))
    }
    
    func testHighRAMRequirementModel() {
        let lowRamCap = DeviceCapability(simulatedRAMGB: 4)
        let heavyModel = TTSModelMetadata(
            id: "heavy-tts-v1",
            name: "Heavy TTS",
            version: "v1.0",
            description: "Heavy model requiring 8GB RAM",
            sizeBytes: 4 * 1024 * 1024 * 1024,
            ramRequired: 8 * 1024 * 1024 * 1024,
            languages: ["en-US"],
            format: .coreML,
            requiresG2P: false,
            g2pEngine: nil,
            quality: .premium,
            supportsVoiceCloning: false,
            supportsEmotionControl: false,
            supportsStreaming: true,
            supportsWordTimestamps: true,
            minDeviceRAM: 8,
            tier: .heavy,
            voices: ["heavy"]
        )
        
        XCTAssertFalse(lowRamCap.canRun(model: heavyModel))
        XCTAssertNotNil(lowRamCap.compatibilityReason(for: heavyModel))
        XCTAssertTrue(lowRamCap.compatibilityReason(for: heavyModel)!.contains("Requires at least 8 GB RAM"))
    }
}
