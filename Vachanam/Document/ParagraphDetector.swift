//
//  ParagraphDetector.swift
//  Vachanam
//
//  Groups extracted visual lines and text blocks into coherent logical paragraphs
//  using vertical spacing, margin alignments, and typographic heuristics.
//

import Foundation
import CoreGraphics

public struct VisualLine: Identifiable {
    public let id = UUID()
    public let text: String
    public let bounds: CGRect
    public let pageIndex: Int
    
    public init(text: String, bounds: CGRect, pageIndex: Int) {
        self.text = text
        self.bounds = bounds
        self.pageIndex = pageIndex
    }
}

public struct RawParagraph {
    public let lines: [VisualLine]
    public let pageIndex: Int
    public let blockType: BlockType
    public let level: Int
    public let marker: String?
    
    public init(
        lines: [VisualLine],
        pageIndex: Int,
        blockType: BlockType = .paragraph,
        level: Int = 1,
        marker: String? = nil
    ) {
        self.lines = lines
        self.pageIndex = pageIndex
        self.blockType = blockType
        self.level = level
        self.marker = marker
    }
    
    public var bounds: CGRect {
        guard let first = lines.first?.bounds else { return .zero }
        return lines.dropFirst().reduce(first) { $0.union($1.bounds) }
    }
    
    public var combinedText: String {
        guard !lines.isEmpty else { return "" }
        var result = ""
        let wordReconstructor = WordReconstructor.shared
        
        for i in 0..<lines.count {
            let lineText = lines[i].text.trimmingCharacters(in: .whitespaces)
            guard !lineText.isEmpty else { continue }
            
            if result.isEmpty {
                result = lineText
            } else {
                // Check if previous line ended with a hyphen
                if (result.hasSuffix("-") || result.hasSuffix("\u{2010}") || result.hasSuffix("\u{2011}")),
                   let lastWord = result.components(separatedBy: .whitespaces).last,
                   let firstWordNextLine = lineText.components(separatedBy: .whitespaces).first {
                    
                    let resolved = wordReconstructor.resolveHyphenation(
                        firstPart: lastWord,
                        secondPart: firstWordNextLine
                    )
                    
                    // Replace the last word in result
                    let dropCount = lastWord.count
                    let prefixResult = String(result.dropLast(dropCount)).trimmingCharacters(in: .whitespaces)
                    let remainingNextLine = lineText.dropFirst(firstWordNextLine.count).trimmingCharacters(in: .whitespaces)
                    
                    let combinedLinePart: String
                    if prefixResult.isEmpty {
                        combinedLinePart = resolved.reconstructedWord
                    } else {
                        combinedLinePart = prefixResult + " " + resolved.reconstructedWord
                    }
                    
                    if remainingNextLine.isEmpty {
                        result = combinedLinePart
                    } else {
                        result = combinedLinePart + " " + remainingNextLine
                    }
                } else {
                    result += " " + lineText
                }
            }
        }
        return result
    }
}

public class ParagraphDetector {
    public static let shared = ParagraphDetector()
    
    private static let bulletRegex = try? NSRegularExpression(
        pattern: #"^([\u2022\u25E6\u25AA\u25AB\u2013\u2014\*\+\u203A\u00BB]|\-)\s+"#,
        options: []
    )
    
    private static let numberedListRegex = try? NSRegularExpression(
        pattern: #"^(\d{1,3}[\.\)]|\([0-9a-zA-Z]{1,3}\)|[a-zA-Z][\.\)]|[ivxlcdmIVXLCDM]{1,6}[\.\)])\s+"#,
        options: []
    )
    
    private static let headingNumberingRegex = try? NSRegularExpression(
        pattern: #"^(chapter\s+\d+|section\s+\d+|part\s+\d+|appendix\s+[a-z]|\d+(\.\d+)+)\b"#,
        options: [.caseInsensitive]
    )
    
    private static let romanNumeralHeadingRegex = try? NSRegularExpression(
        pattern: #"^(I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s+"#,
        options: []
    )
    
    public init() {}
    
