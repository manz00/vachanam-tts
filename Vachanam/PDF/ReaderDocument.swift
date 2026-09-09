//
//  ReaderDocument.swift
//  Vachanam
//
//  Universal document model wrapping PDFKit for PDFs, and ParsedDocument / SemanticDocument
//  for EPUB, Markdown, Plain Text, and Web articles with unified TOC and page navigation.
//

import Foundation
import PDFKit

public struct TOCItem: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let pageIndex: Int
    public let children: [TOCItem]
    
    public init(title: String, pageIndex: Int, children: [TOCItem] = []) {
        self.title = title
        self.pageIndex = pageIndex
        self.children = children
    }
}

public class ReaderDocument: Identifiable, ObservableObject {
    public let id = UUID()
    public let fileURL: URL
    public let pdfDocument: PDFDocument
    public let title: String
    public var pageCount: Int
    public let format: DocumentFormat
    public var parsedDocument: ParsedDocument?
    public var semanticDocument: SemanticDocument?
    
    @Published public var tocItems: [TOCItem] = []
    
    public init?(url: URL) {
        let detected = DocumentFormat.detect(from: url)
        self.format = detected
        self.fileURL = url
        self.title = url.deletingPathExtension().lastPathComponent
        
        if detected == .pdf {
            guard let doc = PDFDocument(url: url) else { return nil }
            self.pdfDocument = doc
            self.pageCount = doc.pageCount
            self.tocItems = extractTOC(from: doc.outlineRoot)
        } else {
            // For non-PDF files, initialize with dummy PDFDocument and 1 page initially
            self.pdfDocument = PDFDocument()
            self.pageCount = 1
        }
    }
    
    public init(
        parsedDocument: ParsedDocument,
        fileURL: URL,
        semanticDocument: SemanticDocument
    ) {
        self.format = parsedDocument.format
        self.title = parsedDocument.title
        self.fileURL = fileURL
        self.pdfDocument = PDFDocument()
        self.pageCount = semanticDocument.pageCount
        self.parsedDocument = parsedDocument
        self.semanticDocument = semanticDocument
        self.tocItems = parsedDocument.chapters.enumerated().map { (idx, ch) in
            TOCItem(title: ch.title ?? "Section \(idx + 1)", pageIndex: idx)
        }
    }
    
    public init?(data: Data, title: String = "Untitled Document") {
        guard let doc = PDFDocument(data: data) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        try? data.write(to: tempURL)
        self.format = .pdf
        self.fileURL = tempURL
        self.pdfDocument = doc
        self.title = title
        self.pageCount = doc.pageCount
        self.tocItems = extractTOC(from: doc.outlineRoot)
    }
    
    public func page(at index: Int) -> PDFPage? {
        guard format == .pdf, index >= 0 && index < pageCount else { return nil }
        return pdfDocument.page(at: index)
    }
    
    public func text(forPageIndex index: Int) -> String {
        if format == .pdf {
            guard let page = page(at: index) else { return "" }
            return page.string ?? ""
        } else if let semDoc = semanticDocument {
            let pageWords = semDoc.words(forPageIndex: index)
            return pageWords.map { $0.text }.joined(separator: " ")
        }
        return ""
    }
    
    private func extractTOC(from outline: PDFOutline?) -> [TOCItem] {
        guard let outline = outline else { return [] }
        var items: [TOCItem] = []
        
        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }
            let title = child.label ?? "Untitled Section"
            var pageIndex = 0
            if let dest = child.destination, let page = dest.page {
                pageIndex = pdfDocument.index(for: page)
            } else if let action = child.action as? PDFActionGoTo, let page = action.destination.page {
                pageIndex = pdfDocument.index(for: page)
            }
            let subChildren = extractTOC(from: child)
            items.append(TOCItem(title: title, pageIndex: pageIndex, children: subChildren))
        }
        return items
    }
}
