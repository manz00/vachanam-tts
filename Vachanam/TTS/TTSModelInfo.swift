//
//  TTSModelInfo.swift
//  Vachanam
//
//  TTS model metadata, download state, format, and capabilities.
//

import Foundation

public enum TTSModelFormat: String, Codable {
    case coreML
    case mlx
}

public enum TTSModelTier: String, Codable {
    case lightweight
    case heavy
}

public enum TTSModelQuality: String, Codable {
    case standard
    case premium
}

public enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
    
    public var isDownloaded: Bool {
        if case .downloaded = self { return true }
        return false
    }
}

public struct TTSModelMetadata: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let sizeBytes: Int64
    public let ramRequired: Int64
    public let languages: [String]
    public let format: TTSModelFormat
    public let requiresG2P: Bool
    public let g2pEngine: String?
    public let quality: TTSModelQuality
    public let supportsVoiceCloning: Bool
    public let supportsEmotionControl: Bool
    public let supportsStreaming: Bool
    public let supportsWordTimestamps: Bool
    public let minDeviceRAM: Int
    public let tier: TTSModelTier
    public let voices: [String]
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    public var formattedRAM: String {
        ByteCountFormatter.string(fromByteCount: ramRequired, countStyle: .memory)
    }
}