    /// Groups ordered visual lines on a page into semantic paragraphs and blocks.
    public func detectParagraphs(from lines: [VisualLine], pageIndex: Int) -> [RawParagraph] {
        guard !lines.isEmpty else { return [] }
        
        var blocks: [RawParagraph] = []
        var currentBlockLines: [VisualLine] = []
        var currentBlockType: BlockType = .paragraph
        var currentBlockLevel: Int = 1
        var currentBlockMarker: String? = nil
        
        // Calculate median line height for baseline spacing comparisons
        let lineHeights = lines.map { $0.bounds.height }.filter { $0 > 0 }
        let medianHeight: CGFloat
        if !lineHeights.isEmpty {
            let sorted = lineHeights.sorted()
            medianHeight = sorted[sorted.count / 2]
        } else {
            medianHeight = 14.0
        }
        
        // Find baseline left margin
        let minXs = lines.map { $0.bounds.minX }.filter { $0 > 0 }
        let baseMargin: CGFloat = minXs.isEmpty ? 50.0 : (minXs.sorted().first ?? 50.0)
        
        func flushCurrentBlock() {
            guard !currentBlockLines.isEmpty else { return }
            blocks.append(RawParagraph(
                lines: currentBlockLines,
                pageIndex: pageIndex,
                blockType: currentBlockType,
                level: currentBlockLevel,
                marker: currentBlockMarker
            ))
            currentBlockLines.removeAll()
            currentBlockType = .paragraph
            currentBlockLevel = 1
            currentBlockMarker = nil
        }
        
        for i in 0..<lines.count {
            let currentLine = lines[i]
            let trimmed = currentLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                // Empty line forces block break
                flushCurrentBlock()
                continue
            }
            
            // Check for list item
            if let (marker, _) = detectListMarker(in: trimmed) {
                flushCurrentBlock()
                let indentLevel = max(0, Int(round((currentLine.bounds.minX - baseMargin) / max(12.0, medianHeight * 1.2))))
                currentBlockLines = [currentLine]
                currentBlockType = .listItem
                currentBlockLevel = indentLevel
                currentBlockMarker = marker
                continue
            }
            
            // Check for heading
            if let headingLevel = detectHeading(line: currentLine, trimmedText: trimmed, medianHeight: medianHeight) {
                flushCurrentBlock()
                // Headings are always standalone units!
                blocks.append(RawParagraph(
                    lines: [currentLine],
                    pageIndex: pageIndex,
                    blockType: .heading,
                    level: headingLevel,
                    marker: nil
                ))
                continue
            }
            
            // If current block is a list item, check if this line is a continuation line
            if currentBlockType == .listItem, let previousLine = currentBlockLines.last {
                let verticalGap = previousLine.bounds.minY - currentLine.bounds.maxY
                let isNormalSpacing = verticalGap <= (medianHeight * 1.4)
                let isIndentedOrFlowing = currentLine.bounds.minX >= (previousLine.bounds.minX - 4.0)
                
                if isNormalSpacing && isIndentedOrFlowing {
                    currentBlockLines.append(currentLine)
                    continue
                } else {
                    // List item finished, start regular paragraph
                    flushCurrentBlock()
                }
            }
            
            // Handle regular paragraph or quote accumulation
            if currentBlockLines.isEmpty {
                let isIndentedQuote = currentLine.bounds.minX > (baseMargin + medianHeight * 2.0)
                currentBlockType = isIndentedQuote ? .quote : .paragraph
                currentBlockLines.append(currentLine)
                continue
            }
            
            let previousLine = currentBlockLines.last!
            let verticalGap = previousLine.bounds.minY - currentLine.bounds.maxY
            
            // Heuristics for paragraph break:
            // 1. Vertical gap is significantly larger than regular line spacing
            let isLargeGap = verticalGap > (medianHeight * 1.5)
            
            // 2. Previous line ended with terminal punctuation and current line has noticeable left indent
            let prevTrimmed = previousLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasTerminalPunctuation = prevTrimmed.hasSuffix(".") || prevTrimmed.hasSuffix("?") || prevTrimmed.hasSuffix("!")
            let hasIndent = currentLine.bounds.minX > (previousLine.bounds.minX + medianHeight * 1.2)
            
            if isLargeGap || (hasTerminalPunctuation && hasIndent) {
                flushCurrentBlock()
                let isIndentedQuote = currentLine.bounds.minX > (baseMargin + medianHeight * 2.0)
                currentBlockType = isIndentedQuote ? .quote : .paragraph
                currentBlockLines = [currentLine]
            } else {
                currentBlockLines.append(currentLine)
            }
        }
        
        flushCurrentBlock()
        return blocks
    }
    
    // MARK: - Marker & Heading Detection
    
    private func detectListMarker(in text: String) -> (marker: String, isNumbered: Bool)? {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: min(nsText.length, 25))
        
        if let bRegex = Self.bulletRegex,
           let match = bRegex.firstMatch(in: text, options: [], range: fullRange) {
            let marker = nsText.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            return (marker, false)
        }
        
        if let nRegex = Self.numberedListRegex,
           let match = nRegex.firstMatch(in: text, options: [], range: fullRange) {
            let marker = nsText.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            return (marker, true)
        }
        
        return nil
    }
    
    private func detectHeading(line: VisualLine, trimmedText: String, medianHeight: CGFloat) -> Int? {
        let wordCount = trimmedText.split(whereSeparator: { $0.isWhitespace }).count
        guard wordCount > 0 && wordCount <= 14 else { return nil }
        
        let nsText = trimmedText as NSString
        let searchRange = NSRange(location: 0, length: min(nsText.length, 30))
        
        let hasHeadingPrefix = (Self.headingNumberingRegex?.firstMatch(in: trimmedText, options: [], range: searchRange) != nil) ||
                               (Self.romanNumeralHeadingRegex?.firstMatch(in: trimmedText, options: [], range: searchRange) != nil)
        
        // Font size heuristic
        let isLargeFont = line.bounds.height >= (medianHeight * 1.22)
        let isVeryLargeFont = line.bounds.height >= (medianHeight * 1.48)
        
        // Headings rarely end with a period, question mark, or exclamation point
        let endsWithSentencePunctuation = trimmedText.hasSuffix(".") || trimmedText.hasSuffix("?") || trimmedText.hasSuffix("!")
        
        if isVeryLargeFont && !endsWithSentencePunctuation {
            return 1
        }
        
        if hasHeadingPrefix {
            if isLargeFont {
                return 1
            } else if trimmedText.lowercased().hasPrefix("chapter") || trimmedText.lowercased().hasPrefix("part") {
                return 1
            } else {
                return 2
            }
        }
        
        if isLargeFont && !endsWithSentencePunctuation {
            return 2
        }
        
        return nil
    }
}
