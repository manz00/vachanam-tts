//
//  AdversarialParserTests.swift
//  VachanamTests
//
//  Tests verifying AUD-24 adversarial input robustness:
//  - Malformed EPUB archives (missing container, missing OPF, empty spine)
//  - Deeply nested HTML structures & SVG security
//  - Extremely long paragraphs (100,000 chars) and giant tokens (50,000 chars)
//

import XCTest
@testable import Vachanam

final class AdversarialParserTests: XCTestCase {
    
    // MARK: - Helper to Build Raw ZIP Archives
    
    private func buildZipArchive(files: [(name: String, content: String)]) -> Data {
        var body = Data()
        var centralDirectory = Data()
        var offset = 0
        
        for file in files {
            let nameBytes = Array(file.name.utf8)
            let contentBytes = Array(file.content.utf8)
            
            // Local File Header (30 bytes)
            var localHeader = Data()
            localHeader.appendUInt32(0x04034b50)
            localHeader.appendUInt16(20)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0) // Stored (no compression)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt32(0) // CRC32 placeholder
            localHeader.appendUInt32(UInt32(contentBytes.count))
            localHeader.appendUInt32(UInt32(contentBytes.count))
            localHeader.appendUInt16(UInt16(nameBytes.count))
            localHeader.appendUInt16(0)
            localHeader.append(contentsOf: nameBytes)
            localHeader.append(contentsOf: contentBytes)
            
            body.append(localHeader)
            
            // Central Directory Entry (46 bytes)
            var cdEntry = Data()
            cdEntry.appendUInt32(0x02014b50)
            cdEntry.appendUInt16(20)
            cdEntry.appendUInt16(20)
            cdEntry.appendUInt16(0)
            cdEntry.appendUInt16(0)
            cdEntry.appendUInt16(0)
            cdEntry.appendUInt16(0)
            cdEntry.appendUInt32(0)
            cdEntry.appendUInt32(UInt32(contentBytes.count))
            cdEntry.appendUInt32(UInt32(contentBytes.count))
            cdEntry.appendUInt16(UInt16(nameBytes.count))
            cdEntry.appendUInt16(0)
            cdEntry.appendUInt16(0)
            cdEntry.appendUInt16(0)
            cdEntry.appendUInt16(0)
            cdEntry.appendUInt32(0)
            cdEntry.appendUInt32(UInt32(offset))
            cdEntry.append(contentsOf: nameBytes)
            
            centralDirectory.append(cdEntry)
            offset += localHeader.count
        }
        
        var eocd = Data()
        eocd.appendUInt32(0x06054b50)
        eocd.appendUInt16(0)
        eocd.appendUInt16(0)
        eocd.appendUInt16(UInt16(files.count))
        eocd.appendUInt16(UInt16(files.count))
        eocd.appendUInt32(UInt32(centralDirectory.count))
        eocd.appendUInt32(UInt32(body.count))
        eocd.appendUInt16(0)
        
