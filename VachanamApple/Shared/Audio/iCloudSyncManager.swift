//
//  iCloudSyncManager.swift
//  Vachanam
//
//  Manages iCloud Drive and local shared directory storage for pre-generated audiobook bundles.
//

import Foundation
import CryptoKit

public class iCloudSyncManager: ObservableObject {
    public static let shared = iCloudSyncManager()
    
    @Published public var availableManifests: [AudiobookManifest] = []
    
    public init() {
        refreshAvailableBundles()
    }
    
    /// Root directory for pre-generated audiobook bundles (iCloud Drive if available, otherwise local Documents).
    public func audiobooksDirectory() -> URL {
        let fileManager = FileManager.default
        
        // 1. Try iCloud Drive ubiquity container
        if let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let cloudURL = containerURL.appendingPathComponent("Documents/Audiobooks", isDirectory: true)
            try? fileManager.createDirectory(at: cloudURL, withIntermediateDirectories: true)
            return cloudURL
        }
        
        // 2. Fallback to app Documents directory
        let localDocs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audiobooksDir = localDocs.appendingPathComponent("Audiobooks", isDirectory: true)
        try? fileManager.createDirectory(at: audiobooksDir, withIntermediateDirectories: true)
        return audiobooksDir
    }
    
    /// Specific bundle directory for a given document hash.
    public func bundleDirectory(for documentHash: String) -> URL {
        audiobooksDirectory().appendingPathComponent(documentHash, isDirectory: true)
    }
    
    /// Checks if a complete pre-generated bundle exists for a document hash.
    public func hasBundle(for documentHash: String) -> Bool {
        let manifestURL = bundleDirectory(for: documentHash).appendingPathComponent("manifest.json")
        return FileManager.default.fileExists(atPath: manifestURL.path)
    }
    
    /// Loads and parses the manifest for a given document hash.
    public func loadManifest(for documentHash: String) -> AudiobookManifest? {
        let manifestURL = bundleDirectory(for: documentHash).appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AudiobookManifest.self, from: data)
    }
    
    /// Scans the audiobooks directory and updates the list of available bundles.
    public func refreshAvailableBundles() {
        let baseDir = audiobooksDirectory()
        guard let subdirs = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        var manifests: [AudiobookManifest] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        for dir in subdirs {
            let manifestFile = dir.appendingPathComponent("manifest.json")
            if let data = try? Data(contentsOf: manifestFile),
               let manifest = try? decoder.decode(AudiobookManifest.self, from: data) {
                manifests.append(manifest)
            }
        }
        
        manifests.sort { $0.generatedAt > $1.generatedAt }
        DispatchQueue.main.async {
            self.availableManifests = manifests
        }
    }
    
    // MARK: - Content Hash Utilities
    
    /// Computes a stable SHA-256 content hash for raw data.
    public func computeHash(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Computes a stable SHA-256 hash for a local document file.
    public func computeHash(fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return computeHash(data: data)
    }
    
    /// Computes a deterministic SHA-256 hash from a SemanticDocument's content.
    public func computeHash(for document: SemanticDocument) -> String {
        let header = "\(document.title)_\(document.pageCount)_"
        let firstSample = document.words.prefix(150).map { $0.text }.joined(separator: " ")
        let lastSample = document.words.suffix(150).map { $0.text }.joined(separator: " ")
        let signature = header + firstSample + "_" + lastSample
        let data = Data(signature.utf8)
        return computeHash(data: data)
    }
}
