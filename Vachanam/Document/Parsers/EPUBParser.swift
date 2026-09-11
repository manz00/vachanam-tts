//
//  EPUBParser.swift
//  Vachanam
//
//  Parses EPUB 2 and EPUB 3 files into structured ParsedDocument models.
//

import Foundation

public struct EPUBParser: DocumentParser {
    public init() {}
    
    public func parse(from source: DocumentSource) async throws -> ParsedDocument {
        let fileURL: URL
        switch source {
        case .fileURL(let url):
            fileURL = url
        case .webURL, .rawText:
            throw DocumentParserError.invalidSource("EPUBParser requires a local fileURL")
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw DocumentParserError.fileNotFound(fileURL)
        }
        
        guard let archive = ZipArchive(url: fileURL) else {
            throw DocumentParserError.parsingFailed("Could not open EPUB file as a zip archive")
        }
        
        // 1. Find OPF package document via container.xml
        guard let containerXML = archive.string(for: "META-INF/container.xml") else {
            throw DocumentParserError.parsingFailed("Missing META-INF/container.xml in EPUB")
        }
        
        guard let rawOpfPath = extractAttribute(from: containerXML, tag: "rootfile", attribute: "full-path") else {
            throw DocumentParserError.parsingFailed("Could not find OPF package path in container.xml")
        }
        
        var cleanOpfPath = archive.normalizeEntryPath(rawOpfPath)
        let opfXML: String
        if let direct = archive.string(for: cleanOpfPath) ?? archive.string(for: rawOpfPath) {
            opfXML = direct
        } else if let found = archive.entries.first(where: { $0.key.lowercased().hasSuffix(".opf") }),
                  let fallback = archive.string(for: found.key) {
            cleanOpfPath = found.key
            opfXML = fallback
        } else {
            throw DocumentParserError.parsingFailed("Missing OPF package file at: \(cleanOpfPath)")
        }
        
        // Base folder for relative item paths in OPF
        let opfBaseFolder: String = {
            let components = cleanOpfPath.split(separator: "/")
            if components.count > 1 {
                return components.dropLast().joined(separator: "/") + "/"
            }
            return ""
        }()
        
        // 2. Extract metadata
        let title = extractTagContent(from: opfXML, tag: "dc:title") ?? fileURL.deletingPathExtension().lastPathComponent
        let author = extractTagContent(from: opfXML, tag: "dc:creator")
        
        // 3. Extract manifest and spine
        let manifest = extractManifest(from: opfXML)
        let spineIDs = extractSpine(from: opfXML)
        
        // 4. Parse chapters in spine order
        var chapters: [ParsedChapter] = []
        
        for spineID in spineIDs {
            guard let href = manifest[spineID] else { continue }
            // Remove URL fragments (e.g. #section1) and percent encoding
            let cleanHref = (href.components(separatedBy: "#").first ?? href)
                .removingPercentEncoding ?? href
            let rawPath = opfBaseFolder + cleanHref
            let normalizedPath = archive.normalizeEntryPath(rawPath)
            
            guard let chapterContent = archive.string(for: normalizedPath)
                    ?? archive.string(for: rawPath)
                    ?? archive.string(for: cleanHref) else {
                continue
            }
            let blocks = parseHTMLBlocks(from: chapterContent)
            
            if !blocks.isEmpty {
                let chapterTitle = extractTagContent(from: chapterContent, tag: "h1")
                    ?? extractTagContent(from: chapterContent, tag: "h2")
                    ?? extractTagContent(from: chapterContent, tag: "title")
                    ?? "Chapter \(chapters.count + 1)"
                chapters.append(ParsedChapter(title: chapterTitle, blocks: blocks))
            }
        }
        
        // Fallback: If spine was missing or empty, parse HTML items in manifest order
        if chapters.isEmpty {
            let htmlHrefs = manifest.values.filter {
                let lower = $0.lowercased()
                return lower.hasSuffix(".xhtml") || lower.hasSuffix(".html") || lower.hasSuffix(".htm")
            }.sorted()
            
            for href in htmlHrefs {
                let cleanHref = (href.components(separatedBy: "#").first ?? href)
                    .removingPercentEncoding ?? href
                let rawPath = opfBaseFolder + cleanHref
                let normalizedPath = archive.normalizeEntryPath(rawPath)
                guard let chapterContent = archive.string(for: normalizedPath)
                        ?? archive.string(for: rawPath)
                        ?? archive.string(for: cleanHref) else {
                    continue
                }
                let blocks = parseHTMLBlocks(from: chapterContent)
                if !blocks.isEmpty {
                    let chapterTitle = extractTagContent(from: chapterContent, tag: "h1")
                        ?? extractTagContent(from: chapterContent, tag: "h2")
                        ?? extractTagContent(from: chapterContent, tag: "title")
                        ?? "Section \(chapters.count + 1)"
                    chapters.append(ParsedChapter(title: chapterTitle, blocks: blocks))
                }
            }
        }
        
        if chapters.isEmpty {
            throw DocumentParserError.parsingFailed("No readable text chapters found in EPUB")
        }
        
        return ParsedDocument(title: title, author: author, format: .epub, chapters: chapters)
    }
    
    // MARK: - XML / Manifest Parsing Helpers
    
    public func extractManifest(from opfXML: String) -> [String: String] {
        var manifest: [String: String] = [:]
        let tagPattern = #"<item\b([^>]+)\/?>"#
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return manifest
        }
        
