//
//  TextExtractorTests.swift
//  VachanamTests
//

import XCTest
import PDFKit
@testable import Vachanam

final class TextExtractorTests: XCTestCase {
    
    func testSentenceExtractionFromSynthesizedPage() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            let text = "First sentence here. Second sentence starts now! And a third?"
            text.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        
        let pdfDoc = PDFDocument(data: data)!
        let page = pdfDoc.page(at: 0)!
        
        let sentences = TextExtractor.shared.extractSentences(from: page, pageIndex: 0)
        XCTAssertEqual(sentences.count, 3)
        XCTAssertEqual(sentences[0].words.count, 3)
        XCTAssertEqual(sentences[1].words.count, 4)
    }
}
