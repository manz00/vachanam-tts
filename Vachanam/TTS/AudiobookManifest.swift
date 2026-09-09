//
//  AudiobookManifest.swift
//  Vachanam
//
//  Schema models for pre-generated audiobook bundles:
//  - manifest.json: metadata, chapters, and export chunks
//  - timings/*.json: high-resolution per-word timestamps
//  - document_index.json: per-word PDF geometry and structure indexing
//

import Foundation
import CoreGraphics

// MARK: - Manifest Models

public struct AudiobookManifest: Codable, Sendable, Identifiable {
    public var id: String { documentHash }
    public let version: Int
    public let documentHash: String
    public let title: String
    public let author: String?
    public let generatedAt: Date
    public let model: String
    public let voice: String?
    public let speed: Float
    public let sampleRate: Double
    public let totalDuration: TimeInterval
    public let totalChunks: Int
    public let chapters: [AudiobookChapterManifest]
    
    public init(
        version: Int = 1,
        documentHash: String,
        title: String,
        author: String? = nil,
        generatedAt: Date = Date(),
        model: String,
        voice: String? = nil,
        speed: Float = 1.0,
        sampleRate: Double = 24000.0,
        totalDuration: TimeInterval,
        totalChunks: Int,
        chapters: [AudiobookChapterManifest]
    ) {
        self.version = version
        self.documentHash = documentHash
        self.title = title
        self.author = author
        self.generatedAt = generatedAt
        self.model = model
        self.voice = voice
        self.speed = speed
        self.sampleRate = sampleRate
        self.totalDuration = totalDuration
        self.totalChunks = totalChunks
        self.chapters = chapters
    }
}

public struct AudiobookChapterManifest: Codable, Sendable, Identifiable {
    public var id: Int { index }
    public let index: Int
    public let title: String
    public let startPage: Int
    public let endPage: Int
    public let chunks: [AudiobookExportChunk]
    
    public init(
        index: Int,
        title: String,
        startPage: Int,
        endPage: Int,
        chunks: [AudiobookExportChunk]
    ) {
        self.index = index
        self.title = title
        self.startPage = startPage
        self.endPage = endPage
        self.chunks = chunks
    }
}

public struct AudiobookExportChunk: Codable, Sendable, Identifiable {
    public var id: Int { index }
    public let index: Int
    public let chapterIndex: Int
    public let audioM4A: String      // Relative path: e.g. "chapters/chapter-01/chunk-001.m4a"
    public let audioOpus: String?    // Optional opus path
    public let timingsPath: String   // Relative path: e.g. "timings/chapter-01/chunk-001.json"
    public let duration: TimeInterval
    public let startGlobalWordID: Int
    public let endGlobalWordID: Int
    public let sentenceIDs: [Int]
    
    public init(
        index: Int,
        chapterIndex: Int,
        audioM4A: String,
        audioOpus: String? = nil,
        timingsPath: String,
        duration: TimeInterval,
        startGlobalWordID: Int,
        endGlobalWordID: Int,
        sentenceIDs: [Int]
    ) {
        self.index = index
        self.chapterIndex = chapterIndex
        self.audioM4A = audioM4A
        self.audioOpus = audioOpus
        self.timingsPath = timingsPath
        self.duration = duration
        self.startGlobalWordID = startGlobalWordID
        self.endGlobalWordID = endGlobalWordID
        self.sentenceIDs = sentenceIDs
    }
}

// MARK: - Per-Chunk Timings

public struct AudiobookChunkTimings: Codable, Sendable {
    public let chunkIndex: Int
    public let chapterIndex: Int
    public let words: [AudiobookWordTimestamp]
    
    public init(chunkIndex: Int, chapterIndex: Int, words: [AudiobookWordTimestamp]) {
        self.chunkIndex = chunkIndex
        self.chapterIndex = chapterIndex
        self.words = words
    }
}

public struct AudiobookWordTimestamp: Codable, Sendable {
    public let globalWordID: Int
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    
    public init(globalWordID: Int, text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.globalWordID = globalWordID
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - Document Index

public struct AudiobookDocumentIndex: Codable, Sendable {
    public let words: [AudiobookIndexedWord]
    
    public init(words: [AudiobookIndexedWord]) {
        self.words = words
    }
}

public struct AudiobookIndexedWord: Codable, Sendable {
    public let globalWordID: Int
    public let page: Int
    public let paragraphIndex: Int
    public let sentenceIndex: Int
    public let chunkIndex: Int
    public let chapterIndex: Int
    public let pdfBoundingBox: PDFBoxGeometry?
    
    public init(
        globalWordID: Int,
        page: Int,
        paragraphIndex: Int,
        sentenceIndex: Int,
        chunkIndex: Int,
        chapterIndex: Int,
        pdfBoundingBox: PDFBoxGeometry? = nil
    ) {
        self.globalWordID = globalWordID
        self.page = page
        self.paragraphIndex = paragraphIndex
        self.sentenceIndex = sentenceIndex
        self.chunkIndex = chunkIndex
        self.chapterIndex = chapterIndex
        self.pdfBoundingBox = pdfBoundingBox
    }
}

public struct PDFBoxGeometry: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    public init(rect: CGRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.size.width)
        self.height = Double(rect.size.height)
    }
    
    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
