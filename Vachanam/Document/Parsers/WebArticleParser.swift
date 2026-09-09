//
//  WebArticleParser.swift
//  Vachanam
//
//  Fetches web pages and extracts reader-friendly article content into ParsedDocument models.
//

import Foundation

public struct WebArticleParser: DocumentParser {
    public init() {}
    
    public func parse(from source: DocumentSource) async throws -> ParsedDocument {
        let html: String
        let defaultTitle: String
        
        switch source {
        case .webURL(let url):
            var request = URLRequest(url: url)
            request.timeoutInterval = 20.0
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw DocumentParserError.networkError("Invalid HTTP response")
                }
                html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
                defaultTitle = url.host ?? "Web Article"
            } catch {
                throw DocumentParserError.networkError(error.localizedDescription)
            }
            
        case .rawText(let rawHTML, let rawTitle):
            html = rawHTML
            defaultTitle = rawTitle
            
        case .fileURL(let url):
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                throw DocumentParserError.fileNotFound(url)
            }
            html = content
            defaultTitle = url.deletingPathExtension().lastPathComponent
        }
        
        return parseHTMLArticle(html, defaultTitle: defaultTitle)
    }
    
    public func parseHTMLArticle(_ html: String, defaultTitle: String) -> ParsedDocument {
        // 1. Extract metadata
        let extractedTitle = extractTagContent(from: html, tag: "title")
        let cleanTitle: String = {
            if let t = extractedTitle, !t.isEmpty {
                // Often titles are "Article Name | Site Name", strip site name
                return t.components(separatedBy: " | ").first ?? t.components(separatedBy: " - ").first ?? t
            }
            return defaultTitle
        }()
        
        let author = extractMetaContent(from: html, name: "author")
            ?? extractMetaContent(from: html, property: "article:author")
        
        // 2. Remove scripts, styles, navigation, headers, footers
        var sanitized = html
        let tagsToRemove = ["script", "style", "nav", "header", "footer", "aside", "svg", "noscript", "iframe"]
        for tag in tagsToRemove {
            let pattern = "(?is)<" + tag + ".*?</" + tag + ">"
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 3. Extract article or main content if available
        let mainContent: String = {
            if let articleMatch = extractTagHTML(from: sanitized, tag: "article") {
                return articleMatch
            }
            if let mainMatch = extractTagHTML(from: sanitized, tag: "main") {
                return mainMatch
            }
            return sanitized
        }()
        
        // 4. Extract blocks
        let epubParser = EPUBParser()
        let blocks = epubParser.parseHTMLBlocks(from: mainContent)
        
        let chapter = ParsedChapter(title: cleanTitle, blocks: blocks.isEmpty ? [
            ParsedBlock(type: .paragraph, text: cleanHTMLText(sanitized))
        ] : blocks)
        
        return ParsedDocument(
            title: cleanTitle,
            author: author,
            format: .webArticle,
            chapters: [chapter]
        )
    }
    
    // MARK: - Helpers
    
    private func extractTagContent(from html: String, tag: String) -> String? {
        let pattern = "<" + tag + "[^>]*>(.*?)</" + tag + ">"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let ns = html as NSString
        if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges >= 2 {
            return cleanHTMLText(ns.substring(with: match.range(at: 1)))
        }
        return nil
    }
    
    private func extractTagHTML(from html: String, tag: String) -> String? {
        let pattern = "(?is)<" + tag + "[^>]*>.*?</" + tag + ">"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = html as NSString
        if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) {
            return ns.substring(with: match.range)
        }
        return nil
    }
    
    private func extractMetaContent(from html: String, name: String? = nil, property: String? = nil) -> String? {
        let attr = name != nil ? "name=['\"]\(name!)['\"]" : "property=['\"]\(property!)['\"]"
        let pattern = "<meta\\s+[^>]*" + attr + "[^>]*content=['\"]([^'\"]+)['\"][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = html as NSString
        if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges >= 2 {
            return cleanHTMLText(ns.substring(with: match.range(at: 1)))
        }
        return nil
    }
    
    private func cleanHTMLText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&mdash;": "—",
            "&ndash;": "–"
        ]
        for (ent, rep) in entities {
            text = text.replacingOccurrences(of: ent, with: rep)
        }
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
