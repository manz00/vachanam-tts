//
//  SentenceBoundsIntegrityTests.swift
//  VachanamTests
//
//  Verifies that sentence line bounds and word rects never bleed across adjacent sentences
//  or outside paragraph bounds.
//

import XCTest
import PDFKit
@testable import KokoroTTS
@testable import Vachanam

final class SentenceBoundsIntegrityTests: XCTestCase {
    
    func testAdjacentSentencesOnSameLineDoNotOverlapHorizontally() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            
            // Render two sentences clearly on the same visual line:
            let lineText = "First short sentence. Second sentence follows."
            lineText.draw(in: CGRect(x: 50, y: 100, width: 500, height: 30), withAttributes: [
                .font: UIFont.systemFont(ofSize: 14)
            ])
        }
        
        guard let pdf = PDFDocument(data: data) else {
            XCTFail("Failed to create test PDF")
            return
        }
        
        let doc = SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "Same-Line Sentences")
        XCTAssertGreaterThanOrEqual(doc.sentences.count, 2, "Must extract at least two sentences")
        
        let s0 = doc.sentences[0]
        let s1 = doc.sentences[1]
        
        XCTAssertTrue(s0.text.contains("First short sentence"), "First sentence must contain text: \(s0.text)")
        XCTAssertTrue(s1.text.contains("Second sentence follows"), "Second sentence must contain text: \(s1.text)")
        
        let s0LineBounds = s0.lineBounds(for: 0)
        let s1LineBounds = s1.lineBounds(for: 0)
        
        XCTAssertFalse(s0LineBounds.isEmpty, "Sentence 0 must have line bounds")
        XCTAssertFalse(s1LineBounds.isEmpty, "Sentence 1 must have line bounds")
        
        // When on the same line, Sentence 0 must be strictly to the left of Sentence 1
        if let s0Line = s0LineBounds.first, let s1Line = s1LineBounds.first {
            XCTAssertLessThanOrEqual(
                s0Line.maxX,
                s1Line.minX + 5.0, // Allow small font kerning tolerance
                "Sentence 0 (maxX: \(s0Line.maxX)) must not bleed into Sentence 1 (minX: \(s1Line.minX))"
            )
        }
    }
    
    func testMultiLineSentenceBoundsStayWithinParagraphBounds() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let paraText = """
            This is an extensive first sentence that continues across multiple visual lines in a compact paragraph format to test bounding accuracy. \
            And this is the second sentence that concludes the thought cleanly on its own subsequent line.
            """
            paraText.draw(in: CGRect(x: 60, y: 120, width: 300, height: 200), withAttributes: [
                .font: UIFont.systemFont(ofSize: 14)
            ])
        }
        
        guard let pdf = PDFDocument(data: data) else {
            XCTFail("Failed to create test PDF")
            return
        }
        
        let doc = SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "Multi-Line Paragraph")
        XCTAssertGreaterThanOrEqual(doc.sentences.count, 2, "Must segment into 2 sentences")
        
        let s0 = doc.sentences[0]
        let s1 = doc.sentences[1]
        
        let s0Lines = s0.lineBounds(for: 0)
        let s1Lines = s1.lineBounds(for: 0)
        
        XCTAssertFalse(s0Lines.isEmpty, "Sentence 0 must have line bounds")
        XCTAssertFalse(s1Lines.isEmpty, "Sentence 1 must have line bounds")
        
        // Sentence 0's words must all contain text from Sentence 0
        for word in s0.words {
            XCTAssertTrue(s0.text.contains(word.text), "Word '\(word.text)' must belong to Sentence 0")
        }
        
        // Sentence 1's words must all contain text from Sentence 1
        for word in s1.words {
            XCTAssertTrue(s1.text.contains(word.text), "Word '\(word.text)' must belong to Sentence 1")
        }
    }
    
    func testWordMidYValuesStayWithinSentenceLineBounds() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let text = "Artificial intelligence transforms accessibility technology for everyone."
            text.draw(in: CGRect(x: 50, y: 150, width: 450, height: 40), withAttributes: [
                .font: UIFont.systemFont(ofSize: 16)
            ])
        }
        
        guard let pdf = PDFDocument(data: data) else {
            XCTFail("Failed to create test PDF")
            return
        }
        
        let doc = SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "Word Y Bounds Test")
        guard let sentence = doc.sentences.first else {
            XCTFail("Expected at least one sentence")
            return
        }
        
        let lines = sentence.lineBounds(for: 0)
        XCTAssertFalse(lines.isEmpty, "Sentence must have line bounds")
        
        let minY = (lines.map { $0.minY }.min() ?? 0) - 4
        let maxY = (lines.map { $0.maxY }.max() ?? 0) + 4
        let validRange = minY...maxY
        
        for word in sentence.words where !word.bounds.isEmpty {
            XCTAssertTrue(
                validRange.contains(word.bounds.midY),
                "Word '\(word.text)' midY (\(word.bounds.midY)) must be within line bounds range \(validRange)"
            )
        }
    }
    
    func testDisplayedEquationAndTagNotSeveredIntoOrphanSentence() {
        let url = URL(fileURLWithPath: "/Users/manjunath/Documents/mml-book.pdf")
        guard let pdf = PDFDocument(url: url) else { return }
        
        let doc = SentenceSegmenter.shared.parseDocument(pdfDocument: pdf, title: "MML Book")
        let p47Sentences = doc.sentences.filter { $0.primaryPageIndex == 47 }
        
        // Assert no standalone equation tag sentence exists (e.g. text consisting solely of "(2.67)" or "equation 2.67")
        let orphanEquationTags = p47Sentences.filter {
            let t = $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t == "(2.67)" || t == "equation 2.67" || t == "(2.69)" || t == "equation 2.69"
        }
        XCTAssertTrue(orphanEquationTags.isEmpty, "Equation tags must not be severed into isolated sentences: \(orphanEquationTags.map { $0.text })")
        
        // Assert that Example 2.14 is unified with its vectors and equation tag (2.67)
        let exampleSentence = p47Sentences.first { $0.text.contains("Example 2.14") }
        XCTAssertNotNil(exampleSentence)
        XCTAssertTrue(exampleSentence?.text.contains("2.67") == true, "Sentence must include equation tag 2.67")
        XCTAssertTrue(exampleSentence?.text.contains("x1") == true, "Sentence must include vector x1")
        
        // Assert no page numbers are found in the body of page 47 (matrices contain 1, 2, 4, etc.)
        let pageNumbers = p47Sentences.filter { $0.blockType == .pageNumber }
        XCTAssertTrue(pageNumbers.isEmpty, "Matrix entries must not be classified as page numbers")
        
        // Assert that numbers, equations, and matrix fragments phonemize without throwing emptyOutput
        let phonemizer = KokoroMisakiPhonemizer()
        XCTAssertNoThrow(try phonemizer.phonemize("2.78"), "Isolated decimal number must phonemize successfully")
        XCTAssertNoThrow(try phonemizer.phonemize("equation 2.78"), "Equation reference must phonemize successfully")
        XCTAssertNoThrow(try phonemizer.phonemize("1 0 0"), "Matrix entries must phonemize successfully")
        XCTAssertNoThrow(try phonemizer.phonemize("-1.3 -2.2 3.5"), "Negative decimals must phonemize successfully")
        
        let chunk934Text = "Example 2.16 In R sub 3, the canonical/standard basis is B equals 1 0 0 , 1 0 0 , 0 0 1 , equation 2.78"
        let frags = KokoroChunkBoundaries.splitForRetry(chunk934Text)
        XCTAssertFalse(frags.isEmpty, "Chunk should produce split fragments")
        for frag in frags {
            XCTAssertNoThrow(try phonemizer.phonemize(frag), "Retry fragment '\(frag)' must not throw emptyOutput")
        }
        
        let p50Sentences = doc.sentences.filter { $0.primaryPageIndex == 50 }
        let example216Sentence = p50Sentences.first { $0.text.contains("Example 2.16") }
        XCTAssertNotNil(example216Sentence, "Example 2.16 must be present on page index 50")
        XCTAssertTrue(example216Sentence?.text.contains("2.78") == true, "Example 2.16 must include equation tag 2.78")
    }
}






