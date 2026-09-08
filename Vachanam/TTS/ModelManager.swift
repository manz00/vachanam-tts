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
        downloadStates[model.id] = .downloading(progress: 0.1)
        
        // Simulates managed background chunk download and creates model manifest folder
        Task { @MainActor in
            for step in 1...10 {
                try? await Task.sleep(nanoseconds: 80_000_000)
                let progress = Double(step) / 10.0
                self.downloadStates[model.id] = .downloading(progress: progress)
            }
            
            let dir = self.modelDirectory(for: model.id)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            // Generate full model package structure
            let manifestPath = dir.appendingPathComponent("manifest.json")
            let manifestJson = """
            {
              "id": "\(model.id)",
              "name": "\(model.name)",
              "version": "\(model.version)",
              "format": "\(model.format.rawValue)",
              "sizeBytes": \(model.sizeBytes),
              "ramRequired": \(model.ramRequired),
              "dateDownloaded": "\(ISO8601DateFormatter().string(from: Date()))"
            }
            """
            try? manifestJson.data(using: .utf8)?.write(to: manifestPath)
            
            let configPath = dir.appendingPathComponent("config.json")
            let configJson = """
            {
              "sampleRate": 24000,
              "channels": 1,
              "language": "en-US",
              "tier": "\(model.tier.rawValue)"
            }
            """
            try? configJson.data(using: .utf8)?.write(to: configPath)
            
            let weightsPlaceholder = dir.appendingPathComponent("weights.bin")
            try? "Weights for \(model.name) \(model.version)".data(using: .utf8)?.write(to: weightsPlaceholder)
            
            // Create neural compiled package directory (.mlmodelc)
            let mlmodelcName = model.id.contains("kokoro") ? "Kokoro.mlmodelc" : "model.mlmodelc"
            let compiledDir = dir.appendingPathComponent(mlmodelcName, isDirectory: true)
            try? FileManager.default.createDirectory(at: compiledDir, withIntermediateDirectories: true)
            let cmodelMeta = compiledDir.appendingPathComponent("cmodel.plist")
            try? "Kokoro CoreML Compiled Graph".data(using: .utf8)?.write(to: cmodelMeta)
            
            self.downloadStates[model.id] = .downloaded
            
            // If this is the active model, automatically trigger loading into memory
            if self.activeModelId == model.id {
                await TTSController.shared.loadActiveModel()
            }
        }
    }
    
    @MainActor
    public func loadModel(withId id: String) async throws {
        guard isModelDownloaded(id) else {
            throw TTSError.weightsNotFound
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
        unloadModel(withId: modelId)
        let dir = modelDirectory(for: modelId)
        try? FileManager.default.removeItem(at: dir)
        downloadStates[modelId] = .notDownloaded
    }
}
