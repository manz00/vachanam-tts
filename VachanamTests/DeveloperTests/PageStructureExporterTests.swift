//
//  PageStructureExporterTests.swift
//  VachanamTests
//
//  Unit and integration tests for DeveloperModeManager, PageStructureExporter,
//  and JSON round-trip serialization.
//

import XCTest
import Foundation
import PDFKit
import KokoroTTS
@testable import Vachanam

@MainActor
final class PageStructureExporterTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testDeveloperModeManagerToggleAndPersistence() {
        let manager = DeveloperModeManager.shared
        let originalState = manager.isDeveloperModeEnabled
        
        manager.toggle()
        XCTAssertEqual(manager.isDeveloperModeEnabled, !originalState)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "vachanam_developer_mode_enabled"), !originalState)
        
        manager.toggle()
        XCTAssertEqual(manager.isDeveloperModeEnabled, originalState)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "vachanam_developer_mode_enabled"), originalState)
    }
    
    func testPageStructureExportWithBenchmarkDocument() {
        let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
        guard let doc = ReaderDocument(url: benchmarkURL) else {
            XCTFail("Failed to initialize ReaderDocument for Benchmark")
            return
        }
        
        // Parse semantics synchronously with SentenceSegmenter
        let semDoc = SentenceSegmenter.shared.parseDocument(pdfDocument: doc.pdfDocument, title: doc.title, documentID: doc.id)
        doc.semanticDocument = semDoc
        
        let export = PageStructureExporter.exportPage(pageIndex: 0, document: doc)
        
        XCTAssertEqual(export.documentTitle, doc.title)
        XCTAssertEqual(export.pageIndex, 0)
        XCTAssertEqual(export.pageNumber, 1)
        XCTAssertGreaterThan(export.pageWidth, 0)
        XCTAssertGreaterThan(export.pageHeight, 0)
        XCTAssertFalse(export.exportedAt.isEmpty)
        XCTAssertGreaterThan(export.totalSentencesOnPage, 0)
        XCTAssertGreaterThan(export.totalWordsOnPage, 0)
        
        // Verify JSON string generation
        let jsonString = PageStructureExporter.exportJSONString(from: export)
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertTrue(jsonString.contains("\"documentTitle\""))
        XCTAssertTrue(jsonString.contains("\"pageIndex\" : 0"))
        
        // Verify JSON round-trip deserialization
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Failed to convert JSON string to data")
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(PageStructureExport.self, from: data)
            XCTAssertEqual(decoded.documentTitle, export.documentTitle)
            XCTAssertEqual(decoded.pageIndex, export.pageIndex)
            XCTAssertEqual(decoded.totalSentencesOnPage, export.totalSentencesOnPage)
            XCTAssertEqual(decoded.sentences.count, export.sentences.count)
            XCTAssertEqual(decoded.blocks.count, export.blocks.count)
        } catch {
            XCTFail("JSON decoding failed: \(error)")
        }
    }
    
    func testExportParagraphDiagnosticsAndPhonemization() {
        let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
        guard let doc = ReaderDocument(url: benchmarkURL) else {
            XCTFail("Failed to initialize ReaderDocument for Benchmark")
            return
        }
        
        let semDoc = SentenceSegmenter.shared.parseDocument(pdfDocument: doc.pdfDocument, title: doc.title, documentID: doc.id)
        doc.semanticDocument = semDoc
        
        guard let firstSentence = semDoc.sentences.first else {
            XCTFail("Semantic document had no sentences")
            return
        }
        
        let paragraphExport = PageStructureExporter.exportParagraph(sentence: firstSentence, document: doc)
        
        XCTAssertEqual(paragraphExport.documentTitle, doc.title)
        XCTAssertEqual(paragraphExport.sentenceIDs, [firstSentence.sentenceID])
        XCTAssertFalse(paragraphExport.rawText.isEmpty)
        XCTAssertFalse(paragraphExport.normalizedSpeechText.isEmpty)
        XCTAssertFalse(paragraphExport.verbalizedText.isEmpty)
        XCTAssertNotNil(paragraphExport.diagnostics["characterCount"])
        XCTAssertNotNil(paragraphExport.diagnostics["wordCount"])
        XCTAssertNotNil(paragraphExport.diagnostics["blockType"])
        
        // Verify JSON round-trip
        let jsonString = PageStructureExporter.exportJSONString(from: paragraphExport)
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Failed to get UTF-8 data")
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(ParagraphExport.self, from: data)
            XCTAssertEqual(decoded.sentenceIDs, paragraphExport.sentenceIDs)
            XCTAssertEqual(decoded.rawText, paragraphExport.rawText)
            XCTAssertEqual(decoded.wordCount, paragraphExport.wordCount)
        } catch {
            XCTFail("Failed to decode ParagraphExport: \(error)")
        }
    }
    
    func testWriteTemporaryJSONFile() {
        let sampleJSON = "{\"testKey\": \"testValue\"}"
        let tempURL = PageStructureExporter.writeTemporaryJSONFile(
            filename: "test_export_diag.json",
            jsonString: sampleJSON
        )
        
        XCTAssertNotNil(tempURL)
        guard let url = tempURL else { return }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try? String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, sampleJSON)
        
        try? FileManager.default.removeItem(at: url)
    }
    
    func testPhysicsConstantsSpeechNormalizationAndVerbalization() {
        let input = """
        • Planck's Constant: h ≈ 6.626 × 10⁻³⁴ J·s (ħ ≈ 1.055 × 10⁻³⁴ J·s)
        • Boltzmann's Constant: k_B ≈ 1.381 × 10⁻²³ J/K
        • Stefan-Boltzmann Constant: σ ≈ 5.670 × 10⁻⁸ W·m⁻²·K⁻⁴
        • Vacuum Permittivity: ε₀ ≈ 8.854 × 10⁻¹² F/m
        • Avogadro's Constant: N_A ≈ 6.022 × 10²³ mol⁻
        """
        
        let normalized = TextNormalizer.shared.normalizeForSpeech(input)
        
        // Assert symbols and units are translated naturally
        XCTAssertFalse(normalized.contains("cross"), "× before 10 should be verbalized as 'times', never 'cross'")
        XCTAssertTrue(normalized.contains("Joule seconds"), "J·s should be verbalized as Joule seconds")
        XCTAssertTrue(normalized.contains("Joules per Kelvin"), "J/K should be verbalized as Joules per Kelvin")
        XCTAssertTrue(normalized.contains("Watts per square meter per Kelvin to the fourth"), "W·m⁻²·K⁻⁴ should be verbalized cleanly")
        XCTAssertTrue(normalized.contains("Farads per meter"), "F/m should be verbalized as Farads per meter")
        XCTAssertTrue(normalized.contains("per mole"), "mol⁻ should be verbalized as per mole")
        XCTAssertTrue(normalized.contains("h bar"), "ħ should be verbalized as h bar")
        XCTAssertTrue(normalized.contains("sigma"), "σ should be verbalized as sigma")
        XCTAssertTrue(normalized.contains("epsilon"), "ε should be verbalized as epsilon")
        XCTAssertFalse(normalized.contains("squared cubed"), "10²³ must never be split into squared cubed")
        XCTAssertFalse(normalized.contains("inverse squared"), "10⁻¹² must never be split into inverse squared")
        
        // Verbalize numbers for Kokoro G2P
        let verbalized = KokoroMisakiPhonemizer.verbalizeNumbers(in: normalized)
        XCTAssertFalse(verbalized.contains("10⁻³⁴"))
        XCTAssertFalse(verbalized.contains("10⁻²³"))
        XCTAssertFalse(verbalized.contains("10⁻⁸"))
        XCTAssertFalse(verbalized.contains("10⁻¹²"))
        XCTAssertFalse(verbalized.contains("10²³"))
        XCTAssertTrue(verbalized.contains("six point six two six"))
        XCTAssertTrue(verbalized.contains("one point zero five five"))
        XCTAssertTrue(verbalized.contains("one point three eight one"))
        XCTAssertTrue(verbalized.contains("five point six seven zero"))
        XCTAssertTrue(verbalized.contains("eight point eight five four"))
        XCTAssertTrue(verbalized.contains("six point zero two two"))
        XCTAssertFalse(verbalized.contains("⁻"), "No residual superscript minus symbols should remain")
    }
}
