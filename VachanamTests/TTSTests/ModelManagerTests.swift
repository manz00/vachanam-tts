//
//  ModelManagerTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class ModelManagerTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        setenv("MLX_METAL_GPU_ARCH", "appleg14g", 0)
    }
    
    func testModelRegistryLoading() {
        let registry = ModelRegistry.shared
        XCTAssertEqual(registry.availableModels.count, 1)
        
        let kokoro = registry.model(withId: "kokoro-v1.0-en")
        XCTAssertNotNil(kokoro)
        XCTAssertEqual(kokoro?.name, "Kokoro")
        XCTAssertEqual(kokoro?.tier, .lightweight)
    }
    
    func testActiveModelSwitching() {
        let manager = ModelManager.shared
        manager.activeModelId = "kokoro-v1.0-en"
        XCTAssertEqual(manager.activeModelId, "kokoro-v1.0-en")
    }
    
    func testModelDirectoryPaths() {
        let manager = ModelManager.shared
        let dir = manager.modelDirectory(for: "kokoro-v1.0-en")
        XCTAssertTrue(dir.path.contains("kokoro-v1.0-en"))
    }
    
    @MainActor
    func testModelLoadAndUnloadLifecycle() async throws {
        let manager = ModelManager.shared
        let kokoroDir = manager.modelDirectory(for: "kokoro-v1.0-en")
        try? FileManager.default.createDirectory(at: kokoroDir, withIntermediateDirectories: true)
        
        try await manager.loadModel(withId: "kokoro-v1.0-en")
        XCTAssertTrue(manager.isModelLoaded("kokoro-v1.0-en"))
        XCTAssertEqual(manager.loadedModelId, "kokoro-v1.0-en")
        
        manager.unloadModel(withId: "kokoro-v1.0-en")
        XCTAssertFalse(manager.isModelLoaded("kokoro-v1.0-en"))
        XCTAssertNil(manager.loadedModelId)
    }
}
