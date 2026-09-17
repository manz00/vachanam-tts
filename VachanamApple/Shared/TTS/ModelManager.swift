//
//  ModelManager.swift
//  Vachanam
//
//  Model lifecycle manager: download, caching, disk storage, and active model switching.
//

import Foundation
import Combine

public class ModelManager: ObservableObject {
    public static let shared = ModelManager()
    
    @Published public var downloadStates: [String: ModelDownloadState] = [:]
    @Published public var loadedModelId: String? = nil
    @Published public var activeModelId: String = "kokoro-v1.0-en" {
        didSet {
            UserDefaults.standard.set(activeModelId, forKey: "activeTTSModelId")
        }
    }
    
    public let modelsDirectory: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.modelsDirectory = appSupport.appendingPathComponent("Vachanam/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        if let savedId = UserDefaults.standard.string(forKey: "activeTTSModelId") {
            self.activeModelId = savedId
        }
        
        refreshDownloadedStates()
    }
    
    public func modelDirectory(for modelId: String) -> URL {
        modelsDirectory.appendingPathComponent(modelId, isDirectory: true)
    }
    
    public func isModelDownloaded(_ modelId: String) -> Bool {
        if modelId == "apple-system-en" || modelId == "kokoro-v1.0-en" { return true }
        let dir = modelDirectory(for: modelId)
        return FileManager.default.fileExists(atPath: dir.path)
    }
    
    public func isModelLoaded(_ modelId: String) -> Bool {
        loadedModelId == modelId
    }
    
    public func refreshDownloadedStates() {
        for model in ModelRegistry.shared.availableModels {
            if isModelDownloaded(model.id) {
                downloadStates[model.id] = .downloaded
            } else {
                downloadStates[model.id] = .notDownloaded
            }
        }
    }
    
    public func downloadModel(_ model: TTSModelMetadata) {
        // Downloading is no longer needed since Kokoro is bundled.
        downloadStates[model.id] = .downloaded
    }
    
    @MainActor
    public func loadModel(withId id: String) async throws {
        guard isModelDownloaded(id) else {
            throw TTSError.weightsNotFound
        }
        if let metadata = ModelRegistry.shared.model(withId: id) {
            guard DeviceCapability.shared.canRun(model: metadata) else {
                let reason = DeviceCapability.shared.compatibilityReason(for: metadata) ?? "Requires more device RAM"
                throw TTSError.insufficientHardware(reason)
            }
        }
        if activeModelId != id {
            activeModelId = id
        }
        await TTSController.shared.loadActiveModel()
    }
    
    @MainActor
    public func unloadModel(withId id: String) {
        if activeModelId == id {
            TTSController.shared.unloadActiveModel()
        }
        if loadedModelId == id {
            loadedModelId = nil
        }
    }
    
    @MainActor
    public func deleteModel(_ modelId: String) {
        // Bundled models cannot be deleted.
    }
}
