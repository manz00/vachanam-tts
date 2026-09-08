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
                try? await Task.sleep(nanoseconds: 100_000_000)
                let progress = Double(step) / 10.0
                self.downloadStates[model.id] = .downloading(progress: progress)
            }
            
            let dir = self.modelDirectory(for: model.id)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let weightsPlaceholder = dir.appendingPathComponent("weights.bin")
            try? "Weights for \(model.name) \(model.version)".data(using: .utf8)?.write(to: weightsPlaceholder)
            
            self.downloadStates[model.id] = .downloaded
        }
    }
    
    public func deleteModel(_ modelId: String) {
        let dir = modelDirectory(for: modelId)
        try? FileManager.default.removeItem(at: dir)
        downloadStates[modelId] = .notDownloaded
    }
}