        var archive = Data()
        archive.append(body)
        archive.append(centralDirectory)
        archive.append(eocd)
        return archive
    }
    
    // MARK: - Malformed EPUB Tests
    
    func testEPUBMissingContainerXML() async throws {
        let zipData = buildZipArchive(files: [
            ("mimetype", "application/epub+zip"),
            ("OEBPS/content.opf", "<package><metadata/><manifest/><spine/></package>")
        ])
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".epub")
        try zipData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let parser = EPUBParser()
        do {
            _ = try await parser.parse(from: .fileURL(tempURL))
            XCTFail("Should throw when container.xml is missing")
        } catch {
            guard let parserError = error as? DocumentParserError else {
                XCTFail("Expected DocumentParserError, got \(error)")
                return
            }
            if case .parsingFailed(let msg) = parserError {
                XCTAssertTrue(msg.contains("container.xml"))
            } else {
                XCTFail("Expected parsingFailed error")
            }
        }
    }
    
    func testEPUBMissingOPFPackage() async throws {
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/non_existent.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        let zipData = buildZipArchive(files: [
            ("mimetype", "application/epub+zip"),
            ("META-INF/container.xml", containerXML)
        ])
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".epub")
        try zipData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let parser = EPUBParser()
        do {
            _ = try await parser.parse(from: .fileURL(tempURL))
            XCTFail("Should throw when OPF file is missing")
        } catch {
            guard let parserError = error as? DocumentParserError else {
                XCTFail("Expected DocumentParserError, got \(error)")
                return
            }
            if case .parsingFailed(let msg) = parserError {
                XCTAssertTrue(msg.contains("Missing OPF"))
            } else {
                XCTFail("Expected parsingFailed error")
            }
        }
    }
    
    func testEPUBCircularOrInvalidSpineFallback() async throws {
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        // Spine references non-existent ID, but manifest contains a valid XHTML item
        let opfXML = """
        <package version="3.0" xmlns="http://www.idpf.org/2007/opf">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>Fallback Book</dc:title>
            </metadata>
            <manifest>
                <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
            </manifest>
            <spine>
                <itemref idref="ghost_item_id_1" />
                <itemref idref="ghost_item_id_2" />
            </spine>
        </package>
        """
        let ch1HTML = "<html><body><h1>Fallback Chapter</h1><p>Rescued via manifest fallback.</p></body></html>"
        
        let zipData = buildZipArchive(files: [
            ("mimetype", "application/epub+zip"),
            ("META-INF/container.xml", containerXML),
            ("OEBPS/content.opf", opfXML),
            ("OEBPS/ch1.xhtml", ch1HTML)
        ])
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".epub")
        try zipData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let parser = EPUBParser()
        let parsed = try await parser.parse(from: .fileURL(tempURL))
        XCTAssertEqual(parsed.title, "Fallback Book")
        XCTAssertEqual(parsed.chapters.count, 1)
        XCTAssertTrue(parsed.allBlocks.contains(where: { $0.text.contains("Rescued via manifest") }))
    }
    
    func testDeeplyNestedHTMLPerformance() {
        var deepHTML = "<html><body>"
        for _ in 0..<1000 {
            deepHTML += "<div><span><p>"
        }
        deepHTML += "Text in deeply nested tree."
        for _ in 0..<1000 {
            deepHTML += "</p></span></div>"
        }
        deepHTML += "</body></html>"
        
        let parser = EPUBParser()
        let blocks = parser.parseHTMLBlocks(from: deepHTML)
        XCTAssertFalse(blocks.isEmpty)
        XCTAssertTrue(blocks.first?.text.contains("Text in deeply nested tree") ?? false)
    }
    
    func testSVGMalformedImageReferences() {
        let parser = EPUBParser()
        let dirtyHTML = """
        <svg>
            <image xlink:href="file:///etc/passwd" />
            <image xlink:href="javascript:alert(1)" />
            <image xlink:href="data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==" />
            <image xlink:href="https://images.example.com/legit.png" />
        </svg>
        """
        
        let blocks = parser.parseHTMLBlocks(from: dirtyHTML)
        // file://, javascript:, and data: must not be resolved as valid image URLs
        let imageURLs = blocks.compactMap { $0.imageURL?.absoluteString }
        XCTAssertFalse(imageURLs.contains(where: { $0.hasPrefix("file:") }))
        XCTAssertFalse(imageURLs.contains(where: { $0.hasPrefix("javascript:") }))
        XCTAssertFalse(imageURLs.contains(where: { $0.hasPrefix("data:") }))
        XCTAssertTrue(imageURLs.contains("https://images.example.com/legit.png"))
    }
    
    // MARK: - Extremely Long Tokens & Paragraphs
    
    func testExtremelyLongParagraphChunking() async throws {
        // 100,000 character continuous text
        let hugeSentence = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 2250)
        XCTAssertGreaterThan(hugeSentence.count, 100_000)
        
        let parsed = try await PlainTextParser().parse(from: .rawText(hugeSentence, title: "Long Doc"))
        let semDoc = SemanticDocumentBuilder.shared.build(from: parsed)
        let chunks = TTSChunker.shared.chunk(sentences: semDoc.sentences)
        XCTAssertGreaterThan(chunks.count, 10)
    }
    
    func testExtremelyLongWordChunking() async throws {
        // 50,000 character monolithic token with no spaces
        let monsterWord = String(repeating: "Supercalifragilisticexpialidocious", count: 1500)
        XCTAssertGreaterThan(monsterWord.count, 50_000)
        
        let parsed = try await PlainTextParser().parse(from: .rawText(monsterWord, title: "Monster Word"))
        let semDoc = SemanticDocumentBuilder.shared.build(from: parsed)
        let chunks = TTSChunker.shared.chunk(sentences: semDoc.sentences)
        XCTAssertGreaterThanOrEqual(chunks.count, 1)
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    
    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
