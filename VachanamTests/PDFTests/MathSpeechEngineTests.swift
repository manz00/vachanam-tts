//
//  MathSpeechEngineTests.swift
//  VachanamTests
//
//  Tests for standardized Speech Rule Engine (SRE) and MathSpeak vocalizer,
//  scientific exponential notation, SI unit expansions, LaTeX macros, and style verbosity.
//

import XCTest
@testable import Vachanam

final class MathSpeechEngineTests: XCTestCase {
    
    let engine = MathSpeechEngine.shared
    let normalizer = TextNormalizer.shared
    
    // MARK: - 1. Scientific Notation Tests
    
    func testScientificExponentialNotationConversational() {
        // Avogadro's number
        let avogadro = "The constant is 6.022e23 molecules."
        let spokenAvogadro = engine.normalizeMath(avogadro, style: .conversational)
        XCTAssertTrue(spokenAvogadro.contains("twenty three") || spokenAvogadro.contains("twenty-three"), "Expected power of 23 in: \(spokenAvogadro)")
        XCTAssertTrue(spokenAvogadro.contains("times ten to the power of"), "Expected 'times ten to the power of' in: \(spokenAvogadro)")
        
        // Negative exponent
        let smallNum = "Charge is 1.6e-19 coulombs."
        let spokenSmall = engine.normalizeMath(smallNum, style: .conversational)
        XCTAssertTrue(spokenSmall.contains("times ten to the minus nineteen"), "Expected minus nineteen in: \(spokenSmall)")
        
        // Negative mantissa and negative exponent
        let negMantissa = "Value is -3e-9 units."
        let spokenNeg = engine.normalizeMath(negMantissa, style: .conversational)
        XCTAssertTrue(spokenNeg.contains("negative 3") || spokenNeg.contains("minus 3"), "Expected negative 3 in: \(spokenNeg)")
        XCTAssertTrue(spokenNeg.contains("times ten to the minus nine"), "Expected minus nine in: \(spokenNeg)")
        
        // Power 2 and 3
        let powerTwo = "Scale is 1e2 meters."
        let spokenTwo = engine.normalizeMath(powerTwo, style: .conversational)
        XCTAssertTrue(spokenTwo.contains("times ten squared") || spokenTwo.contains("times ten to the second"), "Expected ten squared in: \(spokenTwo)")
        
        let powerThree = "Scale is 5.5e3 meters."
        let spokenThree = engine.normalizeMath(powerThree, style: .conversational)
        XCTAssertTrue(spokenThree.contains("times ten cubed") || spokenThree.contains("times ten to the third"), "Expected ten cubed in: \(spokenThree)")
        
        // Explicit notation (x 10^n)
        let explicit = "Speed of light is 3.0 x 10^8 m/s."
        let spokenExplicit = engine.normalizeMath(explicit, style: .conversational)
        XCTAssertTrue(spokenExplicit.contains("times ten to the eighth"), "Expected eighth power in: \(spokenExplicit)")
    }
    
    func testScientificNotationMathSpeakRigorous() {
        let avogadro = "Constant: 6.022e23."
        let spokenAvogadro = engine.normalizeMath(avogadro, style: .mathSpeakRigorous)
        XCTAssertTrue(spokenAvogadro.contains("times ten to the power twenty three") || spokenAvogadro.contains("times ten to the power twenty-three"), "Expected power twenty-three in: \(spokenAvogadro)")
        
        let smallNum = "Offset: 1.5E-4."
        let spokenSmall = engine.normalizeMath(smallNum, style: .mathSpeakRigorous)
        XCTAssertTrue(spokenSmall.contains("times ten to the negative four power"), "Expected negative four power in: \(spokenSmall)")
    }
    
    // MARK: - 2. SI Units and Metric Prefixes Tests
    
    func testNumberAdjacentSIUnits() {
        let input = "The transistor gate is 5 nm, clock speed is 2.4 GHz, latency is 100 ms, and supply is 12 V."
        let spoken = engine.vocalizeSIUnits(input)
        XCTAssertTrue(spoken.contains("5 nanometers"), "Expected 5 nanometers in: \(spoken)")
        XCTAssertTrue(spoken.contains("2.4 gigahertz"), "Expected 2.4 gigahertz in: \(spoken)")
        XCTAssertTrue(spoken.contains("100 milliseconds"), "Expected 100 milliseconds in: \(spoken)")
        XCTAssertTrue(spoken.contains("12 volts"), "Expected 12 volts in: \(spoken)")
    }
    
