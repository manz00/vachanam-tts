//
//  MathAndSymbolNormalizationTests.swift
//  VachanamTests
//
//  Unit tests for mathematical symbol, Greek letter, vector space,
//  number-variable adjacency, and equation label speech normalization.
//

import XCTest
import NaturalLanguage
@testable import Vachanam

final class MathAndSymbolNormalizationTests: XCTestCase {
    
    let normalizer = TextNormalizer.shared
    private var previousMathStyle: MathSpeechStyle = .conversational
    
    override func setUp() {
        super.setUp()
        previousMathStyle = AccessibilityManager.shared.mathSpeechStyle
        AccessibilityManager.shared.mathSpeechStyle = .conversational
    }
    
    override func tearDown() {
        AccessibilityManager.shared.mathSpeechStyle = previousMathStyle
        super.tearDown()
    }
    
    func testGreekLetterNormalization() {
        let input = "Let λ be the eigenvalue and θ be the rotation angle with σ variance."
        let spoken = normalizer.normalizeForSpeech(input)
        XCTAssertTrue(spoken.contains("lambda"), "Expected lambda in: \(spoken)")
        XCTAssertTrue(spoken.contains("theta"), "Expected theta in: \(spoken)")
        XCTAssertTrue(spoken.contains("sigma"), "Expected sigma in: \(spoken)")
    }
    
