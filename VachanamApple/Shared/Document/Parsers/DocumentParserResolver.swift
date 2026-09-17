//
//  DocumentParserResolver.swift
//  Vachanam
//
//  Dispatches documents to the appropriate format parser based on file extension or source type.
//

import Foundation

public class DocumentParserResolver {
    public static let shared = DocumentParserResolver()
    
    public init() {}
    
    public func parse(source: DocumentSource, format: DocumentFormat? = nil) async throws -> ParsedDocument {
        let targetFormat: DocumentFormat
        if let fmt = format {
            targetFormat = fmt
        } else {
            switch source {
            case .fileURL(let url):
                targetFormat = DocumentFormat.detect(from: url)
            case .webURL:
                targetFormat = .webArticle
            case .rawText:
                targetFormat = .plainText
            }
        }
        
        switch targetFormat {
        case .pdf:
            throw DocumentParserError.invalidSource("PDF documents are handled by PDFKit / SentenceSegmenter")
        case .epub:
            return try await EPUBParser().parse(from: source)
        case .markdown:
            return try await MarkdownParser().parse(from: source)
        case .plainText:
            return try await PlainTextParser().parse(from: source)
        case .webArticle:
            return try await WebArticleParser().parse(from: source)
        }
    }
}
