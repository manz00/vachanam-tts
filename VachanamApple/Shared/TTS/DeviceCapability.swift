//
//  DeviceCapability.swift
//  Vachanam
//
//  Hardware capability inspection: physical RAM checks and model compatibility.
//

import Foundation

public class DeviceCapability {
    public static let shared = DeviceCapability()
    
    public let physicalRAMGigabytes: Int
    public let physicalRAMBytes: UInt64
    
    public init(simulatedRAMGB: Int? = nil) {
        if let sim = simulatedRAMGB {
            self.physicalRAMGigabytes = sim
            self.physicalRAMBytes = UInt64(sim) * 1024 * 1024 * 1024
            return
        }
        
        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let result = sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
        
        if result == 0 && memSize > 0 {
            self.physicalRAMBytes = memSize
            self.physicalRAMGigabytes = Int(memSize / (1024 * 1024 * 1024))
        } else {
            // Default safe fallback for modern Apple Silicon iPad / Mac
            self.physicalRAMGigabytes = 8
            self.physicalRAMBytes = 8 * 1024 * 1024 * 1024
        }
    }
    
    public func canRun(model: TTSModelMetadata) -> Bool {
        return physicalRAMGigabytes >= model.minDeviceRAM
    }
    
    public func compatibilityReason(for model: TTSModelMetadata) -> String? {
        if canRun(model: model) { return nil }
        return "Requires at least \(model.minDeviceRAM) GB RAM (Current device has ~\(physicalRAMGigabytes) GB)"
    }
}
