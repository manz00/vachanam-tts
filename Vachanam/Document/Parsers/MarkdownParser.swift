//
//  MarkdownParser.swift
//  Vachanam
//
//  Parses Markdown files into structured chapters and semantic blocks.
//

import Foundation

public struct MarkdownParser: DocumentParser {
    public init() {}
    
    public func parse(from source: DocumentSource) async throws -> ParsedDocument {
        let text: String
        let title: String
        
        switch source {
        case .fileURL(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw DocumentParserError.fileNotFound(url)
            }
            guard let data = try? Data(contentsOf: url) else {
                throw DocumentParserError.parsingFailed("Could not read Markdown file: \(url.lastPathComponent)")
            }
            text = PlainTextParser.decodeString(from: data)
            title = url.deletingPathExtension().lastPathComponent
        case .rawText(let rawText, let rawTitle):
            text = rawText
            title = rawTitle
        case .webURL:
            throw DocumentParserError.invalidSource("MarkdownParser requires a fileURL or rawText")
        }
        
        return parseMarkdownText(text, defaultTitle: title)
    }
    
    public func parseMarkdownText(_ text: String, defaultTitle: String) -> ParsedDocument {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var chapters: [ParsedChapter] = []
        var currentChapterTitle: String? = nil
        var currentBlocks: [ParsedBlock] = []
        var documentTitle: String? = nil
        
        var paragraphBuffer: [String] = []
        var inCodeBlock = false
        
        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            let combined = paragraphBuffer.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty {
                let clean = cleanInlineMarkdown(combined)
                currentBlocks.append(ParsedBlock(type: .paragraph, text: clean))
            }
            paragraphBuffer.removeAll()
        }
        
        func flushChapter() {
            flushParagraph()
            if !currentBlocks.isEmpty {
                let chapTitle = currentChapterTitle ?? (chapters.isEmpty ? defaultTitle : "Section \(chapters.count + 1)")
                chapters.append(ParsedChapter(title: chapTitle, blocks: currentBlocks))
                currentBlocks.removeAll()
            }
        }
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            
            // Fenced code blocks toggle
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // Ending code block
                    inCodeBlock = false
                    flushParagraph()
                } else {
                    // Starting code block
                    flushParagraph()
                    inCodeBlock = true
                }
                continue
            }
            
            if inCodeBlock {
                // Keep code content in paragraph buffer
                paragraphBuffer.append(rawLine)
                continue
            }
            
            // Setext-style headings (=== or --- under a paragraph line)
            if !paragraphBuffer.isEmpty && (line.range(of: #"^={3,}\s*$"#, options: .regularExpression) != nil || line.range(of: #"^-{3,}\s*$"#, options: .regularExpression) != nil) {
                let isLevel1 = line.hasPrefix("=")
                let headingText = paragraphBuffer.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                paragraphBuffer.removeAll()
                let cleanHeading = cleanInlineMarkdown(headingText)
                if isLevel1 {
                    if documentTitle == nil { documentTitle = cleanHeading }
                    flushChapter()
                    currentChapterTitle = cleanHeading
                    currentBlocks.append(ParsedBlock(type: .heading, text: cleanHeading, level: 1))
                } else {
                    currentBlocks.append(ParsedBlock(type: .heading, text: cleanHeading, level: 2))
                }
                continue
            }
            
            // Empty line separates paragraphs
            if line.isEmpty {
                flushParagraph()
                continue
            }
            
            // Headings
            if line.hasPrefix("#") {
                flushParagraph()
                let hashCount = line.prefix(while: { $0 == "#" }).count
                let headingText = line.dropFirst(hashCount).trimmingCharacters(in: .whitespaces)
                let cleanHeading = cleanInlineMarkdown(headingText)
                
                if hashCount == 1 {
                    // Level 1 heading: treat as chapter or doc title
                    if documentTitle == nil {
                        documentTitle = cleanHeading
                    }
                    flushChapter()
                    currentChapterTitle = cleanHeading
                    currentBlocks.append(ParsedBlock(type: .heading, text: cleanHeading, level: 1))
                } else {
                    currentBlocks.append(ParsedBlock(type: .heading, text: cleanHeading, level: hashCount))
                }
                continue
            }
            
            // Unordered list items (- , * , + )
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                flushParagraph()
                let itemText = cleanInlineMarkdown(String(line.dropFirst(2)))
                currentBlocks.append(ParsedBlock(type: .listItem, text: itemText, level: 1, marker: "•"))
                continue
            }
            
            // Ordered list items (e.g. 1. )
            if let match = line.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                flushParagraph()
                let marker = String(line[match]).trimmingCharacters(in: .whitespaces)
                let itemText = cleanInlineMarkdown(String(line[match.upperBound...]))
                currentBlocks.append(ParsedBlock(type: .listItem, text: itemText, level: 1, marker: marker))
                continue
            }
            
            // Blockquotes (> )
            if line.hasPrefix(">") {
                flushParagraph()
                let quoteText = cleanInlineMarkdown(line.dropFirst().trimmingCharacters(in: .whitespaces))
                currentBlocks.append(ParsedBlock(type: .quote, text: quoteText, level: 1))
                continue
            }
            
            // Normal paragraph line
            paragraphBuffer.append(line)
        }
        
        flushChapter()
        
        if chapters.isEmpty {
            chapters.append(ParsedChapter(title: defaultTitle, blocks: [
                ParsedBlock(type: .paragraph, text: cleanInlineMarkdown(text))
            ]))
        }
        
        return ParsedDocument(
            title: documentTitle ?? defaultTitle,
            author: nil,
            format: .markdown,
            chapters: chapters
        )
    }
    
    private func cleanInlineMarkdown(_ md: String) -> String {
        var text = md
        // Remove bold/italic markers (**word**, *word*, __word__, _word_)
        text = text.replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "__(.*?)__", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\*(.*?)\\*", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "_(.*?)_", with: "$1", options: .regularExpression)
        // Remove inline code ticks (`code` -> code)
        text = text.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        // Markdown links: [title](url) -> title
        text = text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]+\\)", with: "$1", options: .regularExpression)
        // Strikethrough: ~~word~~ -> word
        text = text.replacingOccurrences(of: "~~(.*?)~~", with: "$1", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
