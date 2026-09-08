//
//  AnnotationExporterTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class AnnotationExporterTests: XCTestCase {
    
    func testMarkdownExportFormatting() {
        let note = StickyNoteAnnotation(pageIndex: 0, position: .zero, content: "Remember this formula")
        let box = TextBoxAnnotation(pageIndex: 1, position: .zero, text: "Important fact")
        let shape = ShapeAnnotation(pageIndex: 0, shapeType: .rectangle, startPoint: .zero, endPoint: CGPoint(x: 20, y: 20))
        let bookmark = Bookmark(documentURL: URL(fileURLWithPath: "/tmp/doc.pdf"), pageIndex: 0, pageTitle: "Introduction", note: "Start here")
        
        let md = AnnotationExporter.exportToMarkdown(
            documentTitle: "Sample Document",
            stickyNotes: [note],
            textBoxes: [box],
            shapes: [shape],
            bookmarks: [bookmark]
        )
        
        XCTAssertTrue(md.contains("# Reading Notes & Annotations: Sample Document"))
        XCTAssertTrue(md.contains("## 📌 Bookmarks"))
        XCTAssertTrue(md.contains("Remember this formula"))
        XCTAssertTrue(md.contains("Important fact"))
        XCTAssertTrue(md.contains("Rectangle callout"))
    }
}
