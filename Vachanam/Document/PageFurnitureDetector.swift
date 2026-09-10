//
//  PageFurnitureDetector.swift
//  Vachanam
//
//  Intelligently detects and classifies repetitive or non-narrative page furniture:
//  running headers, running footers, page numbers, figure/table captions, and footnotes.
//

import Foundation
import CoreGraphics

public struct PageFurnitureDetector: Sendable {
    public static let shared = PageFurnitureDetector()
    
    public struct Configuration: Sendable {
        /// Top percentage of page height considered the header band (default: 0.88 to 1.0, i.e. top 12%)
        public var headerBandYRatio: CGFloat
        /// Bottom percentage of page height considered the footer band (default: 0.0 to 0.10, i.e. bottom 10%)
        public var footerBandYRatio: CGFloat
        /// Extended bottom percentage for multi-line footnotes (default: bottom 22%)
        public var footnoteBandYRatio: CGFloat
        /// Minimum page appearances for a string to be considered a recurring running header/footer
        public var minRepetitionCount: Int
        
        public init(
            headerBandYRatio: CGFloat = 0.88,
            footerBandYRatio: CGFloat = 0.10,
            footnoteBandYRatio: CGFloat = 0.22,
            minRepetitionCount: Int = 2
        ) {
            self.headerBandYRatio = headerBandYRatio
            self.footerBandYRatio = footerBandYRatio
            self.footnoteBandYRatio = footnoteBandYRatio
            self.minRepetitionCount = minRepetitionCount
        }
    }
    
    public struct DocumentAnalysis: Sendable {
        /// Normalized texts identified as running headers across multiple pages
        public let recurringHeaders: Set<String>
        /// Normalized texts identified as running footers across multiple pages
        public let recurringFooters: Set<String>
        /// Page indices identified as Notation / Table of Symbols pages
        public let notationPages: Set<Int>
        
        public init(
            recurringHeaders: Set<String> = [],
            recurringFooters: Set<String> = [],
            notationPages: Set<Int> = []
        ) {
            self.recurringHeaders = recurringHeaders
            self.recurringFooters = recurringFooters
            self.notationPages = notationPages
        }
    }
    
    public let config: Configuration
    
    // MARK: - Regex Patterns
    
    private static let pageNumberRegexes: [NSRegularExpression] = {
        let patterns = [
            #"^\s*\d{1,4}\s*$"#,                                              // "42"
            #"^\s*Page\s+\d{1,4}(?:\s+(?:of|\/)\s+\d{1,4})?\s*$"#,          // "Page 5" or "Page 5 of 20"
            #"^\s*[-–—\[\(]\s*\d{1,4}\s*[-–—\]\)]\s*$"#,                    // "- 42 -" or "[42]" or "(42)"
            #"^\s*[ivxlcdmIVXLCDM]{1,6}\s*$"#,                               // "iv", "xii", "III"
            #"^\s*\d{1,3}\s*[-–]\s*\d{1,3}\s*$"#,                            // "1-12", "4-2"
            #"^\s*(?:chapter|section)\s+\d{1,3}\s*[-–]\s*\d{1,3}\s*$"#       // "Chapter 1 - 5"
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()
    
    private static let captionRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"^\s*(?:Figure|Fig\.|Table|Plate|Chart|Photo|Illustration|Map)\s+\d+[\.:]"#,
            options: [.caseInsensitive]
        )
    }()
    
