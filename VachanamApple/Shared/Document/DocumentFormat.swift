//
//  DocumentFormat.swift
//  Vachanam
//
//  Supported document formats for Vachanam multi-format ingestion.
//

import Foundation
import UniformTypeIdentifiers

public enum DocumentFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case pdf
    case epub
    case markdown
    case plainText
    case webArticle
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .pdf: return "PDF Document"
        case .epub: return "EPUB Book"
        case .markdown: return "Markdown Note"
        case .plainText: return "Plain Text"
        case .webArticle: return "Web Article"
        }
    }
    
    public var badgeText: String {
        switch self {
        case .pdf: return "PDF"
        case .epub: return "EPUB"
        case .markdown: return "MD"
        case .plainText: return "TXT"
        case .webArticle: return "WEB"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .pdf: return "doc.text.fill"
        case .epub: return "books.vertical.fill"
        case .markdown: return "text.badge.checkmark"
        case .plainText: return "doc.plaintext.fill"
        case .webArticle: return "globe"
        }
    }
    
    public static func detect(from url: URL) -> DocumentFormat {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return .pdf
        case "epub":
            return .epub
        case "md", "markdown":
            return .markdown
        case "txt", "text":
            return .plainText
        default:
            if url.scheme == "http" || url.scheme == "https" {
                return .webArticle
            }
            return .plainText
        }
    }
}
