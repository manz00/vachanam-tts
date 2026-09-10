//
//  MultiDisciplineTTSBenchmarkTests.swift
//  VachanamTests
//
//  Comprehensive automated test suite for The Ultimate Multi-Discipline TTS Benchmark:
//  validates PDF document extraction, dialogue prosody, explicit LaTeX matrices,
//  linear algebra equations, SI units, and academic citations.
//

import XCTest
import PDFKit
@testable import Vachanam

final class MultiDisciplineTTSBenchmarkTests: XCTestCase {
    
    let normalizer = TextNormalizer.shared
    let engine = MathSpeechEngine.shared
    
    // MARK: - Benchmark PDF Document Integrity
    
    func testBenchmarkPDFDocumentExistsAndExtractsText() {
        let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
        XCTAssertTrue(FileManager.default.fileExists(atPath: benchmarkURL.path), "Benchmark PDF must exist on disk")
        
        guard let pdf = PDFDocument(url: benchmarkURL) else {
            XCTFail("Failed to load Benchmark PDF via PDFKit")
            return
        }
        
        XCTAssertEqual(pdf.pageCount, 4, "Expected exactly 4 pages in the Benchmark PDF")
        
        // Page 1: Overview & Section 1: The Novel
        let page1 = pdf.page(at: 0)?.string ?? ""
        XCTAssertTrue(page1.contains("The Ultimate Multi-Discipline TTS Benchmark"))
        XCTAssertTrue(page1.contains("Section 1: The Novel"))
        XCTAssertTrue(page1.contains("Detective Clara Vance"))
        XCTAssertTrue(page1.contains("Dr. Alistair"))
        
        // Page 2: Section 2: Pure Mathematics & Formal Notation
        let page2 = pdf.page(at: 1)?.string ?? ""
        XCTAssertTrue(page2.contains("Section 2: Pure Mathematics & Formal Notation"))
        XCTAssertTrue(page2.contains("Part A: Linear Systems"))
        XCTAssertTrue(page2.contains("Part B: Explicit Matrices"))
        XCTAssertTrue(page2.contains("det(A)"))
        XCTAssertTrue(page2.contains("Singular Value Decomposition"))
        
        // Page 3: Section 3: Empirical Science, SI Units & Measurements
        let page3 = pdf.page(at: 2)?.string ?? ""
        XCTAssertTrue(page3.contains("Section 3: Empirical Science"))
        XCTAssertTrue(page3.contains("Planck's Constant"))
        XCTAssertTrue(page3.contains("14,000"))
        
        // Page 4: Section 4: Academic Prose, Citations & Normalization
        let page4 = pdf.page(at: 3)?.string ?? ""
        XCTAssertTrue(page4.contains("Section 4: Academic Prose"))
        XCTAssertTrue(page4.contains("Vaswani et al."))
        XCTAssertTrue(page4.contains("doi:10.1000/182"))
    }
    
    // MARK: - Section 1: Novel Dialogue, Punctuation & Prosody
    
    func testSection1NovelProsodyAndHonorifics() {
        let novelSnippet = """
        "He didn't just leave, Vance," Dr. Alistair whispered, his voice catching on the threshold of an apology. "He vanished—clean into thin air! At precisely 11:45 p.m., no less."
        "Is that so?" Clara arched an eyebrow, leaning forward into the lamplight. "Then tell me, Alistair... why did the night porter find his spectacles—still warm—on the side table?"
        A sudden, sharp crash echoed from the conservatory downstairs. Crash!
        "Halt!" shouted Inspector Kensington. "Drop the ledger!"
        """
        
        let normalized = normalizer.normalizeForSpeech(novelSnippet)
        
        // Verify title expansion prevents awkward sentence splitting
        XCTAssertTrue(normalized.contains("Doctor Alistair"), "Expected 'Dr.' to expand to 'Doctor' before name: \(normalized)")
        XCTAssertTrue(normalized.contains("Inspector Kensington"), "Expected Inspector Kensington preserved: \(normalized)")
        
        // Verify dashes are converted to commas for smooth clause cadence
        XCTAssertTrue(normalized.contains("vanished, clean into thin air"), "Expected em-dash clause to convert to natural pause: \(normalized)")
        XCTAssertTrue(normalized.contains("spectacles, still warm, on the side table"), "Expected parenthetical em-dashes to convert to pauses: \(normalized)")
        
        // Verify contractions and exclamation interjections preserved
        XCTAssertTrue(normalized.contains("didn't"), "Expected contraction didn't preserved: \(normalized)")
        XCTAssertTrue(normalized.contains("Crash!"), "Expected interjection Crash! preserved: \(normalized)")
    }
    
    // MARK: - Section 2: Explicit Matrices & Advanced Linear Algebra
    