        let idRegex = try? NSRegularExpression(pattern: #"\bid\s*=\s*['"]([^'"]+)['"]"#, options: [.caseInsensitive])
        let hrefRegex = try? NSRegularExpression(pattern: #"\bhref\s*=\s*['"]([^'"]+)['"]"#, options: [.caseInsensitive])
        
        let ns = opfXML as NSString
        let matches = tagRegex.matches(in: opfXML, range: NSRange(location: 0, length: ns.length))
        
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let attrs = ns.substring(with: match.range(at: 1))
            let attrsNS = attrs as NSString
            
            var itemID: String?
            var itemHref: String?
            
            if let idMatch = idRegex?.firstMatch(in: attrs, range: NSRange(location: 0, length: attrsNS.length)), idMatch.numberOfRanges >= 2 {
                itemID = attrsNS.substring(with: idMatch.range(at: 1))
            }
            if let hrefMatch = hrefRegex?.firstMatch(in: attrs, range: NSRange(location: 0, length: attrsNS.length)), hrefMatch.numberOfRanges >= 2 {
                itemHref = attrsNS.substring(with: hrefMatch.range(at: 1))
            }
            
            if let id = itemID, let href = itemHref {
                manifest[id] = href
            }
        }
        return manifest
    }
    
    public func extractSpine(from opfXML: String) -> [String] {
        var spine: [String] = []
        let pattern = #"<itemref\b[^>]*?\bidref\s*=\s*['"]([^'"]+)['"][^>]*\/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return spine
        }
        let ns = opfXML as NSString
        let matches = regex.matches(in: opfXML, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.numberOfRanges >= 2 {
                let idref = ns.substring(with: match.range(at: 1))
                spine.append(idref)
            }
        }
        return spine
    }
    
    public func extractTagContent(from xml: String, tag: String) -> String? {
        let pattern = "<" + tag + "[^>]*>(.*?)</" + tag + ">"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let ns = xml as NSString
        if let match = regex.firstMatch(in: xml, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges >= 2 {
            let raw = ns.substring(with: match.range(at: 1))
            return cleanHTMLText(raw)
        }
        return nil
    }
    
    public func extractAttribute(from xml: String, tag: String, attribute: String) -> String? {
        let pattern = #"<\#(tag)\b[^>]*?\b\#(attribute)\s*=\s*['"]([^'"]+)['"][^>]*\/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let ns = xml as NSString
        if let match = regex.firstMatch(in: xml, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges >= 2 {
            return ns.substring(with: match.range(at: 1))
        }
        return nil
    }
    
    // MARK: - HTML Chapter Block Parser
    
    public func parseHTMLBlocks(from html: String) -> [ParsedBlock] {
        var blocks: [ParsedBlock] = []
        
        // Strip scripts and styles first
        var sanitized = html.replacingOccurrences(of: "(?is)<script.*?</script>", with: "", options: .regularExpression)
        sanitized = sanitized.replacingOccurrences(of: "(?is)<style.*?</style>", with: "", options: .regularExpression)
        
        // Match headings, paragraphs, list items, blockquotes, divs, dd/dt
        let blockPattern = #"<(h[1-6]|p|li|blockquote|div|dt|dd)[^>]*>(.*?)</\1>"#
        guard let regex = try? NSRegularExpression(pattern: blockPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return blocks
        }
        
        let ns = sanitized as NSString
        let matches = regex.matches(in: sanitized, range: NSRange(location: 0, length: ns.length))
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let tagName = ns.substring(with: match.range(at: 1)).lowercased()
            let innerHTML = ns.substring(with: match.range(at: 2))
            let text = cleanHTMLText(innerHTML)
            
            guard !text.isEmpty else { continue }
            
            if tagName.hasPrefix("h") {
                let level = Int(tagName.dropFirst()) ?? 1
                blocks.append(ParsedBlock(type: .heading, text: text, level: level))
            } else if tagName == "li" {
                blocks.append(ParsedBlock(type: .listItem, text: text, level: 1, marker: "•"))
            } else if tagName == "blockquote" {
                blocks.append(ParsedBlock(type: .quote, text: text, level: 1))
            } else {
                blocks.append(ParsedBlock(type: .paragraph, text: text, level: 1))
            }
        }
        
        // Fallback: If no structured tags found, extract text separated by paragraph breaks
        if blocks.isEmpty {
            let plainText = cleanHTMLText(sanitized)
            let paragraphs = plainText.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for p in paragraphs {
                blocks.append(ParsedBlock(type: .paragraph, text: p))
            }
        }
        
        return blocks
    }
    
    public func cleanHTMLText(_ html: String) -> String {
        // Pre-convert break tags and block boundaries to whitespace/newlines to avoid word gluing
        var text = html
            .replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "(?i)</(p|div|h[1-6]|li|blockquote)>", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        
        // Decode common named entities
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&rsquo;": "’",
            "&lsquo;": "‘",
            "&rdquo;": "”",
            "&ldquo;": "“",
            "&bull;": "•",
            "&trade;": "™",
            "&copy;": "©",
            "&reg;": "®"
        ]
        for (ent, rep) in entities {
            text = text.replacingOccurrences(of: ent, with: rep)
        }
        
        // Decode decimal numeric entities: &#1234;
        if let decRegex = try? NSRegularExpression(pattern: #"&#(\d+);"#, options: []) {
            let nsText = text as NSString
            let matches = decRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let numStr = nsText.substring(with: match.range(at: 1))
                    if let code = UInt32(numStr), let scalar = UnicodeScalar(code) {
                        text = (text as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                    }
                }
            }
        }
        
        // Decode hexadecimal numeric entities: &#x1f600;
        if let hexRegex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]+);"#, options: []) {
            let nsText = text as NSString
            let matches = hexRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let hexStr = nsText.substring(with: match.range(at: 1))
                    if let code = UInt32(hexStr, radix: 16), let scalar = UnicodeScalar(code) {
                        text = (text as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                    }
                }
            }
        }
        
        // Collapse excess whitespace
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
