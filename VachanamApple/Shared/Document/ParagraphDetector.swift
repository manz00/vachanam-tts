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
    public let pageRange: NSRange?
    
    public init(text: String, bounds: CGRect, pageIndex: Int, pageRange: NSRange? = nil) {
        self.text = text
        self.bounds = bounds
        self.pageIndex = pageIndex
        self.pageRange = pageRange
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
    
    public var characterRange: NSRange? {
        let validRanges = lines.compactMap { $0.pageRange }.filter { $0.location != NSNotFound }
        guard let first = validRanges.first else { return nil }
        let minLoc = validRanges.map { $0.location }.min() ?? first.location
        let maxEnd = validRanges.map { $0.location + $0.length }.max() ?? (first.location + first.length)
        return NSRange(location: minLoc, length: max(0, maxEnd - minLoc))
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
                    // Check if current line is an exponent or superscript attached to previous line (e.g. A followed by -1, T, ⊤, or 2)
                    let isSuperscriptExponent = (lineText == "−1" || lineText == "-1" || lineText == "T" || lineText == "⊤" || lineText == "2" || lineText == "3") &&
                        (result.hasSuffix("A") || result.hasSuffix("B") || result.hasSuffix("C") || result.hasSuffix("D") ||
                         result.hasSuffix("M") || result.hasSuffix("X") || result.hasSuffix("W") || result.hasSuffix(")") || result.hasSuffix("]"))
                    
                    if isSuperscriptExponent {
                        result += lineText
                    } else if lineText.hasPrefix(",") || lineText.hasPrefix(";") {
                        // Avoid double space before comma or semicolon (e.g. matrix followed by ", equation (2.4)")
                        result += lineText
                    } else {
                        // Check if previous line is on the same horizontal baseline as current line (e.g. bold lead-in heading)
                        let prevLine = lines[i - 1]
                        let currLine = lines[i]
                        let isSameBaseline = abs(prevLine.bounds.midY - currLine.bounds.midY) < 4.0 && currLine.bounds.minX >= (prevLine.bounds.maxX - 2.0)
                        if isSameBaseline {
                            let prevTrimmed = prevLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
                            let words = prevTrimmed.split(whereSeparator: { $0.isWhitespace })
                            let endsWithPunctuation = prevTrimmed.hasSuffix(".") || prevTrimmed.hasSuffix(":") || prevTrimmed.hasSuffix(";") || prevTrimmed.hasSuffix("!") || prevTrimmed.hasSuffix("?") || prevTrimmed.hasSuffix("—")
                            let endsWithMathOrContinuation = prevTrimmed.hasSuffix("→") || prevTrimmed.hasSuffix("⟶") || prevTrimmed.hasSuffix("+") || prevTrimmed.hasSuffix("=") || prevTrimmed.hasSuffix("-") || prevTrimmed.hasSuffix(",") || prevTrimmed.hasSuffix("(")
                            let isTitleCased = words.count > 0 && words.allSatisfy { w in
                                guard let first = w.first else { return false }
                                return first.isUppercase || first.isNumber
                            }
                            if words.count <= 6 && !endsWithPunctuation && !endsWithMathOrContinuation && isTitleCased {
                                result += ". " + lineText
                            } else {
                                result += " " + lineText
                            }
                        } else {
                            result += " " + lineText
                        }
                    }
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
    /// Groups ordered visual lines on a page into semantic paragraphs and blocks,
    /// with intelligent separation of margin notes (sidenotes) from main body text.
    public func detectParagraphs(
        from lines: [VisualLine],
        pageIndex: Int,
        pageBounds: CGRect = .zero,
        analysis: PageFurnitureDetector.DocumentAnalysis? = nil
    ) -> [RawParagraph] {
        guard !lines.isEmpty else { return [] }
        
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
        
        let isNotationPage = analysis?.notationPages.contains(pageIndex) == true
        let defaultBodyType: BlockType = isNotationPage ? .symbolTable : .paragraph
        
        // Detect if the page has a separate margin column (sidenotes / marginalia)
        if let marginInfo = detectMarginColumn(lines: lines, pageBounds: pageBounds, analysis: analysis, medianHeight: medianHeight) {
            let marginLines: [VisualLine]
            if marginInfo.isLeft {
                marginLines = lines.filter { line in
                    line.bounds.maxX <= marginInfo.splitX &&
                    PageFurnitureDetector.shared.classifyLine(line: line, pageBounds: pageBounds, analysis: analysis, medianLineHeight: medianHeight) == nil
                }
            } else {
                marginLines = lines.filter { line in
                    line.bounds.minX >= marginInfo.splitX &&
                    PageFurnitureDetector.shared.classifyLine(line: line, pageBounds: pageBounds, analysis: analysis, medianLineHeight: medianHeight) == nil
                }
            }
            
            let marginLineIDs = Set(marginLines.map { $0.id })
            let mainLines = lines.filter { !marginLineIDs.contains($0.id) }
            
            let mainBlocks = groupLines(
                lines: mainLines,
                pageIndex: pageIndex,
                pageBounds: pageBounds,
                analysis: analysis,
                medianHeight: medianHeight,
                baseMargin: mainLines.map { $0.bounds.minX }.min() ?? baseMargin,
                defaultBlockType: defaultBodyType
            )
            
            let marginBlocks = groupLines(
                lines: marginLines,
                pageIndex: pageIndex,
                pageBounds: pageBounds,
                analysis: analysis,
                medianHeight: medianHeight,
                baseMargin: marginLines.map { $0.bounds.minX }.min() ?? baseMargin,
                defaultBlockType: .sidenote
            )
            
            return mainBlocks + marginBlocks
        }
        
        return groupLines(
            lines: lines,
            pageIndex: pageIndex,
            pageBounds: pageBounds,
            analysis: analysis,
            medianHeight: medianHeight,
            baseMargin: baseMargin,
            defaultBlockType: defaultBodyType
        )
    }
    
    private func detectMarginColumn(
        lines: [VisualLine],
        pageBounds: CGRect,
        analysis: PageFurnitureDetector.DocumentAnalysis?,
        medianHeight: CGFloat
    ) -> (isLeft: Bool, splitX: CGFloat)? {
        guard pageBounds.width > 100 else { return nil }
        let pageWidth = pageBounds.width
        
        // Filter out page furniture (headers, footers, page numbers)
        let contentLines = lines.filter { line in
            let f = PageFurnitureDetector.shared.classifyLine(
                line: line,
                pageBounds: pageBounds,
                analysis: analysis,
                medianLineHeight: medianHeight
            )
            return f == nil || f == .caption || f == .footnote
        }
        guard contentLines.count >= 4 else { return nil }
        
        // 1. Check for Left Margin column (e.g. MML page 18 notes/tips/video links)
        // Margin lines: maxX <= splitX, splitX in [0.22 * pageWidth, 0.45 * pageWidth]
        // Main body lines: minX >= (splitX - 10.0)
        let leftSplitCandidates = stride(from: pageWidth * 0.22, through: pageWidth * 0.45, by: 10.0)
        for splitX in leftSplitCandidates {
            // Strict gutter check: No lines should cross over the split boundary
            let crossingLines = contentLines.filter { $0.bounds.minX < (splitX - 15.0) && $0.bounds.maxX > (splitX + 15.0) }
            guard crossingLines.isEmpty else { continue }
            
            let marginCandidates = contentLines.filter { $0.bounds.maxX <= splitX }
            let bodyCandidates = contentLines.filter { $0.bounds.minX >= (splitX - 10.0) && $0.bounds.width >= (pageWidth * 0.35) }
            
            if marginCandidates.count >= 2 && bodyCandidates.count >= 2 {
                let marginMinXs = marginCandidates.map { $0.bounds.minX }
                let bodyMinXs = bodyCandidates.map { $0.bounds.minX }
                let marginBaseX = marginMinXs.sorted().first ?? 0
                let bodyBaseX = bodyMinXs.sorted().first ?? 0
                
                // Ensure distinct left baselines between margin and body columns
                guard (bodyBaseX - marginBaseX) >= (pageWidth * 0.15) else { continue }
                
                let avgMarginWidth = marginCandidates.reduce(0.0) { $0 + $1.bounds.width } / CGFloat(marginCandidates.count)
                if avgMarginWidth <= (pageWidth * 0.35) {
                    return (isLeft: true, splitX: splitX)
                }
            }
        }
        
        // 2. Check for Right Margin column
        let rightSplitCandidates = stride(from: pageWidth * 0.55, through: pageWidth * 0.85, by: 10.0)
        for splitX in rightSplitCandidates {
            // Strict gutter check: No lines should cross over the split boundary
            let crossingLines = contentLines.filter { $0.bounds.minX < (splitX - 15.0) && $0.bounds.maxX > (splitX + 15.0) }
            guard crossingLines.isEmpty else { continue }
            
            let bodyCandidates = contentLines.filter { $0.bounds.maxX <= (splitX + 5.0) && $0.bounds.width >= (pageWidth * 0.35) }
            let marginCandidates = contentLines.filter { $0.bounds.minX >= splitX }
            
            if marginCandidates.count >= 2 && bodyCandidates.count >= 2 {
                let bodyMaxXs = bodyCandidates.map { $0.bounds.maxX }
                let marginMinXs = marginCandidates.map { $0.bounds.minX }
                let bodyMaxX = bodyMaxXs.max() ?? 0
                let marginBaseX = marginMinXs.sorted().first ?? 0
                
                // Ensure distinct gutter between body right edge and margin left edge
                guard (marginBaseX - bodyMaxX) >= 6.0 else { continue }
                guard splitX >= (bodyMaxX - 2.0) else { continue }
                
                let avgMarginWidth = marginCandidates.reduce(0.0) { $0 + $1.bounds.width } / CGFloat(marginCandidates.count)
                if avgMarginWidth <= (pageWidth * 0.35) {
                    return (isLeft: false, splitX: splitX)
                }
            }
        }
        
        return nil
    }
    
    private func groupLines(
        lines: [VisualLine],
        pageIndex: Int,
        pageBounds: CGRect,
        analysis: PageFurnitureDetector.DocumentAnalysis?,
        medianHeight: CGFloat,
        baseMargin: CGFloat,
        defaultBlockType: BlockType
    ) -> [RawParagraph] {
        guard !lines.isEmpty else { return [] }
        
        var blocks: [RawParagraph] = []
        var currentBlockLines: [VisualLine] = []
        var currentBlockType: BlockType = defaultBlockType
        var currentBlockLevel: Int = 1
        var currentBlockMarker: String? = nil
        
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
            currentBlockType = defaultBlockType
            currentBlockLevel = 1
            currentBlockMarker = nil
        }
        
        for i in 0..<lines.count {
            let currentLine = lines[i]
            let trimmed = currentLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                flushCurrentBlock()
                continue
            }
            
            // Publication notices & disclaimers (e.g. Cambridge University Press / arXiv / copyright)
            // must be isolated immediately into .pageFooter and never merged into narrative body paragraphs.
            if PageFurnitureDetector.shared.isPublicationDisclaimer(trimmed) {
                flushCurrentBlock()
                blocks.append(RawParagraph(
                    lines: [currentLine],
                    pageIndex: pageIndex,
                    blockType: .pageFooter,
                    level: 1,
                    marker: nil
                ))
                continue
            }
            
            // A line starting with a lowercase letter is a grammatical continuation of the preceding text
            // and should never be broken into standalone page furniture.
            let startsWithLowercase = trimmed.first?.isLowercase == true
            
            // Check if current line continues an incomplete sentence from the current block at normal line spacing
            let isSentenceContinuation: Bool
            if let previousLine = currentBlockLines.last {
                let verticalGap = previousLine.bounds.minY - currentLine.bounds.maxY
                let prevTrimmed = previousLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let prevHasTerminalPunctuation = prevTrimmed.hasSuffix(".") || prevTrimmed.hasSuffix("?") || prevTrimmed.hasSuffix("!")
                isSentenceContinuation = (verticalGap <= medianHeight * 1.8) && !prevHasTerminalPunctuation
            } else {
                isSentenceContinuation = false
            }
            
            // Check for page furniture (headers, footers, page numbers, captions, footnotes)
            if !startsWithLowercase, let furnitureType = PageFurnitureDetector.shared.classifyLine(
                line: currentLine,
                pageBounds: pageBounds,
                analysis: analysis,
                medianLineHeight: medianHeight
            ) {
                // If this line is a continuation of an incomplete sentence from the current block at normal line spacing,
                // and NOT a publication disclaimer or page number, it is narrative text and must not be broken into standalone page furniture.
                let isDisclaimer = PageFurnitureDetector.shared.isPublicationDisclaimer(trimmed)
                if isSentenceContinuation && (furnitureType == .pageHeader || furnitureType == .pageFooter) && !isDisclaimer {
                    // Fall through to regular block accumulation
                } else {
                    flushCurrentBlock()
                    blocks.append(RawParagraph(
                        lines: [currentLine],
                        pageIndex: pageIndex,
                        blockType: furnitureType,
                        level: 1,
                        marker: nil
                    ))
                    continue
                }
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
            if currentBlockType == .listItem, let previousLine = currentBlockLines.last, let firstLine = currentBlockLines.first {
                let verticalGap = previousLine.bounds.minY - currentLine.bounds.maxY
                let isNormalSpacing = verticalGap <= (medianHeight * 1.6)
                let isIndentedOrFlowing = currentLine.bounds.minX >= (firstLine.bounds.minX - 10.0)
                
                if isNormalSpacing && isIndentedOrFlowing {
                    currentBlockLines.append(currentLine)
                    continue
                } else {
                    flushCurrentBlock()
                }
            }
            
            // Handle regular paragraph or quote accumulation
            if currentBlockLines.isEmpty {
                let isIndentedQuote = currentLine.bounds.minX > (baseMargin + medianHeight * 2.0)
                currentBlockType = isIndentedQuote ? .quote : defaultBlockType
                currentBlockLines.append(currentLine)
                continue
            }
            
            let previousLine = currentBlockLines.last!
            let verticalGap = previousLine.bounds.minY - currentLine.bounds.maxY
            
            let prevTrimmed = previousLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let currTrimmed = currentLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let hasTerminalPunctuation = prevTrimmed.hasSuffix(".") || prevTrimmed.hasSuffix("?") || prevTrimmed.hasSuffix("!") || prevTrimmed.hasSuffix(":") || prevTrimmed.hasSuffix("—") || prevTrimmed.hasSuffix("\"") || prevTrimmed.hasSuffix("”") || prevTrimmed.hasSuffix(")")
            
            // Check if either line indicates that currentLine is an unbroken continuation (displayed math, formula, preposition, or clause)
            let continuationConjunctions = ["by", "with", "where", "for", "and", "or", "that", "is", "are", "as", "to", "then", "of", "in", "such", "than", "from", "equals", "defined", "given", "assume", "let"]
            let prevEndsWithContinuation = prevTrimmed.hasSuffix(",") || prevTrimmed.hasSuffix("=") || prevTrimmed.hasSuffix("+") ||
                prevTrimmed.hasSuffix("-") || prevTrimmed.hasSuffix("−") || prevTrimmed.hasSuffix("→") || prevTrimmed.hasSuffix("⟶") ||
                prevTrimmed.hasSuffix("(") || prevTrimmed.hasSuffix("[") || prevTrimmed.hasSuffix("{") ||
                continuationConjunctions.contains(where: { prevTrimmed.lowercased().hasSuffix(" \($0)") || prevTrimmed.lowercased() == $0 })
            
            let currStartsWithContinuation: Bool
            if let firstChar = currTrimmed.first {
                currStartsWithContinuation = firstChar.isLowercase ||
                    ["+", "-", "−", "=", "×", "÷", "·", "±", "…", "···", ",", ")", "]", "}", "→", "⟶"].contains(String(firstChar)) ||
                    currTrimmed.hasPrefix("...") || currTrimmed.hasPrefix("···") || currTrimmed.hasPrefix("…") ||
                    currTrimmed.hasPrefix("where ") || currTrimmed.hasPrefix("with ") || currTrimmed.hasPrefix("and ")
            } else {
                currStartsWithContinuation = false
            }
            
            let isSuperscriptOrFragment = currTrimmed == "−1" || currTrimmed == "-1" || currTrimmed == "T" || currTrimmed == "⊤" ||
                (currTrimmed.count <= 3 && (currTrimmed.hasPrefix("-") || currTrimmed.hasPrefix("−")))
            
            // Heuristics for paragraph break:
            // 1. Vertical gap is significantly larger than regular line spacing.
            // In LaTeX / academic typography, displayed equations have an above/below display skip (1.5x-2.0x line height).
            // A gap constitutes a true paragraph break only if:
            // - The previous line ended with terminal punctuation, OR
            // - The gap is an immense section gap (> 3.0x line height) and the line is not a math/clause continuation.
            let isLargeGap = (verticalGap > (medianHeight * 1.5) && hasTerminalPunctuation) ||
                             (verticalGap > (medianHeight * 3.0) && !prevEndsWithContinuation && !currStartsWithContinuation && !isSuperscriptOrFragment)
            
            // 2. Indentation check: Indented by at least 5pt from the column base margin or previous line
            let isIndented = (currentLine.bounds.minX >= (baseMargin + 5.0)) || (currentLine.bounds.minX >= (previousLine.bounds.minX + 5.0))
            
            // 3. Short terminal line check: The previous line ended well before the column right margin
            let columnMaxX = lines.map { $0.bounds.maxX }.max() ?? 400.0
            let isPreviousLineShort = previousLine.bounds.maxX < (columnMaxX - 25.0)
            
            let shouldBreakParagraph = !prevEndsWithContinuation && !currStartsWithContinuation && !isSuperscriptOrFragment &&
                (isLargeGap || (hasTerminalPunctuation && (isIndented || isPreviousLineShort)))
            
            if shouldBreakParagraph {
                flushCurrentBlock()
                let isIndentedQuote = currentLine.bounds.minX > (baseMargin + medianHeight * 2.0)
                currentBlockType = isIndentedQuote ? .quote : defaultBlockType
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
        
        // Headings must contain at least one alphabetic character (reject pure matrix rows or numbers like "1 1 -1")
        guard trimmedText.rangeOfCharacter(from: .letters) != nil else { return nil }
        
        // Headings must start with an uppercase letter, digit, or roman numeral
        guard let firstChar = trimmedText.first, firstChar.isLetter || firstChar.isNumber else { return nil }
        if firstChar.isLetter && firstChar.isLowercase { return nil }
        
        // Headings do not end with math operators, arrows, commas, or continuation conjunctions
        let badSuffixes = [",", ";", "-", "–", "—", "+", "=", "→", "⟶", "<", ">", "/", "\\", "(", "[", "{", "that", "and", "or", "of", "with", "to", "in", "for", "by"]
        let lowerTrimmed = trimmedText.lowercased()
        for suffix in badSuffixes {
            if lowerTrimmed.hasSuffix(suffix) {
                return nil
            }
        }
        
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
            } else if (trimmedText.lowercased().hasPrefix("chapter") || trimmedText.lowercased().hasPrefix("part")) && wordCount <= 6 {
                // Short standalone title lines like "Chapter 10: Dimensionality Reduction", not body sentences like "Chapter 10 focuses on..."
                let bodyVerbs = ["focuses", "introduces", "we", "is", "are", "shows", "will", "discusses", "restate", "provides"]
                let words = trimmedText.lowercased().components(separatedBy: .whitespaces)
                if !words.contains(where: { bodyVerbs.contains($0) }) {
                    return 1
                }
            } else if isLargeFont {
                return 2
            }
        }
        
        if isLargeFont && !endsWithSentencePunctuation {
            return 2
        }
        
        return nil
    }
}