    func testSIUnitsSingularVsPlural() {
        let singular = "Length: 1 nm and 1.0 mm."
        let spokenSingular = engine.vocalizeSIUnits(singular)
        XCTAssertTrue(spokenSingular.contains("1 nanometer"), "Expected 1 nanometer in: \(spokenSingular)")
        XCTAssertTrue(spokenSingular.contains("1.0 millimeter"), "Expected 1.0 millimeter in: \(spokenSingular)")
        
        let plural = "Length: 2 nm and 3.5 mm."
        let spokenPlural = engine.vocalizeSIUnits(plural)
        XCTAssertTrue(spokenPlural.contains("2 nanometers"), "Expected 2 nanometers in: \(spokenPlural)")
        XCTAssertTrue(spokenPlural.contains("3.5 millimeters"), "Expected 3.5 millimeters in: \(spokenPlural)")
    }
    
    func testCompoundSIUnits() {
        let speed = "Car velocity was 120 km/h with acceleration 9.8 m/s^2."
        let spoken = engine.vocalizeSIUnits(speed)
        XCTAssertTrue(spoken.contains("kilometers per hour"), "Expected kilometers per hour in: \(spoken)")
        XCTAssertTrue(spoken.contains("meters per second squared"), "Expected meters per second squared in: \(spoken)")
    }
    
    func testSIUnitsDoNotMutateRegularEnglishWords() {
        let sentences = [
            "This diagnosis is a ms symptom.",
            "He traveled to V for his summer vacation.",
            "Take a m detour.",
            "He had a kg of apples." // without number before kg: "a kg"
        ]
        for sentence in sentences {
            let spoken = engine.vocalizeSIUnits(sentence)
            if sentence.contains("a ms") {
                XCTAssertFalse(spoken.contains("millisecond"), "Should not expand 'a ms': \(spoken)")
            }
            if sentence.contains("to V") {
                XCTAssertFalse(spoken.contains("volt"), "Should not expand 'to V': \(spoken)")
            }
        }
    }
    
    // MARK: - 3. Standardized Symbols (SRE & MathSpeak)
    
    func testSymbolsConversational() {
        let text = "For x ∈ S with x ≠ y and x ≤ z, we have ∫ f(x) dx ≈ 0."
        let spoken = engine.normalizeMath(text, style: .conversational)
        XCTAssertTrue(spoken.contains("in"), "Expected 'in' for ∈ in: \(spoken)")
        XCTAssertTrue(spoken.contains("not equal to"), "Expected 'not equal to' for ≠ in: \(spoken)")
        XCTAssertTrue(spoken.contains("less than or equal to"), "Expected 'less than or equal to' for ≤ in: \(spoken)")
        XCTAssertTrue(spoken.contains("integral of"), "Expected 'integral of' for ∫ in: \(spoken)")
        XCTAssertTrue(spoken.contains("approximately"), "Expected 'approximately' for ≈ in: \(spoken)")
    }
    
    func testSymbolsMathSpeakRigorous() {
        let text = "Set relation: A ⊆ B, A ∪ B, A ∩ B, ∀ x, ∃ y, x ∈ S, ∂f, ∇g, x ≈ y."
        let spoken = engine.normalizeMath(text, style: .mathSpeakRigorous)
        XCTAssertTrue(spoken.contains("subset of or equal to"), "Expected 'subset of or equal to' for ⊆ in: \(spoken)")
        XCTAssertTrue(spoken.contains("set union"), "Expected 'set union' for ∪ in: \(spoken)")
        XCTAssertTrue(spoken.contains("set intersection"), "Expected 'set intersection' for ∩ in: \(spoken)")
        XCTAssertTrue(spoken.contains("universal quantifier, for all"), "Expected universal quantifier for ∀ in: \(spoken)")
        XCTAssertTrue(spoken.contains("existential quantifier, there exists"), "Expected existential quantifier for ∃ in: \(spoken)")
        XCTAssertTrue(spoken.contains("element of"), "Expected 'element of' for ∈ in: \(spoken)")
        XCTAssertTrue(spoken.contains("partial derivative"), "Expected 'partial derivative' for ∂ in: \(spoken)")
        XCTAssertTrue(spoken.contains("nabla"), "Expected 'nabla' for ∇ in: \(spoken)")
        XCTAssertTrue(spoken.contains("almost equal to"), "Expected 'almost equal to' for ≈ in: \(spoken)")
    }
    
    // MARK: - 4. LaTeX Macros
    
