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
            let blocks = parseHTMLBlocks(from: chapterContent) { [self] src in
                let imgData = self.resolveImageData(
                    for: src,
                    chapterNormalizedPath: normalizedPath,
                    opfBaseFolder: opfBaseFolder,
                    manifest: manifest,
                    archive: archive
                )
                return (data: imgData, caption: nil)
            }
            
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
                let blocks = parseHTMLBlocks(from: chapterContent) { [self] src in
                    let imgData = self.resolveImageData(
                        for: src,
                        chapterNormalizedPath: normalizedPath,
                        opfBaseFolder: opfBaseFolder,
                        manifest: manifest,
                        archive: archive
                    )
                    return (data: imgData, caption: nil)
                }
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
    
    // MARK: - Precompiled Regex Cache
    
    private static let itemTagRegex = try? NSRegularExpression(
        pattern: #"<item\b([^>]+)\/?>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private static let idAttrRegex = try? NSRegularExpression(
        pattern: #"\bid\s*=\s*['"]([^'"]+)['"]"#,
        options: [.caseInsensitive]
    )
    private static let hrefAttrRegex = try? NSRegularExpression(
        pattern: #"\bhref\s*=\s*['"]([^'"]+)['"]"#,
        options: [.caseInsensitive]
    )
    private static let itemrefRegex = try? NSRegularExpression(
        pattern: #"<itemref\b[^>]*?\bidref\s*=\s*['"]([^'"]+)['"][^>]*\/?>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private static let scriptRegex = try? NSRegularExpression(
        pattern: "(?is)<script.*?</script>",
        options: []
    )
    private static let styleRegex = try? NSRegularExpression(
        pattern: "(?is)<style.*?</style>",
        options: []
    )
    private static let blockPatternRegex = try? NSRegularExpression(
        pattern: #"<(h[1-6]|p|li|blockquote|div|dt|dd)[^>]*>(.*?)</\1>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private static let imgTagRegex = try? NSRegularExpression(
        pattern: #"<(?:img|image)\b([^>]*)\/?>"#,
        options: [.caseInsensitive]
    )
    private static let srcAttrRegex = try? NSRegularExpression(
        pattern: #"\b(?:src|xlink:href|href)\s*=\s*['"]([^'"]+)['"]"#,
        options: [.caseInsensitive]
    )
    private static let altAttrRegex = try? NSRegularExpression(
        pattern: #"\b(?:alt|title)\s*=\s*['"]([^'"]*)['"]"#,
        options: [.caseInsensitive]
    )
    private static let breakRegex = try? NSRegularExpression(
        pattern: "(?i)<br\\s*/?>",
        options: []
    )
    private static let blockCloseRegex = try? NSRegularExpression(
        pattern: "(?i)</(p|div|h[1-6]|li|blockquote)>",
        options: []
    )
    private static let htmlTagRegex = try? NSRegularExpression(
        pattern: "<[^>]+>",
        options: []
    )
    private static let decEntityRegex = try? NSRegularExpression(
        pattern: #"&#(\d+);"#,
        options: []
    )
    private static let hexEntityRegex = try? NSRegularExpression(
        pattern: #"&#x([0-9a-fA-F]+);"#,
        options: []
    )
    private static let whitespaceRegex = try? NSRegularExpression(
        pattern: "[ \\t]+",
        options: []
    )
    private static let excessNewlinesRegex = try? NSRegularExpression(
        pattern: "\\n{3,}",
        options: []
    )
    
    // MARK: - Image Resolution Helper
    
    public func resolveImageData(
        for rawSrc: String,
        chapterNormalizedPath: String,
        opfBaseFolder: String,
        manifest: [String: String],
        archive: ZipArchive
    ) -> Data? {
        let cleanSrc = (rawSrc.components(separatedBy: "#").first ?? rawSrc)
            .removingPercentEncoding ?? rawSrc
        guard !cleanSrc.isEmpty else { return nil }
        
        let chapterFolder: String
        let components = chapterNormalizedPath.split(separator: "/")
        if components.count > 1 {
            chapterFolder = components.dropLast().joined(separator: "/") + "/"
        } else {
            chapterFolder = ""
        }
        
        // Strategy 1: Relative to chapter folder in archive
        let path1 = archive.normalizeEntryPath(chapterFolder + cleanSrc)
        if let data = archive.data(for: path1) { return data }
        
        // Strategy 2: Relative to OPF base folder
        let path2 = archive.normalizeEntryPath(opfBaseFolder + cleanSrc)
        if let data = archive.data(for: path2) { return data }
        
        // Strategy 3: Directly as normalized path
        let path3 = archive.normalizeEntryPath(cleanSrc)
        if let data = archive.data(for: path3) { return data }
        
        // Strategy 4: Manifest lookup by matching filename
        let filename = (cleanSrc as NSString).lastPathComponent.lowercased()
        for manifestHref in manifest.values {
            if (manifestHref as NSString).lastPathComponent.lowercased() == filename {
                let norm = archive.normalizeEntryPath(manifestHref)
                if let data = archive.data(for: norm) { return data }
                let normWithOpf = archive.normalizeEntryPath(opfBaseFolder + manifestHref)
                if let data = archive.data(for: normWithOpf) { return data }
            }
        }
        
        // Strategy 5: Lookup by filename across all archive entries
        for entryKey in archive.entries.keys {
            if (entryKey as NSString).lastPathComponent.lowercased() == filename {
                if let data = archive.data(for: entryKey) { return data }
            }
        }
        
        return nil
    }
    
    private static let namedEntities: [(String, String)] = [
        ("&nbsp;", " "),
        ("&amp;", "&"),
        ("&quot;", "\""),
        ("&apos;", "'"),
        ("&#39;", "'"),
        ("&lt;", "<"),
        ("&gt;", ">"),
        ("&mdash;", "—"),
        ("&ndash;", "–"),
        ("&hellip;", "…"),
        ("&rsquo;", "’"),
        ("&lsquo;", "‘"),
        ("&rdquo;", "”"),
        ("&ldquo;", "“"),
        ("&bull;", "•"),
        ("&trade;", "™"),
        ("&copy;", "©"),
        ("&reg;", "®")
    ]
    
    // MARK: - XML / Manifest Parsing Helpers
    
    public func extractManifest(from opfXML: String) -> [String: String] {
        var manifest: [String: String] = [:]
        guard let tagRegex = Self.itemTagRegex else { return manifest }
        
        let idRegex = Self.idAttrRegex
        let hrefRegex = Self.hrefAttrRegex
        
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
        guard let regex = Self.itemrefRegex else { return spine }
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
    
    public func parseHTMLBlocks(
        from html: String,
        imageResolver: ((String) -> (data: Data?, caption: String?))? = nil
    ) -> [ParsedBlock] {
        var blocks: [ParsedBlock] = []
        
        // Strip scripts and styles first using precompiled regexes
        var sanitized = html
        if sanitized.contains("<script") || sanitized.contains("<SCRIPT") {
            if let r = Self.scriptRegex {
                let ns = sanitized as NSString
                sanitized = r.stringByReplacingMatches(in: sanitized, range: NSRange(location: 0, length: ns.length), withTemplate: "")
            }
        }
        if sanitized.contains("<style") || sanitized.contains("<STYLE") {
            if let r = Self.styleRegex {
                let ns = sanitized as NSString
                sanitized = r.stringByReplacingMatches(in: sanitized, range: NSRange(location: 0, length: ns.length), withTemplate: "")
            }
        }
        
        // Helper to extract image blocks from an HTML fragment (e.g. <img> or <image>)
        func extractImageBlocks(from fragment: String) -> [ParsedBlock] {
            guard let imgRegex = Self.imgTagRegex else { return [] }
            let nsFrag = fragment as NSString
            let imgMatches = imgRegex.matches(in: fragment, range: NSRange(location: 0, length: nsFrag.length))
            var imgBlocks: [ParsedBlock] = []
            
            for m in imgMatches {
                let attrs = m.numberOfRanges >= 2 ? nsFrag.substring(with: m.range(at: 1)) : ""
                let attrsNS = attrs as NSString
                
                var src: String?
                var alt: String?
                
                if let srcMatch = Self.srcAttrRegex?.firstMatch(in: attrs, range: NSRange(location: 0, length: attrsNS.length)), srcMatch.numberOfRanges >= 2 {
                    src = attrsNS.substring(with: srcMatch.range(at: 1))
                }
                if let altMatch = Self.altAttrRegex?.firstMatch(in: attrs, range: NSRange(location: 0, length: attrsNS.length)), altMatch.numberOfRanges >= 2 {
                    alt = attrsNS.substring(with: altMatch.range(at: 1))
                }
                
                guard let imageSrc = src, !imageSrc.isEmpty else { continue }
                let (data, caption) = imageResolver?(imageSrc) ?? (nil, nil)
                let resolvedCaption = cleanHTMLText(caption ?? alt ?? "")
                
                if let data = data {
                    imgBlocks.append(ParsedBlock(type: .image, text: resolvedCaption, imageData: data))
                } else if imageSrc.lowercased().hasPrefix("https://"), let url = URL(string: imageSrc) {
                    imgBlocks.append(ParsedBlock(type: .image, text: resolvedCaption, imageURL: url))
                }
            }
            return imgBlocks
        }
        
        // Match headings, paragraphs, list items, blockquotes, divs, dd/dt
        if let regex = Self.blockPatternRegex {
            let ns = sanitized as NSString
            let matches = regex.matches(in: sanitized, range: NSRange(location: 0, length: ns.length))
            
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let tagName = ns.substring(with: match.range(at: 1)).lowercased()
                let innerHTML = ns.substring(with: match.range(at: 2))
                
                // If innerHTML contains an image tag
                if innerHTML.contains("<img") || innerHTML.contains("<IMG") || innerHTML.contains("<image") || innerHTML.contains("<IMAGE") {
                    let extracted = extractImageBlocks(from: innerHTML)
                    if !extracted.isEmpty {
                        let text = cleanHTMLText(innerHTML)
                        // If there was substantial text alongside the image, emit it
                        if !text.isEmpty && text != extracted.first?.text {
                            blocks.append(ParsedBlock(type: .paragraph, text: text))
                        }
                        blocks.append(contentsOf: extracted)
                        continue
                    }
                }
                
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
        }
        
        // Standalone images / SVG images (e.g. cover page <svg><image .../></svg> or standalone <img ...>)
        if blocks.isEmpty || (sanitized.contains("<img") || sanitized.contains("<image")) {
            let standaloneImages = extractImageBlocks(from: sanitized)
            for img in standaloneImages {
                if !blocks.contains(where: { $0.imageData == img.imageData && $0.type == .image }) {
                    blocks.append(img)
                }
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
        guard !html.isEmpty else { return "" }
        var text = html
        
        // Fast-path tag conversions if '<' exists
        if text.contains("<") {
            if let r = Self.breakRegex {
                let ns = text as NSString
                text = r.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: ns.length), withTemplate: "\n")
            }
            if let r = Self.blockCloseRegex {
                let ns = text as NSString
                text = r.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: ns.length), withTemplate: "\n\n")
            }
            if let r = Self.htmlTagRegex {
                let ns = text as NSString
                text = r.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: ns.length), withTemplate: " ")
            }
        }
        
        // Fast-path entity decoding if '&' exists
        if text.contains("&") {
            for (ent, rep) in Self.namedEntities {
                if text.contains(ent) {
                    text = text.replacingOccurrences(of: ent, with: rep)
                }
            }
            
            // Decode decimal numeric entities: &#1234;
            if text.contains("&#"), let decRegex = Self.decEntityRegex {
                let nsText = text as NSString
                let matches = decRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                if !matches.isEmpty {
                    for match in matches.reversed() {
                        if match.numberOfRanges >= 2 {
                            let numStr = nsText.substring(with: match.range(at: 1))
                            if let code = UInt32(numStr), let scalar = UnicodeScalar(code) {
                                text = (text as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                            }
                        }
                    }
                }
            }
            
            // Decode hexadecimal numeric entities: &#x1f600;
            if text.contains("&#x") || text.contains("&#X"), let hexRegex = Self.hexEntityRegex {
                let nsText = text as NSString
                let matches = hexRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                if !matches.isEmpty {
                    for match in matches.reversed() {
                        if match.numberOfRanges >= 2 {
                            let hexStr = nsText.substring(with: match.range(at: 1))
                            if let code = UInt32(hexStr, radix: 16), let scalar = UnicodeScalar(code) {
                                text = (text as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                            }
                        }
                    }
                }
            }
        }
        
        // Collapse excess whitespace using precompiled regexes
        if let r = Self.whitespaceRegex {
            let ns = text as NSString
            text = r.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: ns.length), withTemplate: " ")
        }
        if let r = Self.excessNewlinesRegex {
            let ns = text as NSString
            text = r.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: ns.length), withTemplate: "\n\n")
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
