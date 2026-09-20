//
//  SecurityHardeningTests.swift
//  VachanamTests
//
//  Unit tests verifying AUD-24 security hardening:
//  - WebArticleParser URL validation & SSRF protection (HTTPS-only, private IP blocking)
//  - ZipArchive path traversal resistance & decompression limits
//  - HTML sanitization against malicious payloads
//

import XCTest
@testable import Vachanam

final class SecurityHardeningTests: XCTestCase {
    
    // MARK: - URL Security Validation Tests
    
    func testRejectsInsecureSchemes() {
        let insecureURLs = [
            "http://example.com/article",
            "file:///etc/passwd",
            "ftp://files.example.com/data.txt",
            "javascript:alert(document.cookie)",
            "data:text/html,<h1>Malicious</h1>"
        ]
        
        for urlStr in insecureURLs {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertThrowsError(try URLSecurityValidator.validate(url: url), "Should reject insecure scheme in: \(urlStr)") { error in
                guard let validationError = error as? URLSecurityValidator.ValidationError else {
                    XCTFail("Expected ValidationError but got \(error)")
                    return
                }
                if case .invalidScheme = validationError {
                    // Success
                } else {
                    XCTFail("Expected invalidScheme error for \(urlStr), got \(validationError)")
                }
            }
        }
    }
    
    func testRejectsLoopbackAndLocalhost() {
        let localhostURLs = [
            "https://localhost/secret",
            "https://sub.localhost/api",
            "https://127.0.0.1/admin",
            "https://127.0.0.2:8080/data",
            "https://[::1]/status"
        ]
        
        for urlStr in localhostURLs {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertThrowsError(try URLSecurityValidator.validate(url: url), "Should reject loopback/localhost: \(urlStr)") { error in
                guard let validationError = error as? URLSecurityValidator.ValidationError else {
                    XCTFail("Expected ValidationError but got \(error)")
                    return
                }
                if case .privateOrReservedAddress = validationError {
                    // Success
                } else {
                    XCTFail("Expected privateOrReservedAddress error for \(urlStr), got \(validationError)")
                }
            }
        }
    }
    
    func testRejectsCloudMetadataEndpoint() {
        let metadataURL = URL(string: "https://169.254.169.254/latest/meta-data/")!
        XCTAssertThrowsError(try URLSecurityValidator.validate(url: metadataURL), "Must reject AWS/GCP/Azure link-local metadata IP") { error in
            guard let validationError = error as? URLSecurityValidator.ValidationError else {
                XCTFail("Expected ValidationError but got \(error)")
                return
            }
            if case .privateOrReservedAddress = validationError {
                // Success
            } else {
                XCTFail("Expected privateOrReservedAddress for cloud metadata, got \(validationError)")
            }
        }
    }
    
    func testRejectsPrivateIPv4Ranges() {
        let privateIPs = [
            "https://10.0.0.1/",
            "https://10.255.255.254/",
            "https://172.16.0.1/",
            "https://172.24.1.100/",
            "https://172.31.255.255/",
            "https://192.168.1.1/",
            "https://192.168.0.254/",
            "https://169.254.1.1/"
        ]
        
        for urlStr in privateIPs {
            let url = URL(string: urlStr)!
            XCTAssertThrowsError(try URLSecurityValidator.validate(url: url), "Must reject private IP \(urlStr)") { error in
                guard let validationError = error as? URLSecurityValidator.ValidationError else {
                    XCTFail("Expected ValidationError but got \(error)")
                    return
                }
                if case .privateOrReservedAddress = validationError {
                    // Success
                } else {
                    XCTFail("Expected privateOrReservedAddress for \(urlStr), got \(validationError)")
                }
            }
        }
    }
    