    private static let footnoteMarkerRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"^\s*(?:[\*†‡§#]|\d{1,2}[\.\)]|\(\d{1,2}\)|\[\d{1,2}\])\s+"#,
            options: []
        )
    }()
    
    public static let publicationDisclaimerRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"(?:published by|university press|all rights reserved|pre-publication|personal use only|not for re-distribution|copyright|\(c\)|©|downloaded from|free to view|commercial products|arxiv:\d|doi:10\.|draft\s*\(|feedback:|mml-book|working draft|preliminary version|not for distribution|sample chapter)"#,
            options: [.caseInsensitive]
        )
    }()
    
    private static let notationHeadingRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"^\s*(?:notation|table of symbols|list of symbols|mathematical notation|summary of notation|symbols and notation|conventions)\b"#,
            options: [.caseInsensitive]
        )
    }()
    
    public init(config: Configuration = Configuration()) {
        self.config = config
    }
    
    // MARK: - Whole-Document Analysis (Two-Pass Detection)
    
    /// Analyzes visual lines across all pages of a document to find repetitive running headers & footers
    /// as well as special Notation / Table of Symbols pages.
    public func analyzeDocument(
        linesByPage: [Int: [VisualLine]],
        pageBounds: [Int: CGRect]
    ) -> DocumentAnalysis {
        var headerOccurrences: [String: Set<Int>] = [:]
        var footerOccurrences: [String: Set<Int>] = [:]
        var notationPages: Set<Int> = []
        
        for (pageIndex, lines) in linesByPage {
            guard let bounds = pageBounds[pageIndex], bounds.height > 0 else { continue }
            let pageHeight = bounds.height
            let pageMinY = bounds.minY
            
            for line in lines {
                let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                let relY = (line.bounds.midY - pageMinY) / pageHeight
                
                // Check for Notation / Table of Symbols headings in upper 40% of page
                if relY >= 0.60, let regex = Self.notationHeadingRegex {
                    let range = NSRange(location: 0, length: (trimmed as NSString).length)
                    if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                        notationPages.insert(pageIndex)
                    }
                }
                
                // Skip standalone page numbers from repetition map (they vary per page anyway)
                if isPageNumber(trimmed) {
                    continue
                }
                
                let normalized = normalizeForComparison(trimmed)
                guard !normalized.isEmpty else { continue }
                
                if relY >= config.headerBandYRatio {
                    headerOccurrences[normalized, default: []].insert(pageIndex)
                } else if relY <= config.footerBandYRatio {
                    footerOccurrences[normalized, default: []].insert(pageIndex)
                }
            }
        }
        
        let minCount = max(2, config.minRepetitionCount)
        let recurringHeaders = Set(headerOccurrences.filter { $0.value.count >= minCount }.map { $0.key })
        let recurringFooters = Set(footerOccurrences.filter { $0.value.count >= minCount }.map { $0.key })
        
        return DocumentAnalysis(
            recurringHeaders: recurringHeaders,
            recurringFooters: recurringFooters,
            notationPages: notationPages
        )
    }
    
    // MARK: - Single Line Classification
    
    /// Classifies a visual line into a BlockType if it represents page furniture (header, footer, page number, caption, footnote),
    /// or returns nil if it is normal body text or heading.
    public func classifyLine(
        line: VisualLine,
        pageBounds: CGRect,
        analysis: DocumentAnalysis? = nil,
        medianLineHeight: CGFloat = 14.0
    ) -> BlockType? {
        let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // 1. Figure and Table captions (geometry-independent)
        if isCaption(trimmed) {
            return .caption
        }
        
        guard pageBounds.height > 0 else {
            if line.text.count <= 15 && isPageNumber(trimmed) {
                return .pageNumber
            }
            return nil
        }
        let relY = (line.bounds.midY - pageBounds.minY) / pageBounds.height
        let inHeaderZone = relY >= config.headerBandYRatio
        let inFooterZone = relY <= config.footerBandYRatio
        let inFootnoteZone = relY <= config.footnoteBandYRatio
        
        // 1. Page numbers (highest priority in header or footer bands)
        if (inHeaderZone || inFooterZone) && isPageNumber(trimmed) {
            return .pageNumber
        }
        
        // 2. Figure and Table captions
        if isCaption(trimmed) {
            return .caption
        }
        
        // 3. Footnotes (requires footnote marker like *, †, 1., etc.)
        if inFootnoteZone && isFootnote(line: line, trimmedText: trimmed, medianHeight: medianLineHeight) {
            return .footnote
        }
        
        // 4. Publication notices & disclaimers (e.g. Cambridge University Press / arXiv / copyright)
        // Disclaimers are never narrative body text regardless of vertical line position
        if isPublicationDisclaimer(trimmed) {
            return .pageFooter
        }
        
        let hasTerminalPunctuation = trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")
        
        // Large fonts are headings, not running page headers
        if line.bounds.height > medianLineHeight * 1.25 {
            return nil
        }
        
        // 5. Cross-page recurring headers or explicit running header patterns
        let normalized = normalizeForComparison(trimmed)
        if inHeaderZone {
            if let analysis = analysis, analysis.recurringHeaders.contains(normalized) {
                return .pageHeader
            }
            let isAllCapsHeader = trimmed == trimmed.uppercased() && trimmed.count < 60 && trimmed.rangeOfCharacter(from: .letters) != nil
            let isHeaderPattern = trimmed.range(of: #"(?:chapter|section|part|manual)\b"#, options: [.caseInsensitive, .regularExpression]) != nil ||
                                  trimmed.contains(" — ") || trimmed.contains(" – ") || trimmed.contains(" | ")
            let hasLeadingOrTrailingPageNumber = trimmed.range(of: #"^\s*(?:[ivxlcdmIVXLCDM]+|\d{1,4})\s+[A-Za-z]"#, options: .regularExpression) != nil ||
                                                 trimmed.range(of: #"[A-Za-z]\s+(?:[ivxlcdmIVXLCDM]+|\d{1,4})\s*$"#, options: .regularExpression) != nil
            let isKnownSectionTitle = ["contents", "table of contents", "preface", "foreword", "index", "bibliography", "references", "appendix", "glossary"].contains(normalized)
            
            if !hasTerminalPunctuation && (isAllCapsHeader || isHeaderPattern || hasLeadingOrTrailingPageNumber || isKnownSectionTitle) && trimmed.count < 75 {
                return .pageHeader
            }
        }
        
        // 6. Footers
        if inFooterZone {
            if let analysis = analysis, analysis.recurringFooters.contains(normalized) {
                return .pageFooter
            }
            // If whole-document analysis was performed, non-recurring lines in the footer band
            // are normal body text unless they match a publication disclaimer or page number.
            // When analysis is nil (e.g. single-page document or isolated test), only classify if
            // it starts with an uppercase letter, is not a continuation, and lies in the bottom margin (relY <= 0.08).
            if analysis == nil {
                let startsWithLetter = trimmed.first?.isLetter == true
                let startsWithUppercase = trimmed.first?.isUppercase == true
                let isContinuation = trimmed.first?.isLowercase == true ||
                                     trimmed.hasSuffix(":") || trimmed.hasSuffix(",") ||
                                     trimmed.hasSuffix(";") || trimmed.hasSuffix("-")
                if startsWithLetter && startsWithUppercase && !isContinuation && !hasTerminalPunctuation && trimmed.count < 80 && relY <= 0.08 {
                    return .pageFooter
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Checkers
    
    public func isPageNumber(_ text: String) -> Bool {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        for regex in Self.pageNumberRegexes {
            if regex.firstMatch(in: text, options: [], range: fullRange) != nil {
                return true
            }
        }
        return false
    }
    
    public func isCaption(_ text: String) -> Bool {
        guard let regex = Self.captionRegex else { return false }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return regex.firstMatch(in: text, options: [], range: fullRange) != nil
    }
    
    public func isFootnote(line: VisualLine, trimmedText: String, medianHeight: CGFloat) -> Bool {
        guard let regex = Self.footnoteMarkerRegex else { return false }
        let nsText = trimmedText as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return regex.firstMatch(in: trimmedText, options: [], range: fullRange) != nil
    }
    
    public func isPublicationDisclaimer(_ text: String) -> Bool {
        guard let regex = Self.publicationDisclaimerRegex else { return false }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return regex.firstMatch(in: text, options: [], range: fullRange) != nil
    }
    
    // MARK: - Normalization
    
    private func normalizeForComparison(_ text: String) -> String {
        var lower = text.lowercased()
        // Strip Roman numerals ("ii", "iv", "xiv")
        lower = lower.replacingOccurrences(of: #"\b[ivxlcdm]+\b"#, with: " ", options: .regularExpression)
        // Strip trailing and leading punctuation and numbers (since page numbers might be appended like "Chapter 1  |  42")
        lower = lower.replacingOccurrences(of: #"[0-9\-\|\.\,\:\;]"#, with: " ", options: .regularExpression)
        lower = lower.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return lower.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