    func testExplicitMatrixVocalizationConversational() {
        let matrix2x2 = """
        Let A = \\begin{bmatrix} 3 & -1 \\\\ 2 & 4 \\end{bmatrix} and Q = \\begin{pmatrix} 1 & 0 \\\\ 0 & 1 \\end{pmatrix}.
        """
        let spoken = normalizer.normalizeForSpeech(matrix2x2, mathStyle: .conversational)
        XCTAssertTrue(spoken.contains("2 by 2 matrix:"), "Expected '2 by 2 matrix:' in: \(spoken)")
        XCTAssertTrue(spoken.contains("row 1: 3, -1"), "Expected row 1 elements in: \(spoken)")
        XCTAssertTrue(spoken.contains("row 2: 2, 4"), "Expected row 2 elements in: \(spoken)")
    }
    
    func testDeterminantVocalization() {
        let detInput = """
        Evaluate \\det(A) = \\begin{vmatrix} 3 & -1 \\\\ 2 & 4 \\end{vmatrix} = 14.
        """
        let spoken = normalizer.normalizeForSpeech(detInput, mathStyle: .conversational)
        XCTAssertTrue(spoken.contains("determinant of 2 by 2 matrix:"), "Expected determinant speech in: \(spoken)")
        XCTAssertTrue(spoken.contains("row 1: 3, -1"), "Expected row 1 in: \(spoken)")
        XCTAssertTrue(spoken.contains("row 2: 2, 4"), "Expected row 2 in: \(spoken)")
    }
    
    func testColumnVectorVocalization() {
        let vectorInput = """
        Consider column vector \\vec{x} = \\begin{bmatrix} x_1 \\\\ x_2 \\\\ x_3 \\end{bmatrix}.
        """
        let spoken = normalizer.normalizeForSpeech(vectorInput, mathStyle: .conversational)
        XCTAssertTrue(spoken.contains("column vector with elements:"), "Expected column vector in: \(spoken)")
        XCTAssertTrue(spoken.contains("vector x"), "Expected 'vector x' for \\vec{x} in: \(spoken)")
    }
    
    func testAdvancedLinearAlgebraOperatorsAndNorms() {
        let input = """
        Let \\mathbf{A} \\in \\mathbb{R}^{m \\times n} satisfy \\mathbf{A}\\vec{v}_i = \\lambda_i \\vec{v}_i with SVD \\mathbf{A} = \\mathbf{U} \\mathbf{\\Sigma} \\mathbf{V}^T.
        We compute \\mathrm{tr}(\\mathbf{A}), tensor product \\mathbf{A} \\otimes \\mathbf{B}, and direct sum \\mathbf{V} \\oplus \\mathbf{W}.
        Estimator satisfies \\hat{x} = \\arg\\min_{\\vec{x}} \\Vert{} A\\vec{x} - \\vec{b} \\Vert{}_2^2 + \\lambda \\Vert{}\\vec{x}\\Vert{}_1.
        """
        
        let spoken = normalizer.normalizeForSpeech(input, mathStyle: .conversational)
        XCTAssertTrue(spoken.contains("bold A"), "Expected bold A in: \(spoken)")
        XCTAssertTrue(spoken.contains("R m by n"), "Expected R m by n in: \(spoken)")
        XCTAssertTrue(spoken.contains("lambda"), "Expected lambda in: \(spoken)")
        XCTAssertTrue(spoken.contains("transpose"), "Expected transpose in: \(spoken)")
        XCTAssertTrue(spoken.contains("trace of"), "Expected trace of in: \(spoken)")
        XCTAssertTrue(spoken.contains("tensor product"), "Expected tensor product in: \(spoken)")
        XCTAssertTrue(spoken.contains("direct sum"), "Expected direct sum in: \(spoken)")
        XCTAssertTrue(spoken.contains("x hat"), "Expected x hat for \\hat{x} in: \(spoken)")
        XCTAssertTrue(spoken.contains("argument minimum"), "Expected argument minimum in: \(spoken)")
        XCTAssertTrue(spoken.contains("L 2 norm"), "Expected L 2 norm in: \(spoken)")
        XCTAssertTrue(spoken.contains("L 1 norm"), "Expected L 1 norm in: \(spoken)")
    }
    
    // MARK: - Section 3: Empirical Science, SI Units & Measurements
    
