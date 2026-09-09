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
        
        guard let opfPath = extractAttribute(from: containerXML, tag: "rootfile", attribute: "full-path") else {
            throw DocumentParserError.parsingFailed("Could not find OPF package path in container.xml")
        }
        
        guard let opfXML = archive.string(for: opfPath) else {
            throw DocumentParserError.parsingFailed("Missing OPF package file at: \(opfPath)")
        }
        
        // Base folder for relative item paths in OPF
        let opfBaseFolder: String = {
            let components = opfPath.split(separator: "/")
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
            // Remove URL fragments (e.g. #section1)
            let cleanHref = href.components(separatedBy: "#").first ?? href
            let fullPath = opfBaseFolder + cleanHref
            
            guard let chapterContent = archive.string(for: fullPath) else { continue }
            let blocks = parseHTMLBlocks(from: chapterContent)
            
            if !blocks.isEmpty {
                let chapterTitle = extractTagContent(from: chapterContent, tag: "h1")
                    ?? extractTagContent(from: chapterContent, tag: "title")
                    ?? "Chapter \(chapters.count + 1)"
                chapters.append(ParsedChapter(title: chapterTitle, blocks: blocks))
            }
        }
        
        if chapters.isEmpty {
            throw DocumentParserError.parsingFailed("No readable text chapters found in EPUB")
        }
        
        return ParsedDocument(title: title, author: author, format: .epub, chapters: chapters)
    }
    
    // MARK: - XML / Manifest Parsing Helpers
    
    private func extractManifest(from opfXML: String) -> [String: String] {
        var manifest: [String: String] = [:]
        let pattern = #"<item\s+[^>]*id=["']([^"']+)["'][^>]*href=["']([^"']+)["'][^>]*\/?>(?:<\/item>)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return manifest
        }
        
        let ns = opfXML as NSString
        let matches = regex.matches(in: opfXML, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.numberOfRanges >= 3 {
                let id = ns.substring(with: match.range(at: 1))
                let href = ns.substring(with: match.range(at: 2))
                manifest[id] = href
            }
        }
        
        // Also check reverse attribute order: href before id
        let patternAlt = #"<item\s+[^>]*href=["']([^"']+)["'][^>]*id=["']([^"']+)["'][^>]*\/?>(?:<\/item>)?"#
        if let regexAlt = try? NSRegularExpression(pattern: patternAlt, options: [.caseInsensitive]) {
            let altMatches = regexAlt.matches(in: opfXML, range: NSRange(location: 0, length: ns.length))
            for match in altMatches {
                if match.numberOfRanges >= 3 {
                    let href = ns.substring(with: match.range(at: 1))
                    let id = ns.substring(with: match.range(at: 2))
                    manifest[id] = href
                }
            }
        }
        
        return manifest
    }
    
    private func extractSpine(from opfXML: String) -> [String] {
        var spine: [String] = []
        let pattern = #"<itemref\s+[^>]*idref=["']([^"']+)["'][^>]*\/?>(?:<\/itemref>)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
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
    
    private func extractTagContent(from xml: String, tag: String) -> String? {
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
    
    private func extractAttribute(from xml: String, tag: String, attribute: String) -> String? {
        let pattern = "<" + tag + "\\s+[^>]*" + attribute + "=['\"]([^'\"]+)['\"][^>]*\\/?>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
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
        var sanitized = html.replacingOccurrences(of: "(?s)<script.*?</script>", with: "", options: .regularExpression)
        sanitized = sanitized.replacingOccurrences(of: "(?s)<style.*?</style>", with: "", options: .regularExpression)
        
        // Match headings, paragraphs, list items, blockquotes
        let blockPattern = #"<(h[1-6]|p|li|blockquote)[^>]*>(.*?)</\1>"#
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
    
    private func cleanHTMLText(_ html: String) -> String {
        // Strip tags
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode common entities
        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…"
        ]
        for (ent, rep) in entities {
            text = text.replacingOccurrences(of: ent, with: rep)
        }
        
        // Collapse excess whitespace
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
