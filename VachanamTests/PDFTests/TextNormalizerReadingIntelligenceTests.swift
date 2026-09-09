//
//  TextNormalizerReadingIntelligenceTests.swift
//  VachanamTests
//
//  Unit tests for TextNormalizer human-like reading intelligence:
//  abbreviations, citations, URLs, and DOIs.
//

import XCTest
@testable import Vachanam

final class TextNormalizerReadingIntelligenceTests: XCTestCase {
    
    func testAbbreviationExpansions() {
        let normalizer = TextNormalizer.shared
        
        // e.g. and i.e.
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Use on-device models, e.g., Kokoro or FastSpeech."),
            "Use on device models, for example, Kokoro or FastSpeech."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("The active model, i.e. Kokoro-82M, is fast."),
            "The active model, that is, Kokoro-82M, is fast."
        )
        
        // et al.
        XCTAssertEqual(
            normalizer.normalizeForSpeech("According to Vaswani et al., attention is all you need."),
            "According to Vaswani and colleagues, attention is all you need."
        )
        
        // etc.
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Apples, oranges, bananas, etc. are fruits."),
            "Apples, oranges, bananas, etcetera are fruits."
        )
        
        // vs.
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Compare CoreML vs. PyTorch performance."),
            "Compare CoreML versus PyTorch performance."
        )
        
        // approx.
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Processing takes approx. 200 ms."),
            "Processing takes approximately 200 milliseconds."
        )
        
        // ca. / c. before year
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Founded ca. 1985."),
            "Founded circa 1985."
        )
        
        // p. and pp.
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Refer to p. 42 for instructions."),
            "Refer to page 42 for instructions."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("See details on pp. 100 to 105."),
            "See details on pages 100 to 105."
        )
        
        // Fig., Figs., Vol., No.
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Shown in Fig. 3."),
            "Shown in Figure 3."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Compare Figs. 1 and 2."),
            "Compare Figures 1 and 2."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Journal of AI, Vol. 12, No. 4."),
            "Journal of AI, Volume 12, Number 4."
        )
    }
    
    func testURLAndDOINormalization() {
        let normalizer = TextNormalizer.shared
        
        // Web URLs
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Visit https://swift.org/documentation for guides."),
            "Visit link to swift.org for guides."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Source code at https://github.com/apple/swift-corelibs-foundation."),
            "Source code at link to github.com."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Check www.apple.com for updates."),
            "Check link to apple.com for updates."
        )
        
        // DOIs
        XCTAssertEqual(
            normalizer.normalizeForSpeech("Paper doi:10.1145/3372278.3390670 discusses neural codecs."),
            "Paper publication link discusses neural codecs."
        )
    }
}
