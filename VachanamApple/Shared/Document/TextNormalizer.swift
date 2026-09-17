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
        
        // Remove soft hyphens (\u{00AD}), zero-width characters, and unmapped font replacement artifacts (\u{FFFD})
        result = result.replacingOccurrences(of: "\u{00AD}", with: "")
        result = result.replacingOccurrences(of: "\u{200B}", with: "") // zero-width space
        result = result.replacingOccurrences(of: "\u{200C}", with: "") // zero-width non-joiner
        result = result.replacingOccurrences(of: "\u{200D}", with: "") // zero-width joiner
        result = result.replacingOccurrences(of: "\u{FEFF}", with: "") // zero-width no-break space (BOM)
        result = result.replacingOccurrences(of: "\u{FFFD}", with: "") // Unicode replacement character (from .notdef/unmapped font glyphs)
        
        // Remove unprintable control characters and private-use font artifacts from unmapped CMaps
        result = result.replacingOccurrences(of: "[\u{0000}-\u{0008}\u{000B}\u{000C}\u{000E}-\u{001F}\u{E000}-\u{F8FF}]", with: "", options: .regularExpression)
        
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
        
        // Separate decimal numbers from variables (e.g. 0.5x -> 0.5 x, 2.0y -> 2.0 y), excluding scientific notation (1.5e3, 6.022e23, 2.0E-4)
        result = result.replacingOccurrences(
            of: #"(?<=\d\.\d{1,6})\s*(?![eE][+-]?\d)([a-zA-Zα-ωΑ-Ω])"#,
            with: " $1",
            options: .regularExpression
        )
        // Separate integers from single lowercase math variables (e.g. 3x -> 3 x, 2y -> 2 y), excluding ordinals and scientific notation (1e3, 2e-4)
        result = result.replacingOccurrences(
            of: #"(?<=\b\d{1,6})\s*(?![eE][+-]?\d)([a-zα-ω])\b(?!(?:st|nd|rd|th)\b)"#,
            with: " $1",
            options: .regularExpression
        )
        
        // Reconstruct words broken across line breaks (e.g. "exam-\nples" -> "examples")
        let lineHyphenPattern = #"(\b\p{L}+)[-‐‑‒]\s*[\r\n]+\s*(\p{L}+\b)"#
        if let regex = try? NSRegularExpression(pattern: lineHyphenPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if let r1 = Range(match.range(at: 1), in: result),
                   let r2 = Range(match.range(at: 2), in: result) {
                    let p1 = String(result[r1]) + "-"
                    let p2 = String(result[r2])
                    let resolved = WordReconstructor.shared.resolveHyphenation(firstPart: p1, secondPart: p2)
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: resolved.reconstructedWord)
                    }
                }
            }
        }
        
        // Clean multiple spaces on single lines (preserving deliberate newlines)
        result = result.replacingOccurrences(of: "[ ]{2,}", with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Converts mathematical symbols, currencies, units, temperatures, and fractions
    /// into natural spoken English for high-quality TTS generation.
    public func normalizeForSpeech(_ text: String, mathStyle: MathSpeechStyle = AccessibilityManager.shared.mathSpeechStyle) -> String {
        guard !text.isEmpty else { return "" }
        
        var result = normalize(text)
        
        // 0. LaTeX Matrices, Delimiters, SI Units, Macros, and Scientific Exponential Notation
        result = MathSpeechEngine.shared.vocalizeMatrices(result, style: mathStyle)
        // Strip display math delimiters $$ and single $ (excluding \$ and currency amounts $50)
        result = result.replacingOccurrences(of: #"\$\$"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<!\\)\$(?!\d|\$)"#, with: "", options: .regularExpression)
        result = MathSpeechEngine.shared.vocalizeSIUnits(result)
        result = MathSpeechEngine.shared.translateLatexMacros(result, style: mathStyle)
        result = MathSpeechEngine.shared.vocalizeScientificNotation(result, style: mathStyle)
        result = MathSpeechEngine.shared.vocalizeUnicodeSuperscripts(result, style: mathStyle)
        
        // 1. URLs and DOIs for natural audio narration (must run before hyphen/dash replacements)
        // DOIs: doi:10.1000/182 -> publication link
        result = result.replacingOccurrences(
            of: #"\bdoi:\s*10\.\d{4,9}/[^\s]+"#,
            with: "publication link",
            options: [.caseInsensitive, .regularExpression]
        )
        // Web URLs: https://www.example.com/path -> link to example.com
        result = result.replacingOccurrences(
            of: #"https?://(?:www\.)?([a-zA-Z0-9\-\.]+)(?:/[^\s]*?(?=[\.,;:\s]|$))?"#,
            with: "link to $1",
            options: [.caseInsensitive, .regularExpression]
        )
        // Standalone www addresses: www.example.org -> link to example.org
        result = result.replacingOccurrences(
            of: #"\bwww\.([a-zA-Z0-9\-\.]+)(?:/[^\s]*?(?=[\.,;:\s]|$))?"#,
            with: "link to $1",
            options: [.caseInsensitive, .regularExpression]
        )
        
        // Strip bullet points and visual list ornaments that should not be spoken
        // (Unicode bullets, circles, squares, diamonds, triangles, checkmarks)
        let bulletChars = CharacterSet(charactersIn: "•◦▪▫●■◆❖★☆►▻➢✓✔\u{2022}\u{25E6}\u{25AA}\u{25AB}\u{25CF}\u{25A0}\u{25C6}\u{2756}\u{2605}\u{2606}\u{25BA}\u{25BB}\u{27A2}\u{2713}\u{2714}")
        result = result.components(separatedBy: bulletChars).joined(separator: " ")
        
        // Strip leading list hyphens, en-dashes, em-dashes, asterisks on newlines or start of text
        result = result.replacingOccurrences(
            of: #"(?:^|[\r\n]+)\s*[*–—\-]\s+"#,
            with: " ",
            options: .regularExpression
        )
        
        // 2. Numeric ranges: 10-20, 1990-2000 -> 10 to 20, 1990 to 2000
        result = result.replacingOccurrences(
            of: #"(?<=\d)\s*[-‐‑‒–—]\s*(?=\d)"#,
            with: " to ",
            options: .regularExpression
        )
        
        // 3. Intra-word hyphens in compound words: "on-device", "accessibility-focused", "word-by-word"
        // Replace with single space so neural TTS synthesizes fluent connected speech without silent punctuation pauses
        result = result.replacingOccurrences(
            of: #"(?<=\p{L})[-‐‑‒–—](?=\p{L})"#,
            with: " ",
            options: .regularExpression
        )
        
        // 4. Parenthetical dashes: em-dashes, en-dashes, spaced hyphens, double hyphens
        // Convert to comma pause for smooth conversational clause transitions instead of abrupt silence
        result = result.replacingOccurrences(
            of: #"\s*[—–]\s*|\s+-\s+|\s*--+\s*"#,
            with: ", ",
            options: .regularExpression
        )
        
        // Currencies: $100 -> 100 dollars, $4,500 -> 4,500 dollars, €50 -> 50 euros, etc.
        result = result.replacingOccurrences(
            of: #"\$(\d+(?:,\d+)*(?:\.\d{1,2})?)\b"#,
            with: "$1 dollars",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"€(\d+(?:,\d+)*(?:\.\d{1,2})?)\b"#,
            with: "$1 euros",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"£(\d+(?:,\d+)*(?:\.\d{1,2})?)\b"#,
            with: "$1 pounds",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"¥(\d+(?:,\d+)*)\b"#,
            with: "$1 yen",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"₹(\d+(?:,\d+)*(?:\.\d{1,2})?)\b"#,
            with: "$1 rupees",
            options: .regularExpression
        )
        
        // Percentages: 25% or 25\% -> 25 percent
        result = result.replacingOccurrences(
            of: #"(\d+(?:\.\d+)?)\s*\\?%"#,
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
        
        // --- 1. Math Variables Attached to Common English Words (PDF font change artifacts) ---
        // e.g. "ycan be added" -> "y can be added", "xand y" -> "x and y", "Aas the rows" -> "A as the rows"
        result = result.replacingOccurrences(
            of: #"\b([A-Z])(as|is|can|are|be|in|to|with|for|by|from|where|when|that|which|then|such|and|or)\b"#,
            with: "$1 $2",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\b([xyz])(can|and|are|is|be|from|where|when|that|which|then|such|or)\b"#,
            with: "$1 $2",
            options: .regularExpression
        )
        
        // --- 2. Vector Arrow Notations ---
        // Combining right arrow above (U+20D7) after variable: x⃗ -> vector x
        result = result.replacingOccurrences(
            of: "([a-zA-Z])[\\u20D7]",
            with: "vector $1",
            options: .regularExpression
        )
        // Vector arrow over or before a variable: \vec{x}, →x, −→ x, →\n→\nx
        result = result.replacingOccurrences(
            of: #"(?:[−-]\s*)?(?:[→⟶]\s*)+([a-zA-Z])\b"#,
            with: " vector $1",
            options: .regularExpression
        )
        
        // --- 3. Transpose & Inverses (before general carets) ---
        // Matrix transpose: A⊤, Aᵀ, A^T, A^⊤, (A + B)⊤, (AB)⊤
        result = result.replacingOccurrences(
            of: #"(?:(?<=\b[a-zA-Z0-9])|(?<=\)))\s*(?:\^\s*[T⊤ᵀ]|[⊤ᵀ])\b"#,
            with: " transpose",
            options: .regularExpression
        )
        // Standalone ⊤ or ᵀ
        result = result.replacingOccurrences(of: #"\b[⊤ᵀ]\b|[⊤ᵀ]"#, with: " transpose", options: .regularExpression)
        
        // Matrix / variable inverse: A^-1, A⁻¹, A^{-1}, A-1, A−1, (AB)-1, (AB)−1
        result = result.replacingOccurrences(
            of: #"(?:(?<=\b[A-Z0-9])|(?<=\)))\s*(?:\^|ˆ)?\s*(?:[-−]1|\{[-−]1\})\b|(?<=[a-zA-Z0-9\)])⁻¹(?![⁰¹²³⁴⁵⁶⁷⁸⁹])"#,
            with: " inverse",
            options: .regularExpression
        )
        // Inverse transpose: A^-T, A^{-T}, A^-⊤, A-T, A−T, A-⊤, A−⊤
        result = result.replacingOccurrences(
            of: #"(?:(?<=\b[A-Z0-9])|(?<=\)))\s*(?:\^|ˆ)?\s*(?:[-−][T⊤ᵀ]|\{[-−][T⊤ᵀ]\})\b"#,
            with: " inverse transpose",
            options: .regularExpression
        )
        
        // --- 4. Carets / Hats & Powers ---
        // Hats:
        // Standalone caret before variable: ^x
        result = result.replacingOccurrences(
            of: #"(?:^|\s)\^([a-zA-Z])\b"#,
            with: " $1 hat",
            options: .regularExpression
        )
        // Standalone caret after single variable without exponent: y^ (followed by space, punctuation, or end)
        result = result.replacingOccurrences(
            of: #"\b([a-zA-Z])\^(?=\s|[\.,;:!?]|$)"#,
            with: "$1 hat",
            options: .regularExpression
        )
        // Combining hat (U+0302 or U+02C6): x̂ -> x hat
        result = result.replacingOccurrences(
            of: "([a-zA-Z])[\\u0302\\u02C6]",
            with: "$1 hat",
            options: .regularExpression
        )
        
        // Powers:
        // Squared: x^2, x², (x+y)^2
        result = result.replacingOccurrences(
            of: #"(?:(?<=\b[a-zA-Z0-9])|(?<=\)))\s*(?:\^|ˆ)\s*2\b|(?<![⁺⁻⁰¹²³⁴⁵⁶⁷⁸⁹])(?<=[a-zA-Z0-9\)])²(?![⁰¹²³⁴⁵⁶⁷⁸⁹])"#,
            with: " squared",
            options: .regularExpression
        )
        // Cubed: x^3, x³, (x+y)^3
        result = result.replacingOccurrences(
            of: #"(?:(?<=\b[a-zA-Z0-9])|(?<=\)))\s*(?:\^|ˆ)\s*3\b|(?<![⁺⁻⁰¹²³⁴⁵⁶⁷⁸⁹])(?<=[a-zA-Z0-9\)])³(?![⁰¹²³⁴⁵⁶⁷⁸⁹])"#,
            with: " cubed",
            options: .regularExpression
        )
        // General variable/numeric powers with braces: x^{n+1}, (x+y)^{k}
        result = result.replacingOccurrences(
            of: #"(?:(?<=\b[a-zA-Z0-9])|(?<=\)))\s*(?:\^|ˆ)\s*\{([^}]+)\}"#,
            with: " to the power of $1",
            options: .regularExpression
        )
        // General variable/numeric powers: x^n, x^k, 10^5, z^n
        result = result.replacingOccurrences(
            of: #"(?:(?<=\b[a-zA-Z0-9])|(?<=\)))\s*(?:\^|ˆ)\s*([0-9]{1,4}|[a-zA-Z]\b)"#,
            with: " to the $1",
            options: .regularExpression
        )
        // Strip any residual detached carets
        result = result.replacingOccurrences(of: #"[ \t]*\^[ \t]*"#, with: " ", options: .regularExpression)
        
        // --- 5. Subscripts ---
        // e.g. x_1 -> x sub 1, x_i -> x sub i, W_ij -> W sub ij, x_{i+1} -> x sub i+1
        result = result.replacingOccurrences(
            of: #"\b([a-zA-Z])_\{([^}]+)\}"#,
            with: "$1 sub $2",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\b([a-zA-Z])_([0-9a-zA-Z]+)\b"#,
            with: "$1 sub $2",
            options: .regularExpression
        )
        // Unicode subscripts: ₀₁₂₃₄₅₆₇₈₉ᵢⱼₖₙₘ
        let unicodeSubscripts: [(String, String)] = [
            ("₀", " sub 0"), ("₁", " sub 1"), ("₂", " sub 2"), ("₃", " sub 3"), ("₄", " sub 4"),
            ("₅", " sub 5"), ("₆", " sub 6"), ("₇", " sub 7"), ("₈", " sub 8"), ("₉", " sub 9"),
            ("ᵢ", " sub i"), ("ⱼ", " sub j"), ("ₖ", " sub k"), ("ₙ", " sub n"), ("ₘ", " sub m")
        ]
        for (subGlyph, subSpoken) in unicodeSubscripts {
            result = result.replacingOccurrences(of: subGlyph, with: subSpoken)
        }
        
        // --- 6. Accents (Bars, Tildes, Primes, Stars) ---
        // Bars: x̄ -> x bar
        result = result.replacingOccurrences(of: "([a-zA-Z])[\\u0304\\u0305\\u00AF]", with: "$1 bar", options: .regularExpression)
        // Tildes: x̃ -> x tilde
        result = result.replacingOccurrences(of: "([a-zA-Z])[\\u0303\\u02DC]", with: "$1 tilde", options: .regularExpression)
        // Primes: x' -> x prime, x'' -> x double prime (excluding contractions like didn't, couldn't, o'clock, user's)
        result = result.replacingOccurrences(of: #"([a-zA-Z0-9])(?:′′|'')(?!['a-zA-Z])"#, with: "$1 double prime", options: .regularExpression)
        result = result.replacingOccurrences(of: #"([a-zA-Z0-9])(?:′|')(?!['a-zA-Z])"#, with: "$1 prime", options: .regularExpression)
        // Star / optimum: x* -> x star, θ* -> theta star
        result = result.replacingOccurrences(of: #"\b([a-zA-Zα-ωΑ-Ω])\*(?!\*)"#, with: "$1 star", options: .regularExpression)
        
        // --- 7. Norms, Inner Products, and Matrix Dimensions ---
        // Norm: ‖x‖ or ||x|| -> the norm of x
        result = result.replacingOccurrences(
            of: #"(?:‖|\|\|)\s*([^‖\|]+?)\s*(?:‖|\|\|)"#,
            with: " the norm of $1 ",
            options: .regularExpression
        )
        // Inner product: ⟨x, y⟩ -> the inner product of x and y
        result = result.replacingOccurrences(
            of: #"[⟨<]\s*([a-zA-Z0-9\s]+?)\s*,\s*([a-zA-Z0-9\s]+?)\s*[⟩>]"#,
            with: " the inner product of $1 and $2 ",
            options: .regularExpression
        )
        // Matrix dimensions: Rn×n, Rm×n, ℝⁿˣⁿ, (n,n)-matrices
        result = result.replacingOccurrences(
            of: #"\b[ℝR]\s*n\s*[×x]\s*n\b|[ℝR]ⁿˣⁿ"#,
            with: " R n by n ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\b[ℝR]\s*m\s*[×x]\s*n\b|[ℝR]ᵐˣⁿ"#,
            with: " R m by n ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\b[ℝR]\s*([0-9a-z]+)\s*[×x]\s*([0-9a-z]+)\b"#,
            with: " R $1 by $2 ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\(([a-zA-Z0-9]+)\s*,\s*([a-zA-Z0-9]+)\)\s*[- ]\s*matrices\b"#,
            with: "$1 by $2 matrices",
            options: .regularExpression
        )
        
        // --- 8. Arrows & Mapping Operators ---
        // Limits: x → 0, x → ∞
        result = result.replacingOccurrences(
            of: #"\b([a-zA-Z])\s*[→⟶]\s*(0|∞|infinity|[0-9]+)\b"#,
            with: "$1 approaches $2",
            options: .regularExpression
        )
        // Set maps: X → Y
        result = result.replacingOccurrences(
            of: #"\b([A-Z])\s*[→⟶]\s*([A-Z])\b"#,
            with: "$1 to $2",
            options: .regularExpression
        )
        // Element map: ↦
        result = result.replacingOccurrences(of: "↦", with: " maps to ")
        // Implication: ⟹, ⇒
        result = result.replacingOccurrences(of: "⟹", with: " implies ")
        result = result.replacingOccurrences(of: "⇒", with: " implies ")
        result = result.replacingOccurrences(of: "⟺", with: " if and only if ")
        result = result.replacingOccurrences(of: "⇔", with: " if and only if ")
        // Remaining standalone arrows
        result = result.replacingOccurrences(of: "→", with: " to ")
        result = result.replacingOccurrences(of: "⟶", with: " to ")
        result = result.replacingOccurrences(of: "←", with: " left arrow ")
        result = result.replacingOccurrences(of: "↔", with: " if and only if ")
        
        // --- 8b. Subscripts, Linear Algebra Equations & Sequence Ellipses ---
        result = MathSpeechEngine.shared.vocalizeSubscriptsAndEquations(result, style: mathStyle)
        
        // --- 9. Standard Math Operators & Symbols ---
        result = MathSpeechEngine.shared.vocalizeSymbols(result, style: mathStyle)
        
        // --- 10. Math Operators Spacing ---
        result = result.replacingOccurrences(
            of: #"(?<=[a-zA-Z0-9\)])\s*=\s*(?=[a-zA-Z0-9\(\-])"#,
            with: " equals ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<=[a-zA-Z0-9\)])\s*\+\s*(?=[a-zA-Z0-9\(\-])"#,
            with: " plus ",
            options: .regularExpression
        )
        // Unicode minus −
        result = result.replacingOccurrences(
            of: #"(?<=[a-zA-Z0-9\)])\s*−\s*(?=[a-zA-Z0-9\(\-])"#,
            with: " minus ",
            options: .regularExpression
        )
        // Spaced ASCII hyphen: x - y or 5 - 3
        result = result.replacingOccurrences(
            of: #"(?<=[a-zA-Z0-9\)])\s+-\s+(?=[a-zA-Z0-9\(\-])"#,
            with: " minus ",
            options: .regularExpression
        )
        // Numeric subtraction without space: 5-3 -> 5 minus 3 (preserves hyphenated names like Kokoro-82M)
        result = result.replacingOccurrences(
            of: #"(?<=[0-9])-(?=[0-9])"#,
            with: " minus ",
            options: .regularExpression
        )
        
        // Leading math operators and punctuation
        result = result.replacingOccurrences(
            of: #"^\s*\+\s*(?=[a-zA-Z0-9\(\-])"#,
            with: "plus ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"^\s*[−-]\s*(?=[0-9a-zA-Z\(\-])"#,
            with: "minus ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"^\s*,\s*"#,
            with: "",
            options: .regularExpression
        )
        
        // --- 11. Common Scientific & Latin Abbreviations ---
        let abbreviations: [(String, String)] = [
            (#"\b(?:w\.r\.t\.|w\.r\.t)\b"#, "with respect to"),
            (#"\b(?:s\.t\.|s\.t)\b"#, "such that"),
            (#"\b(?:i\.i\.d\.|i\.i\.d)\b"#, "independent and identically distributed"),
            (#"\biff\b"#, "if and only if"),
            (#"\bargmin\b"#, "argument minimum"),
            (#"\bargmax\b"#, "argument maximum"),
            (#"\bdiag\s*\("#, "diagonal of ("),
            (#"\bdet\s*\("#, "determinant of ("),
            (#"\b(?:tr|Tr)\s*\("#, "trace of ("),
            (#"\brank\s*\("#, "rank of ("),
            (#"\bdim\s*\("#, "dimension of ("),
            (#"\bspan\s*\("#, "span of ("),
            (#"\bexp\s*\("#, "exponential of ("),
            (#"\blog\s*\("#, "log of ("),
            (#"\bln\s*\("#, "natural log of ("),
            (#"\bsin\s*\("#, "sine of ("),
            (#"\bcos\s*\("#, "cosine of ("),
            (#"\btan\s*\("#, "tangent of ")
        ]
        for (pattern, spoken) in abbreviations {
            result = result.replacingOccurrences(of: pattern, with: spoken, options: .regularExpression)
        }
        
        // Blackboard bold vector spaces and number systems (e.g. ℝⁿ, ℝ³, ℝ, ℕ, ℤ, ℂ)
        result = result.replacingOccurrences(of: #"[ℝR]\s*[\^]?\s*n\b|[ℝR]\s*[\^]?\s*ⁿ"#, with: " R n ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[ℝR]\s*[\^]?\s*d\b|[ℝR]\s*[\^]?\s*ᵈ"#, with: " R d ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[ℝR]\s*[\^]?\s*m\b|[ℝR]\s*[\^]?\s*ᵐ"#, with: " R m ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[ℝR]\s*[\^]?\s*k\b|[ℝR]\s*[\^]?\s*ᵏ"#, with: " R k ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[ℝR]\s*[\^]?\s*2\b|[ℝR]\s*[\^]?\s*²"#, with: " R two ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[ℝR]\s*[\^]?\s*3\b|[ℝR]\s*[\^]?\s*³"#, with: " R three ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[ℝR]\s*[\^]?\s*4\b|[ℝR]\s*[\^]?\s*⁴"#, with: " R four ", options: .regularExpression)
        if mathStyle == .mathSpeakRigorous {
            result = result.replacingOccurrences(of: "ℝ", with: " blackboard bold R ")
            result = result.replacingOccurrences(of: "ℕ", with: " blackboard bold N ")
            result = result.replacingOccurrences(of: "ℤ", with: " blackboard bold Z ")
            result = result.replacingOccurrences(of: "ℚ", with: " blackboard bold Q ")
            result = result.replacingOccurrences(of: "ℂ", with: " blackboard bold C ")
        } else {
            result = result.replacingOccurrences(of: "ℝ", with: " the real numbers ")
            result = result.replacingOccurrences(of: "ℕ", with: " the natural numbers ")
            result = result.replacingOccurrences(of: "ℤ", with: " the integers ")
            result = result.replacingOccurrences(of: "ℚ", with: " the rational numbers ")
            result = result.replacingOccurrences(of: "ℂ", with: " the complex numbers ")
        }
        
        // Greek letters (lowercase and uppercase)
        result = MathSpeechEngine.shared.vocalizeGreek(result, style: mathStyle)
        
        // Number-variable adjacency: 0.5x -> 0.5 x, 2.0y -> 2.0 y (excluding ordinal indicators: 1st, 2nd, 3rd, 4th)
        result = result.replacingOccurrences(
            of: #"(?<=\d\.\d{1,6})\s*([a-zA-Zα-ωΑ-Ω])"#,
            with: " $1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<=\b\d{1,6})\s*([a-zα-ω])\b(?!(?:st|nd|rd|th)\b)"#,
            with: " $1",
            options: .regularExpression
        )
        
        // Equation label detection: e.g. "(2.1)" at the end of a line or math clause -> "equation 2.1"
        result = result.replacingOccurrences(
            of: #"\(([0-9]+\.[0-9]+)\)"#,
            with: "equation $1",
            options: .regularExpression
        )
        
        // Ampersand & at-sign
        result = result.replacingOccurrences(of: #"\s*&\s*"#, with: " and ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s*@\s*"#, with: " at ", options: .regularExpression)
        
        // 5. Common abbreviations and Latin phrases for human-like reading
        // e.g. / e.g., -> for example,
        result = result.replacingOccurrences(
            of: #"\be\.g\.,?\s*"#,
            with: "for example, ",
            options: [.caseInsensitive, .regularExpression]
        )
        // i.e. / i.e., -> that is,
        result = result.replacingOccurrences(
            of: #"\bi\.e\.,?\s*"#,
            with: "that is, ",
            options: [.caseInsensitive, .regularExpression]
        )
        // et al. -> and colleagues
        result = result.replacingOccurrences(
            of: #"\bet\s+al\.(?=[,\s\.;:]|$)"#,
            with: "and colleagues",
            options: [.caseInsensitive, .regularExpression]
        )
        // etc. -> etcetera
        result = result.replacingOccurrences(
            of: #"\betc\.(?=[,\s\.;:]|$)"#,
            with: "etcetera",
            options: [.caseInsensitive, .regularExpression]
        )
        // vs. / vs -> versus
        result = result.replacingOccurrences(
            of: #"\bvs\.?(?=[,\s\.;:]|$)"#,
            with: "versus",
            options: [.caseInsensitive, .regularExpression]
        )
        // approx. -> approximately
        result = result.replacingOccurrences(
            of: #"\bapprox\.\s*"#,
            with: "approximately ",
            options: [.caseInsensitive, .regularExpression]
        )
        // ca. or c. before 3-4 digit years -> circa
        result = result.replacingOccurrences(
            of: #"\b(?:ca\.|c\.)\s*(?=\d{3,4})"#,
            with: "circa ",
            options: [.caseInsensitive, .regularExpression]
        )
        // p. and pp. before numbers -> page / pages
        result = result.replacingOccurrences(
            of: #"\bpp\.\s*(\d+)"#,
            with: "pages $1",
            options: [.caseInsensitive, .regularExpression]
        )
        result = result.replacingOccurrences(
            of: #"\bp\.\s*(\d+)"#,
            with: "page $1",
            options: [.caseInsensitive, .regularExpression]
        )
        // Fig. or Figs. before numbers -> Figure / Figures
        result = result.replacingOccurrences(
            of: #"\bFigs\.\s*(\d+)"#,
            with: "Figures $1",
            options: [.caseInsensitive, .regularExpression]
        )
        result = result.replacingOccurrences(
            of: #"\bFig\.\s*(\d+)"#,
            with: "Figure $1",
            options: [.caseInsensitive, .regularExpression]
        )
        // Vol. / No. before numbers -> Volume / Number
        result = result.replacingOccurrences(
            of: #"\bVol\.\s*(\d+)"#,
            with: "Volume $1",
            options: [.caseInsensitive, .regularExpression]
        )
        result = result.replacingOccurrences(
            of: #"\bNo\.\s*(\d+)"#,
            with: "Number $1",
            options: [.caseInsensitive, .regularExpression]
        )
        
        // Honorific titles before capital names (prevents awkward sentence splitting on Dr. Vance, Dr. Alistair)
        result = result.replacingOccurrences(of: #"\bDr\.\s+(?=[A-Z])"#, with: "Doctor ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\bProf\.\s+(?=[A-Z])"#, with: "Professor ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\bInsp\.\s+(?=[A-Z])"#, with: "Inspector ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\bSgt\.\s+(?=[A-Z])"#, with: "Sergeant ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\bMr\.\s+(?=[A-Z])"#, with: "Mister ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\bMrs\.\s+(?=[A-Z])"#, with: "Missus ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\bMs\.\s+(?=[A-Z])"#, with: "Miz ", options: .regularExpression)
        
        // Scholarly Latin & Section markers
        result = result.replacingOccurrences(of: #"\bibid\.,?\s*"#, with: "in the same place, ", options: [.caseInsensitive, .regularExpression])
        result = result.replacingOccurrences(of: #"\bop\.\s*cit\.,?\s*"#, with: "in the work cited, ", options: [.caseInsensitive, .regularExpression])
        result = result.replacingOccurrences(of: #"\bcf\.\s*"#, with: "compare with ", options: [.caseInsensitive, .regularExpression])
        result = result.replacingOccurrences(of: #"\bviz\.,?\s*"#, with: "namely, ", options: [.caseInsensitive, .regularExpression])
        result = result.replacingOccurrences(of: #"\bq\.v\.,?\s*"#, with: "which see, ", options: [.caseInsensitive, .regularExpression])
        result = result.replacingOccurrences(of: #"§\s*([0-9]+(?:\.[0-9]+)*)"#, with: "section $1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"¶\s*([0-9]+)"#, with: "paragraph $1", options: .regularExpression)
        
        // Clean any resulting consecutive spaces
        result = result.replacingOccurrences(of: "[ ]{2,}", with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