    func testIPv4RangeHelper() {
        func makeIP(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> UInt32 {
            return (UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(c) << 8) | UInt32(d)
        }
        
        // Loopback
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(127, 0, 0, 1)))
        // 10.0.0.0/8
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(10, 50, 1, 1)))
        // 172.16.0.0/12
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(172, 16, 0, 1)))
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(172, 31, 255, 255)))
        XCTAssertFalse(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(172, 32, 0, 1)))
        // 192.168.0.0/16
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(192, 168, 1, 1)))
        // Link-local / Cloud metadata
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(169, 254, 169, 254)))
        // CGNAT 100.64.0.0/10
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(100, 64, 0, 1)))
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(100, 127, 255, 255)))
        XCTAssertFalse(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(100, 128, 0, 1)))
        // Multicast
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(224, 0, 0, 1)))
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(239, 255, 255, 255)))
        // Public IPs (should be allowed)
        XCTAssertFalse(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(8, 8, 8, 8)))
        XCTAssertFalse(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(1, 1, 1, 1)))
        XCTAssertFalse(URLSecurityValidator.isPrivateOrReservedIPv4(makeIP(142, 250, 190, 46)))
    }
    
    func testIPv6RangeHelper() {
        // ::1 loopback
        let loopback: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv6(loopback))
        
        // Link-local fe80::1
        let linkLocal: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0xFE, 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv6(linkLocal))
        
        // Unique local fc00::1
        let ula: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0xFC, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv6(ula))
        
        // IPv4-mapped 127.0.0.1
        let mappedLoopback: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF, 127, 0, 0, 1)
        XCTAssertTrue(URLSecurityValidator.isPrivateOrReservedIPv6(mappedLoopback))
        
        // Public IPv6 (2001:4860:4860::8888)
        let publicIPv6: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0x20, 0x01, 0x48, 0x60, 0x48, 0x60, 0, 0, 0, 0, 0, 0, 0, 0, 0x88, 0x88)
        XCTAssertFalse(URLSecurityValidator.isPrivateOrReservedIPv6(publicIPv6))
    }
    
    // MARK: - ZipArchive Security & Traversal Resistance Tests
    
    func testZipArchivePathTraversalNormalization() {
        let dummyData = Data([0x50, 0x4b, 0x05, 0x06] + [UInt8](repeating: 0, count: 18))
        guard let zip = ZipArchive(data: dummyData) else {
            return
        }
        
        XCTAssertEqual(zip.normalizeEntryPath("../../etc/passwd"), "etc/passwd")
        XCTAssertEqual(zip.normalizeEntryPath("../../../../../secret.key"), "secret.key")
        XCTAssertEqual(zip.normalizeEntryPath("./folder/../secret.txt"), "secret.txt")
        XCTAssertEqual(zip.normalizeEntryPath("a/b/../../c/d"), "c/d")
        XCTAssertEqual(zip.normalizeEntryPath("/absolute/path/file.txt"), "absolute/path/file.txt")
        XCTAssertEqual(zip.normalizeEntryPath("windows\\backslashes\\..\\test.txt"), "windows/test.txt")
        XCTAssertEqual(zip.normalizeEntryPath("null\0byte\0attack.xhtml"), "nullbyteattack.xhtml")
    }
    
    func testZipArchiveLimitsConstants() {
        XCTAssertEqual(ZipArchive.maxEntryDecompressedBytes, 100 * 1024 * 1024)
        XCTAssertEqual(ZipArchive.maxTotalDecompressedBytes, 500 * 1024 * 1024)
        XCTAssertEqual(ZipArchive.maxCompressionRatio, 1000.0)
    }
    
    // MARK: - HTML Sanitization Tests
    
    func testWebArticleParserStripsDangerousTags() {
        let parser = WebArticleParser()
        let dirtyHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Safe Article Title</title>
            <script>alert("xss");</script>
            <style>body { display: none; }</style>
        </head>
        <body>
            <header><p>Site Header Navigation</p></header>
            <main>
                <article>
                    <p>This is legitimate safe text that should be extracted and presented to the reader.</p>
                    <script src="https://evil.com/tracker.js"></script>
                    <iframe src="https://malicious.com"></iframe>
                    <svg><circle cx="50" cy="50" r="40"/></svg>
                </article>
            </main>
            <footer><p>Site Footer Copyright 2026</p></footer>
        </body>
        </html>
        """
        
        let parsed = parser.parseHTMLArticle(dirtyHTML, defaultTitle: "Fallback")
        XCTAssertEqual(parsed.title, "Safe Article Title")
        
        let allText = parsed.allBlocks.map { $0.text }.joined(separator: " ")
        XCTAssertFalse(allText.contains("alert(\"xss\")"), "Script tags must be stripped")
        XCTAssertFalse(allText.contains("tracker.js"), "Script references must be stripped")
        XCTAssertFalse(allText.contains("display: none"), "Style blocks must be stripped")
        XCTAssertTrue(allText.contains("legitimate safe text"), "Legitimate text must remain intact")
    }
}