    func testScientificNotationAndComplexSIUnits() {
        let input = """
        Conditions: 21.5^\\circ\\text{C} (70.7^\\circ\\text{F}) under 101.3\\text{ kPa}.
        Avogadro: N_A \\approx 6.022 \\times 10^{23}\\text{ mol}^{-1}.
        Charge: e = 1.602 \\times 10^{-19}\\text{ C}.
        Speed: c = 3.0 \\times 10^8\\text{ m/s}.
        Gravity: g \\approx 9.8\\text{ m/s}^2.
        Ultracentrifuge spun at 14,000\\text{ rpm} for 45\\text{ min}, precipitating 250\\text{ mg} into 15.5\\text{ mL}.
        RF was 2.4\\text{ GHz} with leakage below 500\\text{ mA} at 12\\text{ V}.
        Shifts measured 5\\text{ nm} to 12\\text{ nm} across 100\\text{ ms}.
        """
        
        let spoken = normalizer.normalizeForSpeech(input, mathStyle: .conversational)
        XCTAssertTrue(spoken.contains("21.5 degrees Celsius"), "Expected degrees Celsius in: \(spoken)")
        XCTAssertTrue(spoken.contains("70.7 degrees Fahrenheit"), "Expected degrees Fahrenheit in: \(spoken)")
        XCTAssertTrue(spoken.contains("101.3 kilopascals"), "Expected kilopascals in: \(spoken)")
        XCTAssertTrue(spoken.contains("per mole"), "Expected per mole in: \(spoken)")
        XCTAssertTrue(spoken.contains("coulombs"), "Expected coulombs in: \(spoken)")
        XCTAssertTrue(spoken.contains("meters per second"), "Expected meters per second in: \(spoken)")
        XCTAssertTrue(spoken.contains("meters per second squared"), "Expected meters per second squared in: \(spoken)")
        XCTAssertTrue(spoken.contains("14,000 revolutions per minute"), "Expected revolutions per minute in: \(spoken)")
        XCTAssertTrue(spoken.contains("45 minutes"), "Expected minutes in: \(spoken)")
        XCTAssertTrue(spoken.contains("250 milligrams"), "Expected milligrams in: \(spoken)")
        XCTAssertTrue(spoken.contains("15.5 milliliters"), "Expected milliliters in: \(spoken)")
        XCTAssertTrue(spoken.contains("2.4 gigahertz"), "Expected gigahertz in: \(spoken)")
        XCTAssertTrue(spoken.contains("500 milliamperes"), "Expected milliamperes in: \(spoken)")
        XCTAssertTrue(spoken.contains("12 volts"), "Expected volts in: \(spoken)")
        XCTAssertTrue(spoken.contains("5 nanometers to 12 nanometers"), "Expected nanometers in: \(spoken)")
        XCTAssertTrue(spoken.contains("100 milliseconds"), "Expected milliseconds in: \(spoken)")
    }
    
    // MARK: - Section 4: Academic Prose, Citations & Normalization
    
    func testAcademicCitationsStatisticsAndCurrencies() {
        let input = """
        Recent breakthroughs (e.g., Vaswani et al., 2017; see also Radford & colleagues, ca. 2022) are noted in ibid., p. 145, and op. cit., cf. Section 2.1 (§ 2.1, ¶ 3).
        Documentation at https://arxiv.org/abs/1706.03762 or doi:10.1000/182.
        Cohort showed significant improvements (p < 0.001, two-tailed t-test):
        Trial A yielded +14.8\\% over baseline (n = 1,200).
        Trial B showed -3.2\\text{ dB} spectral distortion.
        Equipment fees totaled $4,500, €3,200, £1,850, ¥250,000, and ₹75,000 respectively.
        Approximately \\frac{3}{4} passed screening (\\pm 0.05\\% variance).
        """
        
        let spoken = normalizer.normalizeForSpeech(input, mathStyle: .conversational)
        
        // Citations and Latin abbreviations
        XCTAssertTrue(spoken.contains("for example"), "Expected e.g. expanded in: \(spoken)")
        XCTAssertTrue(spoken.contains("and colleagues"), "Expected et al. expanded in: \(spoken)")
        XCTAssertTrue(spoken.contains("circa 2022"), "Expected ca. 2022 expanded in: \(spoken)")
        XCTAssertTrue(spoken.contains("in the same place"), "Expected ibid. expanded in: \(spoken)")
        XCTAssertTrue(spoken.contains("in the work cited"), "Expected op. cit. expanded in: \(spoken)")
        XCTAssertTrue(spoken.contains("compare with"), "Expected cf. expanded in: \(spoken)")
        XCTAssertTrue(spoken.contains("section 2.1"), "Expected § 2.1 expanded in: \(spoken)")
        XCTAssertTrue(spoken.contains("paragraph 3"), "Expected ¶ 3 expanded in: \(spoken)")
        
        // Links
        XCTAssertTrue(spoken.contains("link to arxiv.org"), "Expected link to arxiv.org in: \(spoken)")
        XCTAssertTrue(spoken.contains("publication link"), "Expected publication link for DOI in: \(spoken)")
        
        // Statistical numbers and units
        XCTAssertTrue(spoken.contains("+14.8 percent") || spoken.contains("plus 14.8 percent"), "Expected percent in: \(spoken)")
        XCTAssertTrue(spoken.contains("-3.2 decibels") || spoken.contains("minus 3.2 decibels"), "Expected decibels in: \(spoken)")
        
        // Currencies with commas
        XCTAssertTrue(spoken.contains("4,500 dollars"), "Expected 4,500 dollars in: \(spoken)")
        XCTAssertTrue(spoken.contains("3,200 euros"), "Expected 3,200 euros in: \(spoken)")
        XCTAssertTrue(spoken.contains("1,850 pounds"), "Expected 1,850 pounds in: \(spoken)")
        XCTAssertTrue(spoken.contains("250,000 yen"), "Expected 250,000 yen in: \(spoken)")
        XCTAssertTrue(spoken.contains("75,000 rupees"), "Expected 75,000 rupees in: \(spoken)")
        
        // Fractions
        XCTAssertTrue(spoken.contains("3 over 4"), "Expected 3 over 4 in: \(spoken)")
        XCTAssertTrue(spoken.contains("plus or minus 0.05 percent"), "Expected plus or minus in: \(spoken)")
    }
}
