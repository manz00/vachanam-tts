//
//  ReaderDocument.swift
//  Vachanam
//
//  PDF document model wrapping PDFKit with TOC and page metadata.
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
    public let pageCount: Int
    @Published public var tocItems: [TOCItem] = []
    
    public init?(url: URL) {
        guard let doc = PDFDocument(url: url) else { return nil }
        self.fileURL = url
        self.pdfDocument = doc
        self.title = url.deletingPathExtension().lastPathComponent
        self.pageCount = doc.pageCount
        self.tocItems = extractTOC(from: doc.outlineRoot)
    }
    
    public init?(data: Data, title: String = "Untitled Document") {
        guard let doc = PDFDocument(data: data) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        try? data.write(to: tempURL)
        self.fileURL = tempURL
        self.pdfDocument = doc
        self.title = title
        self.pageCount = doc.pageCount
        self.tocItems = extractTOC(from: doc.outlineRoot)
    }
    
    public func page(at index: Int) -> PDFPage? {
        guard index >= 0 && index < pageCount else { return nil }
        return pdfDocument.page(at: index)
    }
    
    public func text(forPageIndex index: Int) -> String {
        guard let page = page(at: index) else { return "" }
        return page.string ?? ""
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
