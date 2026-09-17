//
//  EPUBParserTests.swift
//  VachanamTests
//
//  Tests for EPUBParser, ZipArchive, and multi-format document ingestion.
//

import XCTest
import zlib
@testable import Vachanam

final class EPUBParserTests: XCTestCase {
    
    // MARK: - Test Archive Builder
    
    private func createTestEPUBData(
        title: String = "Test Novel",
        author: String = "Jane Doe",
        usePercentEncodedHrefs: Bool = true,
        useWindowsBackslashesInZip: Bool = false
    ) -> Data {
        var files: [(name: String, content: String, compress: Bool)] = []
        
        // 1. mimetype (stored, not compressed per EPUB spec)
        files.append(("mimetype", "application/epub+zip", false))
        
        // 2. META-INF/container.xml
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        files.append(("META-INF/container.xml", containerXML, true))
        
        // 3. OEBPS/content.opf
        let chapter1Href = usePercentEncodedHrefs ? "Text/Chapter%201.xhtml" : "Text/Chapter 1.xhtml"
        let opfXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>\(title)</dc:title>
                <dc:creator>\(author)</dc:creator>
                <dc:language>en</dc:language>
            </metadata>
            <manifest>
                <item id="ch1"
                      href="\(chapter1Href)"
                      media-type="application/xhtml+xml"/>
                <item media-type="application/xhtml+xml" href="Text/ch2.xhtml" id="ch2" />
            </manifest>
            <spine>
                <itemref idref="ch1" />
                <itemref idref="ch2" />
            </spine>
        </package>
        """
        files.append(("OEBPS/content.opf", opfXML, true))
        
        // 4. Chapter 1 XHTML
        let ch1HTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter 1</title></head>
        <body>
            <h1>Chapter 1: The Arrival</h1>
            <p>The journey began on a crisp autumn morning&nbsp;&mdash;&nbsp;full of promise.</p>
            <div>A secondary paragraph in a div block.</div>
            <p>Sentence with &ldquo;quotes&rdquo; and &#8212; an em-dash.</p>
        </body>
        </html>
        """
        files.append(("OEBPS/Text/Chapter 1.xhtml", ch1HTML, true))
        
        // 5. Chapter 2 XHTML
        let ch2HTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter 2</title></head>
        <body>
            <h1>Chapter 2: Discoveries</h1>
            <p>New insights emerged from careful analysis.<br/>Every step unlocked a new secret.</p>
            <ul>
                <li>Observation alpha</li>
                <li>Observation beta</li>
            </ul>
        </body>
        </html>
        """
        files.append(("OEBPS/Text/ch2.xhtml", ch2HTML, true))
        
        return buildZipArchive(files: files, useWindowsSeparators: useWindowsBackslashesInZip)
    }
    
    private func buildZipArchive(
        files: [(name: String, content: String, compress: Bool)],
        useWindowsSeparators: Bool = false
    ) -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var cdCount: UInt16 = 0
        
        for file in files {
            let entryName = useWindowsSeparators ? file.name.replacingOccurrences(of: "/", with: "\\") : file.name
            let rawContent = Data(file.content.utf8)
            let uncompressedSize = UInt32(rawContent.count)
            let crc = UInt32(crc32(0, [UInt8](rawContent), uInt(rawContent.count)))
            
            let localHeaderOffset = UInt32(zipData.count)
            let nameData = Data(entryName.utf8)
            let nameLen = UInt16(nameData.count)
            
            let method: UInt16
            let payload: Data
            if file.compress {
                method = 8
                payload = compressDeflate(rawContent)
            } else {
                method = 0
                payload = rawContent
            }
            let compressedSize = UInt32(payload.count)
            
            // Local Header
            var lh = Data()
            lh.appendUInt32(0x04034b50)
            lh.appendUInt16(20) // version needed
            lh.appendUInt16(0)  // flags
            lh.appendUInt16(method)
            lh.appendUInt16(0)  // mod time
            lh.appendUInt16(0)  // mod date
            lh.appendUInt32(crc)
            lh.appendUInt32(compressedSize)
            lh.appendUInt32(uncompressedSize)
            lh.appendUInt16(nameLen)
            lh.appendUInt16(0)  // extra len
            lh.append(nameData)
            lh.append(payload)
            zipData.append(lh)
            
            // Central Directory Entry
            var cd = Data()
            cd.appendUInt32(0x02014b50)
            cd.appendUInt16(20) // version made by
            cd.appendUInt16(20) // version needed
            cd.appendUInt16(0)  // flags
            cd.appendUInt16(method)
            cd.appendUInt16(0)  // mod time
            cd.appendUInt16(0)  // mod date
            cd.appendUInt32(crc)
            cd.appendUInt32(compressedSize)
            cd.appendUInt32(uncompressedSize)
            cd.appendUInt16(nameLen)
            cd.appendUInt16(0)  // extra len
            cd.appendUInt16(0)  // comment len
            cd.appendUInt16(0)  // disk number
            cd.appendUInt16(0)  // internal attrs
            cd.appendUInt32(0)  // external attrs
            cd.appendUInt32(localHeaderOffset)
            cd.append(nameData)
            centralDirectory.append(cd)
            
            cdCount += 1
        }
        
        let cdOffset = UInt32(zipData.count)
        let cdSize = UInt32(centralDirectory.count)
        zipData.append(centralDirectory)
        
        // End of Central Directory
        var eocd = Data()
        eocd.appendUInt32(0x06054b50)
        eocd.appendUInt16(0)       // disk number
        eocd.appendUInt16(0)       // start disk
        eocd.appendUInt16(cdCount) // entries on disk
        eocd.appendUInt16(cdCount) // total entries
        eocd.appendUInt32(cdSize)
        eocd.appendUInt32(cdOffset)
        eocd.appendUInt16(0)       // comment len
        zipData.append(eocd)
        
        return zipData
    }
    
    private func compressDeflate(_ data: Data) -> Data {
        var stream = z_stream()
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return data
        }
        defer { deflateEnd(&stream) }
        
        let bufferSize = max(data.count * 2, 512)
        var output = Data(count: bufferSize)
        
        let status = data.withUnsafeBytes { rawIn in
            output.withUnsafeMutableBytes { rawOut in
                guard let inBase = rawIn.bindMemory(to: Bytef.self).baseAddress,
                      let outBase = rawOut.bindMemory(to: Bytef.self).baseAddress else {
                    return Z_MEM_ERROR
                }
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inBase)
                stream.avail_in = uInt(data.count)
                stream.next_out = outBase
                stream.avail_out = uInt(bufferSize)
                return deflate(&stream, Z_FINISH)
            }
        }
        
        if status == Z_STREAM_END {
            return output.prefix(Int(stream.total_out))
        }
        return data
    }
    
    // MARK: - Tests
    
    func testEPUBFullParsing() async throws {
        let epubData = createTestEPUBData(title: "The Odyssey of Sound", author: "Homer")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).epub")
        try epubData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let parser = EPUBParser()
        let parsed = try await parser.parse(from: .fileURL(tempURL))
        
        XCTAssertEqual(parsed.title, "The Odyssey of Sound")
        XCTAssertEqual(parsed.author, "Homer")
        XCTAssertEqual(parsed.format, .epub)
        XCTAssertEqual(parsed.chapters.count, 2)
        
        let ch1 = parsed.chapters[0]
        XCTAssertEqual(ch1.title, "Chapter 1: The Arrival")
        XCTAssertTrue(ch1.blocks.contains(where: { $0.type == .heading && $0.text == "Chapter 1: The Arrival" }))
        XCTAssertTrue(ch1.blocks.contains(where: { $0.type == .paragraph && $0.text.contains("crisp autumn morning") }))
        XCTAssertTrue(ch1.blocks.contains(where: { $0.type == .paragraph && $0.text.contains("secondary paragraph in a div") }))
        
        let ch2 = parsed.chapters[1]
        XCTAssertEqual(ch2.title, "Chapter 2: Discoveries")
        XCTAssertTrue(ch2.blocks.contains(where: { $0.type == .listItem && $0.text == "Observation alpha" }))
    }
    
    func testEPUBWithWindowsBackslashesInZip() async throws {
        let epubData = createTestEPUBData(title: "Windows Archive Book", useWindowsBackslashesInZip: true)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).epub")
        try epubData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let parser = EPUBParser()
        let parsed = try await parser.parse(from: .fileURL(tempURL))
        
        XCTAssertEqual(parsed.title, "Windows Archive Book")
        XCTAssertEqual(parsed.chapters.count, 2)
    }
    
    func testZipArchiveChunkedDecompression() {
        let largeString = String(repeating: "Vachanam universal text-to-speech engine. ", count: 5000)
        let largeData = Data(largeString.utf8)
        let compressed = compressDeflate(largeData)
        
        let files = [("large.txt", largeString, true)]
        let zipData = buildZipArchive(files: files)
        
        let archive = ZipArchive(data: zipData)
        XCTAssertNotNil(archive)
        
        let extracted = archive?.string(for: "large.txt")
        XCTAssertEqual(extracted?.count, largeString.count)
        XCTAssertEqual(extracted, largeString)
    }
    
    func testHTMLCleaningPreventsGluedWords() {
        let parser = EPUBParser()
        let html = "<p>First paragraph.</p><p>Second paragraph.</p>"
        let cleaned = parser.cleanHTMLText(html)
        XCTAssertFalse(cleaned.contains("paragraph.Second"))
        XCTAssertTrue(cleaned.contains("First paragraph."))
        XCTAssertTrue(cleaned.contains("Second paragraph."))
    }
    
    func testEntityDecoding() {
        let parser = EPUBParser()
        let html = "Hello &ldquo;World&rdquo;&nbsp;&mdash;&nbsp;&#8212;&nbsp;&#x2600;"
        let cleaned = parser.cleanHTMLText(html)
        XCTAssertTrue(cleaned.contains("“World”"))
        XCTAssertTrue(cleaned.contains("—"))
        XCTAssertTrue(cleaned.contains("☀"))
    }
    
    func testPlainTextEncodingFallback() async throws {
        // String with non-ASCII characters encoded in ISO Latin 1
        let text = "Café au lait and naïve façade."
        guard let latin1Data = text.data(using: .isoLatin1) else {
            XCTFail("Failed to encode ISO Latin 1")
            return
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try latin1Data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let parser = PlainTextParser()
        let parsed = try await parser.parse(from: .fileURL(tempURL))
        
        XCTAssertFalse(parsed.chapters.isEmpty)
        let blockText = parsed.allBlocks.first?.text ?? ""
        XCTAssertTrue(blockText.contains("Café") || blockText.contains("lait"))
    }
    
    func testMarkdownSetextHeadings() async throws {
        let md = """
        Top Level Book
        ==============
        
        Introductory body paragraph.
        
        Sub Section Header
        ------------------
        
        Second body paragraph.
        """
        let parser = MarkdownParser()
        let parsed = try await parser.parse(from: .rawText(md, title: "Untitled"))
        
        XCTAssertEqual(parsed.title, "Top Level Book")
        let headings = parsed.allBlocks.filter { $0.type == .heading }
        XCTAssertEqual(headings.count, 2)
        XCTAssertEqual(headings[0].text, "Top Level Book")
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertEqual(headings[1].text, "Sub Section Header")
        XCTAssertEqual(headings[1].level, 2)
    }
}

// MARK: - Binary Helper Extensions

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var v = value.littleEndian
        append(UnsafeBufferPointer(start: &v, count: 1))
    }
    
    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        append(UnsafeBufferPointer(start: &v, count: 1))
    }
}
