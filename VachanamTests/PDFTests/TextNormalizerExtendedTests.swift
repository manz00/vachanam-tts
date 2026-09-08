//
//  TextNormalizerExtendedTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class TextNormalizerExtendedTests: XCTestCase {
    
    func testCurrencySpokenNormalization() {
        let normalizer = TextNormalizer.shared
        XCTAssertEqual(normalizer.normalizeForSpeech("It costs $50 to enter."), "It costs 50 dollars to enter.")
        XCTAssertEqual(normalizer.normalizeForSpeech("Total was €120.50 today."), "Total was 120.50 euros today.")
        XCTAssertEqual(normalizer.normalizeForSpeech("Price is £15."), "Price is 15 pounds.")
        XCTAssertEqual(normalizer.normalizeForSpeech("Fee is ¥5000."), "Fee is 5000 yen.")
    }
    
    func testPercentageAndPlusMinus() {
        let normalizer = TextNormalizer.shared
        XCTAssertEqual(normalizer.normalizeForSpeech("Growth of 25% was observed."), "Growth of 25 percent was observed.")
        XCTAssertEqual(normalizer.normalizeForSpeech("Margin is ±5 mm."), "Margin is plus or minus 5 mm.")
    }
    
    func testTemperatureAndMathSymbols() {
        let normalizer = TextNormalizer.shared
        XCTAssertEqual(normalizer.normalizeForSpeech("Heated to 100°C."), "Heated to 100 degrees Celsius.")
        XCTAssertEqual(normalizer.normalizeForSpeech("Cooled to 32°F."), "Cooled to 32 degrees Fahrenheit.")
        XCTAssertEqual(normalizer.normalizeForSpeech("Turned 90°."), "Turned 90 degrees.")
        
        let math = "A × B ÷ C ≠ D ≤ E ≥ F ≈ G"
        let spoken = normalizer.normalizeForSpeech(math)
        XCTAssertTrue(spoken.contains("times"))
        XCTAssertTrue(spoken.contains("divided by"))
        XCTAssertTrue(spoken.contains("not equal to"))
        XCTAssertTrue(spoken.contains("less than or equal to"))
        XCTAssertTrue(spoken.contains("greater than or equal to"))
        XCTAssertTrue(spoken.contains("approximately"))
    }
    
    func testFractionsAndSymbols() {
        let normalizer = TextNormalizer.shared
        XCTAssertEqual(normalizer.normalizeForSpeech("Add ½ cup of milk."), "Add one half cup of milk.")
        XCTAssertEqual(normalizer.normalizeForSpeech("Use ¾ cup."), "Use three quarters cup.")
        XCTAssertEqual(normalizer.normalizeForSpeech("Black & White"), "Black and White")
    }
    
    func testBulletAndListMarkerStripping() {
        let normalizer = TextNormalizer.shared
        XCTAssertEqual(
            normalizer.normalizeForSpeech("• Word-by-word synchronized reading."),
            "Word-by-word synchronized reading."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("◦ Dyslexia reading ruler."),
            "Dyslexia reading ruler."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("▪ Distraction-free reader mode."),
            "Distraction-free reader mode."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("● Full Apple Pencil drawing support."),
            "Full Apple Pencil drawing support."
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("- First list item\n- Second list item"),
            "First list item Second list item"
        )
        XCTAssertEqual(
            normalizer.normalizeForSpeech("* Asterisk bullet item"),
            "Asterisk bullet item"
        )
    }
}
