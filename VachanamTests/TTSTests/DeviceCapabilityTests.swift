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
}
