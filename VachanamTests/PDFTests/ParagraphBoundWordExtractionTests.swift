//
//  ParagraphBoundWordExtractionTests.swift
//  VachanamTests
//
//  Tests verifying that word bounding boxes stay strictly confined within their
//  parent paragraph and never bleed into other paragraphs even with identical words.
//

import XCTest
import PDFKit
@testable import Vachanam

final class ParagraphBoundWordExtractionTests: XCTestCase {
    
    func testWordsInDifferentParagraphsStayWithinRespectiveParagraphBounds() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            
            // Paragraph 1: Top of page (in top-down coords y = 80 -> PDF bottom-up coords Y ~ 700)
            let para1Text = "The matrix is in the vector space. We study the matrix and vector in this chapter."
            para1Text.draw(in: CGRect(x: 50, y: 80, width: 500, height: 60), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            
            // Paragraph 2: Lower on page (in top-down coords y = 350 -> PDF bottom-up coords Y ~ 400)
            let para2Text = "The matrix is in the data set. We compute the matrix and vector in another model."
            para2Text.draw(in: CGRect(x: 50, y: 350, width: 500, height: 60), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        
        guard let pdf = PDFDocument(data: data) else {
            XCTFail("Failed to create test PDF")
            return
        }
        
        let doc = SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "Boundary Test")
        
        XCTAssertGreaterThanOrEqual(doc.paragraphs.count, 2, "Must detect at least 2 distinct paragraphs")
        
        let p0 = doc.paragraphs[0]
        let p1 = doc.paragraphs[1]
        
        let p0Words = p0.sentenceIDs.compactMap { doc.sentence(id: $0) }.flatMap { $0.words }
        let p1Words = p1.sentenceIDs.compactMap { doc.sentence(id: $0) }.flatMap { $0.words }
        
        XCTAssertFalse(p0Words.isEmpty, "Paragraph 0 must have words")
        XCTAssertFalse(p1Words.isEmpty, "Paragraph 1 must have words")
        
        // Find boundary dividing the two paragraphs
        let p0MinY = p0Words.map { $0.bounds.minY }.min() ?? 0
        let p1MaxY = p1Words.map { $0.bounds.maxY }.max() ?? 0
        
        // All p0 words must be vertically above all p1 words in PDF coordinates (Y starts at bottom)
        for w0 in p0Words {
            XCTAssertGreaterThan(
                w0.bounds.minY,
                p1MaxY - 10,
                "Word '\(w0.text)' in Paragraph 0 must stay above Paragraph 1 (bounds: \(w0.bounds), p1MaxY: \(p1MaxY))"
            )
        }
        
        for w1 in p1Words {
            XCTAssertLessThan(
                w1.bounds.maxY,
                p0MinY + 10,
                "Word '\(w1.text)' in Paragraph 1 must stay below Paragraph 0 (bounds: \(w1.bounds), p0MinY: \(p0MinY))"
            )
        }
    }
    
    func testMMLPage20ParagraphSeparationAndSentenceIsolation() {
        let path = "/Users/manjunath/Documents/mml-book.pdf"
        guard FileManager.default.fileExists(atPath: path),
              let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
            return
        }
        
        let singlePageDoc = PDFDocument()
        if let page = doc.page(at: 20) {
            singlePageDoc.insert(page, at: 0)
        }
        
        let semDoc = SentenceSegmenter.shared.parseDocument(pdfDocument: singlePageDoc, title: "MML Page 20")
        
        // Assert multiple distinct paragraphs on this page (Intro, Part II, Ch 8, Ch 9, Ch 10, Ch 11, Ch 12)
        XCTAssertGreaterThanOrEqual(semDoc.paragraphs.count, 5, "MML Page 20 must have at least 5 distinct paragraphs")
        
        // Find the sentence "Unlike regression, dimensionality reduction..."
        let targetSentence = semDoc.sentences.first(where: { $0.text.contains("Unlike regression") })
        XCTAssertNotNil(targetSentence, "Sentence 'Unlike regression...' must be found")
        
        guard let sentence = targetSentence else { return }
        
        // Find its parent paragraph and compute its union bounds
        guard let parentPara = semDoc.paragraphs.first(where: { $0.paragraphID == sentence.paragraphID }) else {
            XCTFail("Parent paragraph for sentence must exist")
            return
        }
        
        let parentSentenceBounds = parentPara.sentenceIDs.compactMap { semDoc.sentence(id: $0) }.map { $0.bounds(for: 0) }
        guard let firstBound = parentSentenceBounds.first else {
            XCTFail("Parent paragraph must have sentence bounds")
            return
        }
        let parentParaBounds = parentSentenceBounds.dropFirst().reduce(firstBound) { $0.union($1) }
        
        // Every word in this sentence must stay strictly within parentParaBounds
        let allowedParaBounds = parentParaBounds.insetBy(dx: -10, dy: -10)
        for word in sentence.words {
            XCTAssertTrue(
                allowedParaBounds.contains(CGPoint(x: word.bounds.midX, y: word.bounds.midY)),
                "Word '\(word.text)' midY (\(word.bounds.midY)) must be inside paragraph bounds (\(parentParaBounds))"
            )
        }
        
        // None of the sentence's lineBounds should extend above Chapter 10's paragraph top (into Chapter 8 or 9)
        let lineBounds = sentence.lineBounds(for: 0)
        for lb in lineBounds {
            XCTAssertLessThan(
                lb.maxY,
                parentParaBounds.maxY + 10,
                "Line bound \(lb) must not extend above Chapter 10 paragraph top"
            )
        }
    }
}
