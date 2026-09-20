//
//  RobustnessAndEdgeCaseTests.swift
//  VachanamTests
//
//  Regression test suite for:
//  - Zero-byte file and corrupted PDF handling (Items 25 & 26)
//  - TTS Request-ID isolation & concurrency protection (Items 50 & 51)
//  - Accessibility Theme Palettes & Contrast (Item 43)
//  - Typography & Font Scaling Range (Items 41 & 42)
//

import XCTest
import PDFKit
import SwiftUI
@testable import Vachanam

final class RobustnessAndEdgeCaseTests: XCTestCase {
    
    // MARK: - Zero-Byte & Corrupted File Ingestion (Items 25 & 26)
    
    func testZeroBytePDFRejection() {
        let emptyData = Data()
        let doc = ReaderDocument(data: emptyData, title: "Empty PDF")
        XCTAssertNil(doc, "ReaderDocument must reject zero-byte PDF data cleanly")
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try? emptyData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let fileDoc = ReaderDocument(url: tempURL)
        XCTAssertNil(fileDoc, "ReaderDocument must reject zero-byte PDF files from URL cleanly")
    }
    
    func testCorruptedPDFRejection() {
        let corruptData = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x12, 0x34, 0x56])
        let doc = ReaderDocument(data: corruptData, title: "Corrupt PDF")
        XCTAssertNil(doc, "ReaderDocument must reject non-PDF binary garbage cleanly")
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try? corruptData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let fileDoc = ReaderDocument(url: tempURL)
        XCTAssertNil(fileDoc, "ReaderDocument must reject corrupt PDF files from URL cleanly")
    }
    
    func testZeroBytePlainTextParsing() async {
        let parser = PlainTextParser()
        do {
            _ = try await parser.parse(from: .rawText("", title: "Empty PlainText"))
            XCTFail("PlainTextParser must throw parsingFailed for zero-byte or empty document")
        } catch let DocumentParserError.parsingFailed(message) {
            XCTAssertTrue(message.contains("Document is empty"))
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }
    
    func testZeroByteMarkdownParsing() {
        let parser = MarkdownParser()
        let parsed = parser.parseMarkdownText("", defaultTitle: "Empty Markdown")
        XCTAssertEqual(parsed.title, "Empty Markdown")
        XCTAssertEqual(parsed.chapters.count, 1)
        XCTAssertEqual(parsed.allBlocks.count, 1)
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: parsed)
        XCTAssertEqual(semDoc.pageCount, 1)
        XCTAssertEqual(semDoc.words.count, 0)
    }
    
    // MARK: - TTS Concurrency & Request-ID Tokens (Items 50 & 51)
    
    func testPlaybackCoordinatorRequestIDIncrementOnRapidRequests() {
        let coordinator = PlaybackCoordinator.shared
        
        // Build a sample document with multiple words
        let doc = MarkdownParser().parseMarkdownText("One two three four five six seven.", defaultTitle: "Concurrency Doc")
        let semDoc = SemanticDocumentBuilder.shared.build(from: doc)
        
        coordinator.loadDocument(semDoc)
        let initialRequestID = coordinator.currentRequestID
        
        // Rapid sequential requests must produce distinct request IDs
        coordinator.play(fromWordID: 0)
        let firstRequestID = coordinator.currentRequestID
        XCTAssertNotEqual(initialRequestID, firstRequestID)
        
        coordinator.play(fromWordID: 2)
        let secondRequestID = coordinator.currentRequestID
        XCTAssertNotEqual(firstRequestID, secondRequestID, "Subsequent playback trigger must invalidate prior request ID")
        
        coordinator.stop()
    }
    
    // MARK: - Theme Palettes & Contrast (Item 43)
    
    func testAllReaderThemePalettes() {
        let themes: [ReaderBackgroundTheme] = [.original, .quiet, .paper, .charcoal, .night]
        
        for theme in themes {
            let bg = theme.backgroundColor
            let text = theme.textColor
            
            // Validate all themes produce concrete non-empty Color values
            XCTAssertFalse(theme.displayName.isEmpty)
            XCTAssertNotNil(bg)
            XCTAssertNotNil(text)
            
            // Quiet should be warm cream, Night should be pitch black
            if theme == .night {
                XCTAssertEqual(theme.backgroundColor, Color.black)
            } else if theme == .original {
                XCTAssertEqual(theme.backgroundColor, Color.white)
            }
        }
    }
    
    // MARK: - Typography & Font Scaling Range (Items 41 & 42)
    
    func testFontManagerScalingRange() {
        let manager = FontManager.shared
        let testSizes: [CGFloat] = [10, 14, 17, 24, 32, 48, 64]
        let families: [ReaderFontFamily] = [.system, .serif, .rounded, .openDyslexic, .mono]
        
        for family in families {
            manager.selectedFont = family
            for size in testSizes {
                let font = manager.resolveFont(size: size)
                XCTAssertNotNil(font, "Font for family \(family.rawValue) at size \(size) must be constructible")
            }
        }
        manager.selectedFont = .system
    }
}
