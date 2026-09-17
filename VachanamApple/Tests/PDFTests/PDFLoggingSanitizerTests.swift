//
//  PDFLoggingSanitizerTests.swift
//  VachanamTests
//
//  Tests for PDFLoggingSanitizer stderr filtering and TextNormalizer unmapped glyph cleaning.
//

import XCTest
@testable import Vachanam

final class PDFLoggingSanitizerTests: XCTestCase {
    
    func testShouldSuppressPatternRecognition() {
        // Font glyph mapping errors
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: ".notdef: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "mapsto: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "summationtext: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "parenleftbig: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "bracketrightbigg: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "radicalbig: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "hatwide: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "arrowhookleft: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "tie: no mapping."))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "suppress: no mapping."))
        
        // CGPDFImage subsample diagnostics
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "CGPDFImage(0x93f84b100): Creating image with subsample_factor = 4"))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "CGPDFImage(0x93f84b100): subsample_factor MISMATCH. existing = 4, requested = 2"))
        
        // CTLD CoreText line display timings
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "CTLD took 0.000252962 seconds"))
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "CTLD took 2.5034e-05 seconds"))
        
        // PDFKit PageLayout / PDFPageAnalyzer text range warnings
        XCTAssertTrue(PDFLoggingSanitizer.shouldSuppress(line: "New text range needs to be within the original node's text range."))
        
        // Legitimate logs MUST NOT be suppressed
        XCTAssertFalse(PDFLoggingSanitizer.shouldSuppress(line: "Fatal error: Index out of range"))
        XCTAssertFalse(PDFLoggingSanitizer.shouldSuppress(line: "Assertion failed: (x > 0)"))
        XCTAssertFalse(PDFLoggingSanitizer.shouldSuppress(line: "[KokoroTTS] Model loaded successfully"))
        XCTAssertFalse(PDFLoggingSanitizer.shouldSuppress(line: "Warning: Missing bundle resource"))
        XCTAssertFalse(PDFLoggingSanitizer.shouldSuppress(line: "Error: Failed to open audio stream"))
    }
    
    func testSuppressingStderrBlockExecution() {
        var executed = false
        
        let result = PDFLoggingSanitizer.suppressingStderr { () -> Int in
            executed = true
            // Write directly to stderr while suppressed
            fputs(".notdef: no mapping.\n", stderr)
            fflush(stderr)
            return 42
        }
        
        XCTAssertTrue(executed)
        XCTAssertEqual(result, 42)
    }
    
    func testTextNormalizerCleansUnmappedGlyphsAndReplacements() {
        let normalizer = TextNormalizer.shared
        
        // Unicode replacement character \u{FFFD}
        let textWithReplacement = "Let \u{FFFD} be a continuous function over \u{FFFD}."
        let cleaned = normalizer.normalize(textWithReplacement)
        XCTAssertFalse(cleaned.contains("\u{FFFD}"))
        XCTAssertEqual(cleaned, "Let be a continuous function over .")
        
        // Unprintable control characters
        let textWithControlChars = "Hello\u{0000}\u{0007}\u{001B} World"
        let cleanedControl = normalizer.normalize(textWithControlChars)
        XCTAssertEqual(cleanedControl, "Hello World")
        
        // Private use area glyphs (e.g. \u{E001}) common in TeX math fonts
        let textWithPUA = "Equation: x + \u{E123} = y"
        let cleanedPUA = normalizer.normalize(textWithPUA)
        XCTAssertEqual(cleanedPUA, "Equation: x + = y")
    }
}