    func testLatexMacrosConversational() {
        let frac = "The probability is \\frac{1}{2} and \\frac{x + y}{z}."
        let spokenFrac = engine.translateLatexMacros(frac, style: .conversational)
        XCTAssertTrue(spokenFrac.contains("1 over 2"), "Expected '1 over 2' in: \(spokenFrac)")
        XCTAssertTrue(spokenFrac.contains("x + y over z"), "Expected 'x + y over z' in: \(spokenFrac)")
        
        let sqrt = "We compute \\sqrt{x} and \\sqrt[3]{8}."
        let spokenSqrt = engine.translateLatexMacros(sqrt, style: .conversational)
        XCTAssertTrue(spokenSqrt.contains("square root of x"), "Expected 'square root of x' in: \(spokenSqrt)")
        XCTAssertTrue(spokenSqrt.contains("root of 8"), "Expected root in: \(spokenSqrt)")
        
        let sum = "\\sum_{i=1}^{n} x_i"
        let spokenSum = engine.translateLatexMacros(sum, style: .conversational)
        XCTAssertTrue(spokenSum.contains("sum from i=1 to n of"), "Expected sum from i=1 to n in: \(spokenSum)")
        
        let bold = "Vector \\mathbf{w}."
        let spokenBold = engine.translateLatexMacros(bold, style: .conversational)
        XCTAssertTrue(spokenBold.contains("bold w"), "Expected 'bold w' in: \(spokenBold)")
    }
    
    func testLatexMacrosMathSpeakRigorous() {
        let frac = "Evaluate \\frac{1}{2}."
        let spokenFrac = engine.translateLatexMacros(frac, style: .mathSpeakRigorous)
        XCTAssertTrue(spokenFrac.contains("start fraction, 1, divided by, 2, end fraction"), "Expected MathSpeak fraction in: \(spokenFrac)")
        
        let sqrt = "Evaluate \\sqrt{x}."
        let spokenSqrt = engine.translateLatexMacros(sqrt, style: .mathSpeakRigorous)
        XCTAssertTrue(spokenSqrt.contains("start square root, x, end square root"), "Expected MathSpeak sqrt in: \(spokenSqrt)")
        
        let bb = "Set \\mathbb{R}."
        let spokenBb = engine.translateLatexMacros(bb, style: .mathSpeakRigorous)
        XCTAssertTrue(spokenBb.contains("blackboard bold R"), "Expected blackboard bold R in: \(spokenBb)")
    }
    
    // MARK: - 5. Mathematical Functions & Limits
    
    func testFunctionsAndLimits() {
        let funcs = "Calculate sin(x) + cos(y) - ln(z) + det(A)."
        let spokenFuncs = engine.vocalizeFunctions(funcs, style: .conversational)
        XCTAssertTrue(spokenFuncs.contains("sine of (x)"), "Expected sine of in: \(spokenFuncs)")
        XCTAssertTrue(spokenFuncs.contains("cosine of (y)"), "Expected cosine of in: \(spokenFuncs)")
        XCTAssertTrue(spokenFuncs.contains("natural log of (z)"), "Expected natural log of in: \(spokenFuncs)")
        XCTAssertTrue(spokenFuncs.contains("determinant of (A)"), "Expected determinant of in: \(spokenFuncs)")
        
        let lim = "The limit is lim_{x -> 0} f(x)."
        let spokenLim = engine.vocalizeFunctions(lim, style: .conversational)
        XCTAssertTrue(spokenLim.contains("limit as x approaches 0 of"), "Expected limit in: \(spokenLim)")
    }
    
    // MARK: - 6. Greek Alphabet
    
    func testGreekAlphabetStyles() {
        let letters = "Parameters: α, β, Δ, and Ω."
        
        let conversational = engine.vocalizeGreek(letters, style: .conversational)
        XCTAssertTrue(conversational.contains("alpha"), "Expected alpha in: \(conversational)")
        XCTAssertTrue(conversational.contains("beta"), "Expected beta in: \(conversational)")
        XCTAssertTrue(conversational.contains("Delta"), "Expected Delta in: \(conversational)")
        XCTAssertTrue(conversational.contains("Omega"), "Expected Omega in: \(conversational)")
        
        let rigorous = engine.vocalizeGreek(letters, style: .mathSpeakRigorous)
        XCTAssertTrue(rigorous.contains("alpha"), "Expected alpha in: \(rigorous)")
        XCTAssertTrue(rigorous.contains("capital Delta"), "Expected capital Delta in: \(rigorous)")
        XCTAssertTrue(rigorous.contains("capital Omega"), "Expected capital Omega in: \(rigorous)")
    }
    
    // MARK: - 7. End-to-End Normalizer and User Overrides
    
