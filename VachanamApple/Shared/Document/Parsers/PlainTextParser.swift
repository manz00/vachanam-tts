//
//  PlainTextParser.swift
//  Vachanam
//
//  Parses raw plain text and TXT files into structured ParsedDocument models.
//

import Foundation

public struct PlainTextParser: DocumentParser {
    public init() {}
    
    public static func decodeString(from data: Data) -> String {
        if let str = String(data: data, encoding: .utf8) { return str }
        if let str = String(data: data, encoding: .isoLatin1) { return str }
        if let str = String(data: data, encoding: .windowsCP1252) { return str }
        if let str = String(data: data, encoding: .utf16) { return str }
        return String(data: data, encoding: .ascii) ?? ""
    }
    
    public func parse(from source: DocumentSource) async throws -> ParsedDocument {
        let text: String
        let defaultTitle: String
        
        switch source {
        case .fileURL(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw DocumentParserError.fileNotFound(url)
            }
            guard let data = try? Data(contentsOf: url) else {
                throw DocumentParserError.parsingFailed("Could not read plain text file: \(url.lastPathComponent)")
            }
            text = Self.decodeString(from: data)
            defaultTitle = url.deletingPathExtension().lastPathComponent
        case .rawText(let rawText, let rawTitle):
            text = rawText
            defaultTitle = rawTitle
        case .webURL:
            throw DocumentParserError.invalidSource("PlainTextParser requires a fileURL or rawText")
        }
        
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var rawParagraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Fallback for files with single-newline separation
        if rawParagraphs.count <= 1 && normalized.contains("\n") {
            let lines = normalized.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if lines.count > 1 {
                rawParagraphs = lines
            }
        }
        
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawParagraphs.isEmpty || !trimmed.isEmpty else {
            throw DocumentParserError.parsingFailed("Document is empty")
        }
        if rawParagraphs.isEmpty {
            rawParagraphs = [trimmed]
        }
        
        var title = defaultTitle
        var startIndex = 0
        
        // If the first paragraph is short, treat it as the document title
        if let first = rawParagraphs.first, first.count <= 80 && !first.hasSuffix(".") {
            title = first
            startIndex = 1
        }
        
        let contentParagraphs = startIndex < rawParagraphs.count ? Array(rawParagraphs[startIndex...]) : rawParagraphs
        let blocks = contentParagraphs.map { ParsedBlock(type: .paragraph, text: $0) }
        
        let chapter = ParsedChapter(title: title, blocks: blocks)
        return ParsedDocument(title: title, author: nil, format: .plainText, chapters: [chapter])
    }
}