    func testBlackboardBoldAndVectorSpaces() {
        let input1 = "Let x ∈ ℝⁿ be a vector."
        let spoken1 = normalizer.normalizeForSpeech(input1)
        XCTAssertTrue(spoken1.contains("in"), "Expected 'in' for ∈ in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("R n"), "Expected 'R n' for ℝⁿ in: \(spoken1)")
        
        let input2 = "Consider points in ℝ³."
        let spoken2 = normalizer.normalizeForSpeech(input2)
        XCTAssertTrue(spoken2.contains("R three"), "Expected 'R three' in: \(spoken2)")
        
        let input3 = "Numbers in ℕ, ℤ, and ℂ."
        let spoken3 = normalizer.normalizeForSpeech(input3)
        XCTAssertTrue(spoken3.contains("natural numbers"), "Expected natural numbers in: \(spoken3)")
        XCTAssertTrue(spoken3.contains("integers"), "Expected integers in: \(spoken3)")
        XCTAssertTrue(spoken3.contains("complex numbers"), "Expected complex numbers in: \(spoken3)")
    }
    
    func testMathOperators() {
        let input = "∀ x ∈ S, ∃ y such that A ⊆ B and A ∩ B = ∅ while x ↦ y with xᵀ."
        let spoken = normalizer.normalizeForSpeech(input)
        XCTAssertTrue(spoken.contains("for all"), "Expected 'for all' in: \(spoken)")
        XCTAssertTrue(spoken.contains("there exists"), "Expected 'there exists' in: \(spoken)")
        XCTAssertTrue(spoken.contains("subset of"), "Expected 'subset of' in: \(spoken)")
        XCTAssertTrue(spoken.contains("intersection"), "Expected 'intersection' in: \(spoken)")
        XCTAssertTrue(spoken.contains("empty set"), "Expected 'empty set' in: \(spoken)")
        XCTAssertTrue(spoken.contains("maps to"), "Expected 'maps to' in: \(spoken)")
        XCTAssertTrue(spoken.contains("transpose"), "Expected 'transpose' in: \(spoken)")
    }
    
    func testVectorArrowNormalization() {
        // Single and multi-arrow vectors
        let input1 = "Let →x and →y be vectors."
        let spoken1 = normalizer.normalizeForSpeech(input1)
        XCTAssertTrue(spoken1.contains("vector x"), "Expected 'vector x' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("vector y"), "Expected 'vector y' in: \(spoken1)")
        
        // Minus-arrow vector as extracted in LaTeX math
        let input2 = "Geometric vectors denoted by −→ x and −→ y."
        let spoken2 = normalizer.normalizeForSpeech(input2)
        XCTAssertTrue(spoken2.contains("vector x"), "Expected 'vector x' in: \(spoken2)")
        XCTAssertTrue(spoken2.contains("vector y"), "Expected 'vector y' in: \(spoken2)")
        
        // Combining vector arrow U+20D7
        let input3 = "Given x\u{20D7} + y\u{20D7} = z\u{20D7}."
        let spoken3 = normalizer.normalizeForSpeech(input3)
        XCTAssertTrue(spoken3.contains("vector x"), "Expected 'vector x' in: \(spoken3)")
        XCTAssertTrue(spoken3.contains("vector y"), "Expected 'vector y' in: \(spoken3)")
        XCTAssertTrue(spoken3.contains("vector z"), "Expected 'vector z' in: \(spoken3)")
        
        // Multiple stacked arrows
        let input4 = "Two geometric vectors→ → x, ycan be added, such that→ → → x+ y= z"
        let spoken4 = normalizer.normalizeForSpeech(input4)
        XCTAssertTrue(spoken4.contains("vector x"), "Expected 'vector x' in: \(spoken4)")
        XCTAssertTrue(spoken4.contains("y can be added"), "Expected 'y can be added' in: \(spoken4)")
        XCTAssertTrue(spoken4.contains("equals z"), "Expected 'equals z' in: \(spoken4)")
    }
    
    func testSuperscriptsExponentsAndCarets() {
        // Squares and cubes
        let input1 = "Compute x^2 + y^3 = z^n."
        let spoken1 = normalizer.normalizeForSpeech(input1)
        XCTAssertTrue(spoken1.contains("x squared"), "Expected 'x squared' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("y cubed"), "Expected 'y cubed' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("z to the n"), "Expected 'z to the n' in: \(spoken1)")
        
        // Unicode superscripts
        let input2 = "Points in x² and y³."
        let spoken2 = normalizer.normalizeForSpeech(input2)
        XCTAssertTrue(spoken2.contains("x squared"), "Expected 'x squared' in: \(spoken2)")
        XCTAssertTrue(spoken2.contains("y cubed"), "Expected 'y cubed' in: \(spoken2)")
        
        // Matrix transpose and inverse
        let input3 = "We compute A^T, A⊤, A^-1, and A⁻¹."
        let spoken3 = normalizer.normalizeForSpeech(input3)
        XCTAssertTrue(spoken3.contains("A transpose"), "Expected 'A transpose' in: \(spoken3)")
        XCTAssertTrue(spoken3.contains("A inverse"), "Expected 'A inverse' in: \(spoken3)")
        
        // Carets / hats: x^ and ^x and x̂
        let input4 = "Estimate parameters ^x and y^ with true value x\u{0302}."
        let spoken4 = normalizer.normalizeForSpeech(input4)
        XCTAssertTrue(spoken4.contains("x hat"), "Expected 'x hat' in: \(spoken4)")
        XCTAssertTrue(spoken4.contains("y hat"), "Expected 'y hat' in: \(spoken4)")
    }
    
    func testSubscriptsAndMatrixDimensions() {
        let input1 = "Variables x_1, x_i, and weight W_ij."
        let spoken1 = normalizer.normalizeForSpeech(input1)
        XCTAssertTrue(spoken1.contains("x sub 1"), "Expected 'x sub 1' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("x sub i"), "Expected 'x sub i' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("W sub ij"), "Expected 'W sub ij' in: \(spoken1)")
        
        // Matrix dimensions
        let input2 = "Consider A ∈ Rn×n and (n,n)-matrices."
        let spoken2 = normalizer.normalizeForSpeech(input2)
        XCTAssertTrue(spoken2.contains("R n by n"), "Expected 'R n by n' in: \(spoken2)")
        XCTAssertTrue(spoken2.contains("n by n matrices"), "Expected 'n by n matrices' in: \(spoken2)")
    }
    
    func testAccentsNormsAndInnerProducts() {
        let input1 = "Norm ‖x‖ and inner product ⟨x, y⟩ with x̄ and x*."
        let spoken1 = normalizer.normalizeForSpeech(input1)
        XCTAssertTrue(spoken1.contains("the norm of x"), "Expected 'the norm of x' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("the inner product of x and y"), "Expected 'the inner product' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("x bar"), "Expected 'x bar' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("x star"), "Expected 'x star' in: \(spoken1)")
    }
    
    func testAttachedMathWordCorrections() {
        let input = "Columns of Aas the rows and ycan be added to xand y."
        let spoken = normalizer.normalizeForSpeech(input)
        XCTAssertTrue(spoken.contains("A as"), "Expected 'A as' in: \(spoken)")
        XCTAssertTrue(spoken.contains("y can"), "Expected 'y can' in: \(spoken)")
        XCTAssertTrue(spoken.contains("x and y"), "Expected 'x and y' in: \(spoken)")
    }
    
    func testNumberVariableAdjacency() {
        let input1 = "Compute 0.5x + 2.0y = 10z."
        let spoken1 = normalizer.normalizeForSpeech(input1)
        XCTAssertTrue(spoken1.contains("0.5 x"), "Expected '0.5 x' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("2.0 y"), "Expected '2.0 y' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("10 z"), "Expected '10 z' in: \(spoken1)")
        
        // Ensure ordinal numbers like 1st, 2nd, 3rd, 4th are preserved
        let input2 = "This is the 1st step and 2nd iteration."
        let spoken2 = normalizer.normalizeForSpeech(input2)
        XCTAssertTrue(spoken2.contains("1st"), "Expected '1st' preserved in: \(spoken2)")
        XCTAssertTrue(spoken2.contains("2nd"), "Expected '2nd' preserved in: \(spoken2)")
    }
    
    func testEquationLabelNormalization() {
        let input = "The system is given by Ax = b (2.1)"
        let spoken = normalizer.normalizeForSpeech(input)
        XCTAssertTrue(spoken.contains("equation 2.1"), "Expected 'equation 2.1' in: \(spoken)")
    }
    
    func testDecimalProtectionDuringSentenceSegmentation() {
        // Verify that 2.0 and 0.5 inside a paragraph do not cause sentence boundary splits
        let text = "The value is 2.0 and it represents a 0.5 scaling factor. Next sentence begins here."
        
        let decimalProtectedText = text.replacingOccurrences(
            of: #"(?<=\d)\.(?=\d)"#,
            with: "__DECIMAL_POINT__",
            options: .regularExpression
        )
        
        let tokenizer = NaturalLanguage.NLTokenizer(unit: .sentence)
        tokenizer.string = decimalProtectedText
        
        var sentences: [String] = []
        let range = decimalProtectedText.startIndex..<decimalProtectedText.endIndex
        tokenizer.enumerateTokens(in: range) { sRange, _ in
            let raw = String(decimalProtectedText[sRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let restored = raw.replacingOccurrences(of: "__DECIMAL_POINT__", with: ".")
            sentences.append(restored)
            return true
        }
        
        XCTAssertEqual(sentences.count, 2, "Expected exactly 2 sentences, got \(sentences.count): \(sentences)")
        XCTAssertTrue(sentences[0].contains("2.0 and it represents a 0.5 scaling factor"), "Sentence was improperly split on decimal: \(sentences[0])")
    }
    
    func testPage8ParagraphIntegrityAndRunInHeading() {
        // Test that run-in bold headings like 'Fledgling Composer' and paragraph ends like 'from data.'
        // are preserved in logical paragraphs without missing words or lines.
        let line1 = VisualLine(text: "Fledgling Composer ", bounds: CGRect(x: 82.9, y: 276.4, width: 96.2, height: 10.1), pageIndex: 8)
        let line2 = VisualLine(text: "As machine learning is applied to new domains,", bounds: CGRect(x: 191.9, y: 276.4, width: 214.7, height: 10.1), pageIndex: 8)
        let line3 = VisualLine(text: "developers of machine learning need to develop new methods and extend", bounds: CGRect(x: 72.0, y: 263.4, width: 334.7, height: 10.1), pageIndex: 8)
        let line4 = VisualLine(text: "existing algorithms. There is a great need in society for new researchers who are able to propose and explore novel approaches for attacking the many challenges of learning", bounds: CGRect(x: 72.0, y: 159.8, width: 334.7, height: 10.1), pageIndex: 8)
        let line5 = VisualLine(text: "from data.", bounds: CGRect(x: 72.0, y: 146.9, width: 47.6, height: 10.1), pageIndex: 8)
        
        let paragraphs = ParagraphDetector.shared.detectParagraphs(
            from: [line1, line2, line3, line4, line5],
            pageIndex: 8,
            pageBounds: CGRect(x: 0, y: 0, width: 595, height: 841)
        )
        
        XCTAssertFalse(paragraphs.isEmpty)
        let fullCombined = paragraphs.map { $0.combinedText }.joined(separator: " ")
        XCTAssertTrue(fullCombined.contains("Fledgling Composer"), "Expected heading to be present")
        XCTAssertTrue(fullCombined.contains("from data."), "Expected last line 'from data.' to be retained in paragraph text")
        
        // Verify that Fledgling Composer is separated by a period for natural speech pausing
        XCTAssertTrue(fullCombined.contains("Fledgling Composer. As machine learning"), "Expected run-in heading to have period delimiter for natural speech")
    }
}
