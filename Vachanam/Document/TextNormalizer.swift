//
//  TextNormalizer.swift
//  Vachanam
//
//  Normalizes extracted PDF text: cleans non-standard whitespace, removes soft hyphens,
//  unfolds ligatures, and filters unprintable layout control characters.
//

import Foundation

public struct TextNormalizer {
    public static let shared = TextNormalizer()
    
    public init() {}
    
    /// Normalizes raw text from PDF extraction or document streams.
    public func normalize(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        var result = text
        
        // Remove soft hyphens (\u{00AD}) and zero-width characters
        result = result.replacingOccurrences(of: "\u{00AD}", with: "")
        result = result.replacingOccurrences(of: "\u{200B}", with: "") // zero-width space
        result = result.replacingOccurrences(of: "\u{200C}", with: "") // zero-width non-joiner
        result = result.replacingOccurrences(of: "\u{200D}", with: "") // zero-width joiner
        result = result.replacingOccurrences(of: "\u{FEFF}", with: "") // zero-width no-break space (BOM)
        
        // Common typographical ligatures to standard characters
        let ligatures: [(String, String)] = [
            ("\u{FB00}", "ff"),
            ("\u{FB01}", "fi"),
            ("\u{FB02}", "fl"),
            ("\u{FB03}", "ffi"),
            ("\u{FB04}", "ffl"),
            ("\u{FB05}", "ft"),
            ("\u{FB06}", "st"),
            ("\u{0152}", "OE"),
            ("\u{0153}", "oe"),
            ("\u{00C6}", "AE"),
            ("\u{00E6}", "ae")
        ]
        for (ligature, replacement) in ligatures {
            result = result.replacingOccurrences(of: ligature, with: replacement)
        }
        
        // Standardize smart quotes and typographic dashes for consistent speech and parsing
        result = result.replacingOccurrences(of: "[\u{2018}\u{2019}\u{201A}\u{201B}]", with: "'", options: .regularExpression)
        result = result.replacingOccurrences(of: "[\u{201C}\u{201D}\u{201E}\u{201F}]", with: "\"", options: .regularExpression)
        result = result.replacingOccurrences(of: "\u{2014}", with: " — ") // em-dash
        result = result.replacingOccurrences(of: "\u{2013}", with: " – ") // en-dash
        
        // Standardize horizontal whitespaces (non-breaking space, tab, etc.) to normal spaces
        result = result.replacingOccurrences(of: "[\u{00A0}\u{2002}\u{2003}\u{2009}\u{202F}\t]+", with: " ", options: .regularExpression)
        
        // Clean multiple spaces on single lines (preserving deliberate newlines)
        result = result.replacingOccurrences(of: "[ ]{2,}", with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Converts mathematical symbols, currencies, units, temperatures, and fractions
    /// into natural spoken English for high-quality TTS generation.
    public func normalizeForSpeech(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        var result = normalize(text)
        
        // Currencies: $100 -> 100 dollars, €50 -> 50 euros, etc.
        result = result.replacingOccurrences(
            of: #"\$(\d+(?:\.\d{1,2})?)\b"#,
            with: "$1 dollars",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"€(\d+(?:\.\d{1,2})?)\b"#,
            with: "$1 euros",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"£(\d+(?:\.\d{1,2})?)\b"#,
            with: "$1 pounds",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"¥(\d+)\b"#,
            with: "$1 yen",
            options: .regularExpression
        )
        
        // Percentages: 25% -> 25 percent
        result = result.replacingOccurrences(
            of: #"(\d+(?:\.\d+)?)\s*%"#,
            with: "$1 percent",
            options: .regularExpression
        )
        
        // Temperature and angles: 20°C -> 20 degrees Celsius, 72°F -> 72 degrees Fahrenheit
        result = result.replacingOccurrences(
            of: #"(\d+(?:\.\d+)?)\s*°\s*C\b"#,
            with: "$1 degrees Celsius",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(\d+(?:\.\d+)?)\s*°\s*F\b"#,
            with: "$1 degrees Fahrenheit",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(\d+(?:\.\d+)?)\s*°"#,
            with: "$1 degrees",
            options: .regularExpression
        )
        
        // Plus or minus: ±5 -> plus or minus 5
        result = result.replacingOccurrences(
            of: #"±\s*(\d+(?:\.\d+)?)"#,
            with: "plus or minus $1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "±", with: " plus or minus ")
        
        // Fractions
        let fractions: [(String, String)] = [
            ("½", " one half "),
            ("⅓", " one third "),
            ("¼", " one quarter "),
            ("¾", " three quarters "),
            ("⅔", " two thirds "),
            ("⅛", " one eighth "),
            ("⅜", " three eighths "),
            ("⅝", " five eighths "),
            ("⅞", " seven eighths ")
        ]
        for (glyph, spoken) in fractions {
            result = result.replacingOccurrences(of: glyph, with: spoken)
        }
        
        // Math symbols
        let mathSymbols: [(String, String)] = [
            ("×", " times "),
            ("÷", " divided by "),
            ("≠", " not equal to "),
            ("≤", " less than or equal to "),
            ("≥", " greater than or equal to "),
            ("≈", " approximately "),
            ("∞", " infinity ")
        ]
        for (sym, spoken) in mathSymbols {
            result = result.replacingOccurrences(of: sym, with: spoken)
        }
        
        // Ampersand & at-sign
        result = result.replacingOccurrences(of: #"\s*&\s*"#, with: " and ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s*@\s*"#, with: " at ", options: .regularExpression)
        
        // Clean any resulting consecutive spaces
        result = result.replacingOccurrences(of: "[ ]{2,}", with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
