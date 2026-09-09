//
//  PlainTextParser.swift
//  Vachanam
//
//  Parses raw plain text and TXT files into structured ParsedDocument models.
//

import Foundation

public struct PlainTextParser: DocumentParser {
    public init() {}
    
    public func parse(from source: DocumentSource) async throws -> ParsedDocument {
        let text: String
        let defaultTitle: String
        
        switch source {
        case .fileURL(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw DocumentParserError.fileNotFound(url)
            }
            do {
                text = try String(contentsOf: url, encoding: .utf8)
                defaultTitle = url.deletingPathExtension().lastPathComponent
            } catch {
                throw DocumentParserError.parsingFailed("Could not read plain text file: \(error.localizedDescription)")
            }
        case .rawText(let rawText, let rawTitle):
            text = rawText
            defaultTitle = rawTitle
        case .webURL:
            throw DocumentParserError.invalidSource("PlainTextParser requires a fileURL or rawText")
        }
        
        let rawParagraphs = text.components(separatedBy: "\n\n")
            .map { $0.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !rawParagraphs.isEmpty else {
            throw DocumentParserError.parsingFailed("Document is empty")
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