    func testTextNormalizerIntegrationWithStyle() {
        let equation = "Suppose \\frac{a}{b} = 1.5e3 with frequency 100 MHz for α ∈ S."
        
        let spokenConv = normalizer.normalizeForSpeech(equation, mathStyle: .conversational)
        XCTAssertTrue(spokenConv.contains("a over b"), "Expected 'a over b' in: \(spokenConv)")
        XCTAssertTrue(spokenConv.contains("1.5 times ten cubed") || spokenConv.contains("1.5 times ten to the third"), "Expected 1.5e3 in: \(spokenConv)")
        XCTAssertTrue(spokenConv.contains("100 megahertz"), "Expected 100 megahertz in: \(spokenConv)")
        XCTAssertTrue(spokenConv.contains("alpha in S"), "Expected 'alpha in S' in: \(spokenConv)")
        
        let spokenRig = normalizer.normalizeForSpeech(equation, mathStyle: .mathSpeakRigorous)
        XCTAssertTrue(spokenRig.contains("start fraction, a, divided by, b, end fraction"), "Expected MathSpeak fraction in: \(spokenRig)")
        XCTAssertTrue(spokenRig.contains("element of"), "Expected 'element of' in: \(spokenRig)")
    }
    
    func testUserPronunciationOverrideTakesPrecedence() {
        let input = "The symbol α is used."
        
        // Add user override for alpha
        let customRule = PronunciationRule(match: "alpha", spokenText: "AL-fuh-star", scope: .user)
        PronunciationManager.shared.addRule(customRule)
        defer {
            PronunciationManager.shared.removeRule(id: customRule.id)
        }
        
        let normalized = normalizer.normalizeForSpeech(input)
        let finalSpoken = PronunciationManager.shared.applyPronunciations(to: normalized)
        XCTAssertTrue(finalSpoken.contains("AL-fuh-star"), "Expected user override to take precedence in: \(finalSpoken)")
    }
    
    // MARK: - 8. Linear Algebra Equations & Subscripts
    
    func testLinearAlgebraEquationVocalization() {
        let eq = "a11x1 +···+ a1nxn= b1"
        
        // Conversational style
        let spokenConv = normalizer.normalizeForSpeech(eq, mathStyle: .conversational)
        XCTAssertTrue(spokenConv.contains("a 1 1, x 1"), "Expected 'a 1 1, x 1' in: \(spokenConv)")
        XCTAssertTrue(spokenConv.contains("plus and so on, plus"), "Expected 'plus and so on, plus' in: \(spokenConv)")
        XCTAssertTrue(spokenConv.contains("a 1 n, x n"), "Expected 'a 1 n, x n' in: \(spokenConv)")
        XCTAssertTrue(spokenConv.contains("equals"), "Expected 'equals' in: \(spokenConv)")
        XCTAssertTrue(spokenConv.contains("b 1"), "Expected 'b 1' in: \(spokenConv)")
        
        // MathSpeak Rigorous style
        let spokenRig = normalizer.normalizeForSpeech(eq, mathStyle: .mathSpeakRigorous)
        XCTAssertTrue(spokenRig.contains("a sub 1 1, x sub 1"), "Expected 'a sub 1 1, x sub 1' in: \(spokenRig)")
        XCTAssertTrue(spokenRig.contains("plus ellipsis, plus"), "Expected 'plus ellipsis, plus' in: \(spokenRig)")
        XCTAssertTrue(spokenRig.contains("a sub 1 n, x sub n"), "Expected 'a sub 1 n, x sub n' in: \(spokenRig)")
        XCTAssertTrue(spokenRig.contains("equals"), "Expected 'equals' in: \(spokenRig)")
        XCTAssertTrue(spokenRig.contains("b sub 1"), "Expected 'b sub 1' in: \(spokenRig)")
    }
    
    func testMultiIndexAndSubscriptVariables() {
        // Double indices, fused variables, and sequences
        let text1 = "Consider am1x1 + ··· + amn xn = bm."
        let spoken1 = normalizer.normalizeForSpeech(text1, mathStyle: .conversational)
        XCTAssertTrue(spoken1.contains("a m 1, x 1"), "Expected 'a m 1, x 1' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("a m n, x n"), "Expected 'a m n, x n' in: \(spoken1)")
        XCTAssertTrue(spoken1.contains("b m"), "Expected 'b m' in: \(spoken1)")
        
        // Sequences with ellipsis: x1,...,xn and R1,..., R m
        let text2 = "Variables x1,...,xn and resources R1,..., R m."
        let spoken2 = normalizer.normalizeForSpeech(text2, mathStyle: .conversational)
        XCTAssertTrue(spoken2.contains("x 1 through x n"), "Expected 'x 1 through x n' in: \(spoken2)")
        XCTAssertTrue(spoken2.contains("R 1 through R m"), "Expected 'R 1 through R m' in: \(spoken2)")
        
        // Single subscript variables: xj, bi
        let text3 = "Determine xj of product j with cost bi."
        let spoken3 = normalizer.normalizeForSpeech(text3, mathStyle: .conversational)
        XCTAssertTrue(spoken3.contains("x j"), "Expected 'x j' in: \(spoken3)")
        XCTAssertTrue(spoken3.contains("b i"), "Expected 'b i' in: \(spoken3)")
    }
}
