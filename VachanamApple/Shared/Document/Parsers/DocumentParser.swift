//
//  DocumentParser.swift
//  Vachanam
//
//  Universal document parser contract and data structures for EPUB, Markdown, TXT, and Web.
//

import Foundation

public enum DocumentSource: Sendable {
    case fileURL(URL)
    case webURL(URL)
    case rawText(String, title: String)
}

public struct ParsedBlock: Sendable, Identifiable {
    public let id = UUID()
    public let type: BlockType
    public let text: String
    public let level: Int
    public let marker: String?
    
    public init(type: BlockType, text: String, level: Int = 1, marker: String? = nil) {
        self.type = type
        self.text = text
        self.level = level
        self.marker = marker
    }
}

public struct ParsedChapter: Sendable, Identifiable {
    public let id = UUID()
    public let title: String?
    public let blocks: [ParsedBlock]
    
    public init(title: String? = nil, blocks: [ParsedBlock]) {
        self.title = title
        self.blocks = blocks
    }
}

public struct ParsedDocument: Sendable {
    public let title: String
    public let author: String?
    public let format: DocumentFormat
    public let chapters: [ParsedChapter]
    
    public init(title: String, author: String? = nil, format: DocumentFormat, chapters: [ParsedChapter]) {
        self.title = title
        self.author = author
        self.format = format
        self.chapters = chapters
    }
    
    /// Flat list of all blocks across all chapters
    public var allBlocks: [ParsedBlock] {
        chapters.flatMap { $0.blocks }
    }
}

public enum DocumentParserError: LocalizedError, Sendable {
    case invalidSource(String)
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case networkError(String)
    case parsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidSource(let msg): return "Invalid document source: \(msg)"
        case .fileNotFound(let url): return "File not found at: \(url.path)"
        case .unsupportedFormat(let fmt): return "Unsupported document format: \(fmt)"
        case .networkError(let msg): return "Network request failed: \(msg)"
        case .parsingFailed(let msg): return "Document parsing failed: \(msg)"
        }
    }
}

public protocol DocumentParser: Sendable {
    func parse(from source: DocumentSource) async throws -> ParsedDocument
}
