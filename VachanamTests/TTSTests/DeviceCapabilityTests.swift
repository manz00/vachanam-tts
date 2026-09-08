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
        let qwen3 = ModelRegistry.shared.model(withId: "qwen3-tts-0.6b-en")!
        
        XCTAssertTrue(lowRamCap.canRun(model: kokoro))
        XCTAssertFalse(lowRamCap.canRun(model: qwen3))
        XCTAssertNotNil(lowRamCap.compatibilityReason(for: qwen3))
    }
    
    func testStandardRAMDevice() {
        let standardCap = DeviceCapability(simulatedRAMGB: 8)
        let qwen3 = ModelRegistry.shared.model(withId: "qwen3-tts-0.6b-en")!
        let cosyVoice = ModelRegistry.shared.model(withId: "cosyvoice3-0.5b")!
        
        XCTAssertTrue(standardCap.canRun(model: qwen3))
        XCTAssertTrue(standardCap.canRun(model: cosyVoice))
    }
}
