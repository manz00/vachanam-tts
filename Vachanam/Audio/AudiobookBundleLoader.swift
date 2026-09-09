//
//  AudiobookBundleLoader.swift
//  Vachanam
//
//  Loads and navigates pre-generated audiobook bundles for zero-latency playback.
//

import Foundation

public class AudiobookBundleLoader: ObservableObject {
    public static let shared = AudiobookBundleLoader()
    
    @Published public var activeManifest: AudiobookManifest?
    @Published public var hasBundleForCurrentDocument: Bool = false
    
    private var timingsCache: [String: AudiobookChunkTimings] = [:]
    
    public init() {}
    
    /// Checks if a bundle is available for the given document.
    public func hasBundle(for document: SemanticDocument) -> Bool {
        let hash = iCloudSyncManager.shared.computeHash(for: document)
        return iCloudSyncManager.shared.hasBundle(for: hash)
    }
    
    /// Loads the bundle manifest for the given document.
    public func loadBundle(for document: SemanticDocument) -> AudiobookManifest? {
        let hash = iCloudSyncManager.shared.computeHash(for: document)
        guard let manifest = iCloudSyncManager.shared.loadManifest(for: hash) else {
            DispatchQueue.main.async {
                self.activeManifest = nil
                self.hasBundleForCurrentDocument = false
            }
            return nil
        }
        
        DispatchQueue.main.async {
            self.activeManifest = manifest
            self.hasBundleForCurrentDocument = true
        }
        return manifest
    }
    
    /// Resolves the absolute on-disk audio URL for an export chunk.
    public func audioURL(for chunk: AudiobookExportChunk, in manifest: AudiobookManifest) -> URL {
        let bundleDir = iCloudSyncManager.shared.bundleDirectory(for: manifest.documentHash)
        return bundleDir.appendingPathComponent(chunk.audioM4A)
    }
    
    /// Loads timing information for an export chunk from disk, with in-memory caching.
    public func loadTimings(for chunk: AudiobookExportChunk, in manifest: AudiobookManifest) -> AudiobookChunkTimings? {
        let cacheKey = "\(manifest.documentHash)_\(chunk.timingsPath)"
        if let cached = timingsCache[cacheKey] {
            return cached
        }
        
        let bundleDir = iCloudSyncManager.shared.bundleDirectory(for: manifest.documentHash)
        let timingURL = bundleDir.appendingPathComponent(chunk.timingsPath)
        
        guard let data = try? Data(contentsOf: timingURL) else { return nil }
        let decoder = JSONDecoder()
        guard let timings = try? decoder.decode(AudiobookChunkTimings.self, from: data) else { return nil }
        
        timingsCache[cacheKey] = timings
        return timings
    }
    
    /// Finds the export chunk covering a given global word ID.
    public func findExportChunk(forGlobalWordID wordID: Int, in manifest: AudiobookManifest) -> (chapter: AudiobookChapterManifest, chunk: AudiobookExportChunk)? {
        for chapter in manifest.chapters {
            for chunk in chapter.chunks {
                if wordID >= chunk.startGlobalWordID && wordID <= chunk.endGlobalWordID {
                    return (chapter, chunk)
                }
            }
        }
        return nil
    }
}
