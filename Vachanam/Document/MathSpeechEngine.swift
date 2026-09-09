//
//  MathSpeechEngine.swift
//  Vachanam
//
//  Standardized Speech Rule Engine (SRE) and MathSpeak vocalizer for scientific notation,
//  SI units, Greek characters, LaTeX macros, and mathematical equations.
//

import Foundation

public enum MathSpeechStyle: String, CaseIterable, Identifiable, Codable {
    case conversational = "Conversational"
    case mathSpeakRigorous = "MathSpeak Rigorous"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .conversational:
            return "Natural spoken English for smooth audio listening (e.g. '1 over 2', '5 nanometers', 'x squared')."
        case .mathSpeakRigorous:
            return "Formal academic screen-reader speech rules (e.g. 'start fraction, 1, divided by, 2, end fraction')."
        }
    }
}

public class MathSpeechEngine: @unchecked Sendable {
    public static let shared = MathSpeechEngine()
    
    // MARK: - Internal Data Structures
    
    public struct SymbolEntry: Codable {
        public let char: String
        public let conversational: String
        public let mathspeak: String
    }
    
    public struct FunctionEntry: Codable {
        public let name: String
        public let conversational: String
        public let mathspeak: String
    }
    
    public struct GreekEntry: Codable {
        public let char: String
        public let conversational: String
        public let mathspeak: String
        public let is_uppercase: Bool
    }
    
    public struct CompoundUnitEntry: Codable {
        public let symbol: String
        public let spoken: String
    }
    
    public struct UnitPrefixedEntry: Codable {
        public let symbol: String
        public let singular: String
        public let plural: String
    }
    
    public struct LatexMacroRule: Codable {
        public let pattern: String
        public let conversational: String
        public let mathspeak: String
    }
    
    public struct DelimiterRule: Codable {
        public let pattern: String
        public let replacement: String
    }
    
    // MARK: - Loaded Mappings
    
    private var symbols: [SymbolEntry] = []
    private var functions: [FunctionEntry] = []
    private var greekLetters: [GreekEntry] = []
    private var compoundUnits: [CompoundUnitEntry] = []
    private var prefixedUnits: [UnitPrefixedEntry] = []
    private var latexMacros: [LatexMacroRule] = []
    private var latexDelimiters: [DelimiterRule] = []
    
    private let spellOutFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    private let ordinalPowers: [Int: String] = [
        1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth", 6: "sixth",
        7: "seventh", 8: "eighth", 9: "ninth", 10: "tenth", 11: "eleventh", 12: "twelfth"
    ]
    
    // Cached regular expressions for high throughput
    private var cachedRegexes: [String: NSRegularExpression] = [:]
    private let regexLock = NSLock()
    
    public init() {
        loadData()
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        loadScientificNotationConfig()
        loadSymbols()
        loadFunctions()
        loadGreek()
        loadSIUnits()
        loadLatexMacros()
    }
    
    private func findFileURL(named name: String) -> URL? {
        // 1. Bundle.main with subdirectory
        if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "MathMaps") {
            return url
        }
        // 2. Bundle.main direct
        if let url = Bundle.main.url(forResource: name, withExtension: "json") {
            return url
        }
        // 3. Class bundle with subdirectory
        let classBundle = Bundle(for: MathSpeechEngine.self)
        if let url = classBundle.url(forResource: name, withExtension: "json", subdirectory: "MathMaps") {
            return url
        }
        // 4. Class bundle direct
        if let url = classBundle.url(forResource: name, withExtension: "json") {
            return url
        }
        // 5. File system path inside Vachanam/Resources/MathMaps (for dev / test executions)
        let localPath = "Vachanam/Resources/MathMaps/\(name).json"
        if FileManager.default.fileExists(atPath: localPath) {
            return URL(fileURLWithPath: localPath)
        }
        return nil
    }
    
    private func loadScientificNotationConfig() {
        // Patterns are standard and compiled below
    }
    
    private func loadSymbols() {
        if let url = findFileURL(named: "symbols"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let rawList = json["symbols"] as? [[String: Any]] {
            self.symbols = rawList.compactMap { dict in
                guard let char = dict["char"] as? String,
                      let conv = dict["conversational"] as? String,
                      let math = dict["mathspeak"] as? String else { return nil }
                return SymbolEntry(char: char, conversational: conv, mathspeak: math)
            }
        }
        
        if self.symbols.isEmpty {
            // Built-in fallback symbols
            self.symbols = [
                SymbolEntry(char: "≠", conversational: "not equal to", mathspeak: "not equal to"),
                SymbolEntry(char: "≤", conversational: "less than or equal to", mathspeak: "less than or equal to"),
                SymbolEntry(char: "≥", conversational: "greater than or equal to", mathspeak: "greater than or equal to"),
                SymbolEntry(char: "≈", conversational: "approximately", mathspeak: "almost equal to"),
                SymbolEntry(char: "≡", conversational: "identically equal to", mathspeak: "strictly equivalent to"),
                SymbolEntry(char: "∝", conversational: "proportional to", mathspeak: "proportional to"),
                SymbolEntry(char: "±", conversational: "plus or minus", mathspeak: "plus or minus"),
                SymbolEntry(char: "∓", conversational: "minus or plus", mathspeak: "minus or plus"),
                SymbolEntry(char: "×", conversational: "times", mathspeak: "cross"),
                SymbolEntry(char: "÷", conversational: "divided by", mathspeak: "divided by"),
                SymbolEntry(char: "⋅", conversational: "dot", mathspeak: "center dot"),
                SymbolEntry(char: "∈", conversational: "in", mathspeak: "element of"),
                SymbolEntry(char: "∉", conversational: "not in", mathspeak: "not an element of"),
                SymbolEntry(char: "⊆", conversational: "subset of", mathspeak: "subset of or equal to"),
                SymbolEntry(char: "⊂", conversational: "subset of", mathspeak: "proper subset of"),
                SymbolEntry(char: "⊇", conversational: "superset of", mathspeak: "superset of or equal to"),
                SymbolEntry(char: "⊃", conversational: "superset of", mathspeak: "proper superset of"),
                SymbolEntry(char: "∪", conversational: "union", mathspeak: "set union"),
                SymbolEntry(char: "∩", conversational: "intersection", mathspeak: "set intersection"),
                SymbolEntry(char: "∅", conversational: "empty set", mathspeak: "empty set"),
                SymbolEntry(char: "∀", conversational: "for all", mathspeak: "universal quantifier, for all"),
                SymbolEntry(char: "∃", conversational: "there exists", mathspeak: "existential quantifier, there exists"),
                SymbolEntry(char: "∄", conversational: "there does not exist", mathspeak: "there does not exist"),
                SymbolEntry(char: "∧", conversational: "and", mathspeak: "logical and"),
                SymbolEntry(char: "∨", conversational: "or", mathspeak: "logical or"),
                SymbolEntry(char: "¬", conversational: "not", mathspeak: "logical not"),
                SymbolEntry(char: "⟹", conversational: "implies", mathspeak: "implies"),
                SymbolEntry(char: "⇒", conversational: "implies", mathspeak: "implies"),
                SymbolEntry(char: "⟺", conversational: "if and only if", mathspeak: "if and only if"),
                SymbolEntry(char: "⇔", conversational: "if and only if", mathspeak: "if and only if"),
                SymbolEntry(char: "∴", conversational: "therefore", mathspeak: "therefore"),
                SymbolEntry(char: "∵", conversational: "because", mathspeak: "because"),
                SymbolEntry(char: "∫", conversational: "integral of", mathspeak: "integral"),
                SymbolEntry(char: "∬", conversational: "double integral of", mathspeak: "double integral"),
                SymbolEntry(char: "∭", conversational: "triple integral of", mathspeak: "triple integral"),
                SymbolEntry(char: "∮", conversational: "contour integral of", mathspeak: "contour integral"),
                SymbolEntry(char: "∑", conversational: "sum of", mathspeak: "sum"),
                SymbolEntry(char: "∏", conversational: "product of", mathspeak: "product"),
                SymbolEntry(char: "∂", conversational: "partial", mathspeak: "partial derivative"),
                SymbolEntry(char: "∇", conversational: "gradient", mathspeak: "nabla"),
                SymbolEntry(char: "√", conversational: "square root of", mathspeak: "start square root"),
                SymbolEntry(char: "∞", conversational: "infinity", mathspeak: "infinity"),
                SymbolEntry(char: "⊥", conversational: "perpendicular to", mathspeak: "perpendicular to"),
                SymbolEntry(char: "∥", conversational: "parallel to", mathspeak: "parallel to"),
                SymbolEntry(char: "∠", conversational: "angle", mathspeak: "angle"),
                SymbolEntry(char: "ℏ", conversational: "h bar", mathspeak: "planck constant over 2 pi, h bar"),
                SymbolEntry(char: "ℵ", conversational: "aleph", mathspeak: "aleph")
            ]
        }
    }
    
    private func loadFunctions() {
        if let url = findFileURL(named: "functions"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let rawList = json["functions"] as? [[String: Any]] {
            self.functions = rawList.compactMap { dict in
                guard let name = dict["name"] as? String,
                      let conv = dict["conversational"] as? String,
                      let math = dict["mathspeak"] as? String else { return nil }
                return FunctionEntry(name: name, conversational: conv, mathspeak: math)
            }
        }
        
        if self.functions.isEmpty {
            self.functions = [
                FunctionEntry(name: "sin", conversational: "sine of", mathspeak: "sine"),
                FunctionEntry(name: "cos", conversational: "cosine of", mathspeak: "cosine"),
                FunctionEntry(name: "tan", conversational: "tangent of", mathspeak: "tangent"),
                FunctionEntry(name: "sec", conversational: "secant of", mathspeak: "secant"),
                FunctionEntry(name: "csc", conversational: "cosecant of", mathspeak: "cosecant"),
                FunctionEntry(name: "cot", conversational: "cotangent of", mathspeak: "cotangent"),
                FunctionEntry(name: "sinh", conversational: "hyperbolic sine of", mathspeak: "hyperbolic sine"),
                FunctionEntry(name: "cosh", conversational: "hyperbolic cosine of", mathspeak: "hyperbolic cosine"),
                FunctionEntry(name: "tanh", conversational: "hyperbolic tangent of", mathspeak: "hyperbolic tangent"),
                FunctionEntry(name: "arcsin", conversational: "arc sine of", mathspeak: "inverse sine"),
                FunctionEntry(name: "arccos", conversational: "arc cosine of", mathspeak: "inverse cosine"),
                FunctionEntry(name: "arctan", conversational: "arc tangent of", mathspeak: "inverse tangent"),
                FunctionEntry(name: "exp", conversational: "exponential of", mathspeak: "exponential of"),
                FunctionEntry(name: "log", conversational: "log of", mathspeak: "logarithm of"),
                FunctionEntry(name: "ln", conversational: "natural log of", mathspeak: "natural logarithm of"),
                FunctionEntry(name: "det", conversational: "determinant of", mathspeak: "determinant of"),
                FunctionEntry(name: "dim", conversational: "dimension of", mathspeak: "dimension of"),
                FunctionEntry(name: "rank", conversational: "rank of", mathspeak: "rank of"),
                FunctionEntry(name: "span", conversational: "span of", mathspeak: "span of"),
                FunctionEntry(name: "tr", conversational: "trace of", mathspeak: "trace of"),
                FunctionEntry(name: "diag", conversational: "diagonal of", mathspeak: "diagonal matrix of"),
                FunctionEntry(name: "argmax", conversational: "argument maximum", mathspeak: "argument of the maximum"),
                FunctionEntry(name: "argmin", conversational: "argument minimum", mathspeak: "argument of the minimum")
            ]
        }
    }
    
    private func loadGreek() {
        if let url = findFileURL(named: "greek"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let rawList = json["letters"] as? [[String: Any]] {
            self.greekLetters = rawList.compactMap { dict in
                guard let char = dict["char"] as? String,
                      let conv = dict["conversational"] as? String,
                      let math = dict["mathspeak"] as? String,
                      let upper = dict["is_uppercase"] as? Bool else { return nil }
                return GreekEntry(char: char, conversational: conv, mathspeak: math, is_uppercase: upper)
            }
        }
        
        if self.greekLetters.isEmpty {
            let pairs: [(String, String, Bool)] = [
                ("α", "alpha", false), ("β", "beta", false), ("γ", "gamma", false), ("δ", "delta", false),
                ("ε", "epsilon", false), ("ϵ", "epsilon", false), ("ζ", "zeta", false), ("η", "eta", false),
                ("θ", "theta", false), ("ϑ", "theta", false), ("ι", "iota", false), ("κ", "kappa", false),
                ("λ", "lambda", false), ("μ", "mu", false), ("ν", "nu", false), ("ξ", "xi", false),
                ("π", "pi", false), ("ϖ", "pi", false), ("ρ", "rho", false), ("ϱ", "rho", false),
                ("σ", "sigma", false), ("ς", "sigma", false), ("τ", "tau", false), ("υ", "upsilon", false),
                ("φ", "phi", false), ("ϕ", "phi", false), ("χ", "chi", false), ("ψ", "psi", false), ("ω", "omega", false),
                ("Α", "Alpha", true), ("Β", "Beta", true), ("Γ", "Gamma", true), ("Δ", "Delta", true),
                ("Ε", "Epsilon", true), ("Ζ", "Zeta", true), ("Η", "Eta", true), ("Θ", "Theta", true),
                ("Ι", "Iota", true), ("Κ", "Kappa", true), ("Λ", "Lambda", true), ("Μ", "Mu", true),
                ("Ν", "Nu", true), ("Ξ", "Xi", true), ("Ο", "Omicron", true), ("Π", "Pi", true),
                ("Ρ", "Rho", true), ("Σ", "Sigma", true), ("Τ", "Tau", true), ("Υ", "Upsilon", true),
                ("Φ", "Phi", true), ("Χ", "Chi", true), ("Ψ", "Psi", true), ("Ω", "Omega", true)
            ]
            self.greekLetters = pairs.map { glyph, name, isUp in
                GreekEntry(char: glyph, conversational: name, mathspeak: isUp ? "capital \(name)" : name, is_uppercase: isUp)
            }
        }
    }
    
    private func loadSIUnits() {
        if let url = findFileURL(named: "si_units"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let compounds = json["compound_units"] as? [[String: Any]] {
                self.compoundUnits = compounds.compactMap { d in
                    guard let sym = d["symbol"] as? String, let spk = d["spoken"] as? String else { return nil }
                    return CompoundUnitEntry(symbol: sym, spoken: spk)
                }
            }
            if let prefixed = json["units_prefixed"] as? [[String: Any]] {
                self.prefixedUnits = prefixed.compactMap { d in
                    guard let sym = d["symbol"] as? String,
                          let sing = d["singular"] as? String,
                          let plur = d["plural"] as? String else { return nil }
                    return UnitPrefixedEntry(symbol: sym, singular: sing, plural: plur)
                }
            }
        }
        
        if self.prefixedUnits.isEmpty {
            self.prefixedUnits = [
                UnitPrefixedEntry(symbol: "nm", singular: "nanometer", plural: "nanometers"),
                UnitPrefixedEntry(symbol: "μm", singular: "micrometer", plural: "micrometers"),
                UnitPrefixedEntry(symbol: "um", singular: "micrometer", plural: "micrometers"),
                UnitPrefixedEntry(symbol: "mm", singular: "millimeter", plural: "millimeters"),
                UnitPrefixedEntry(symbol: "cm", singular: "centimeter", plural: "centimeters"),
                UnitPrefixedEntry(symbol: "km", singular: "kilometer", plural: "kilometers"),
                UnitPrefixedEntry(symbol: "ns", singular: "nanosecond", plural: "nanoseconds"),
                UnitPrefixedEntry(symbol: "μs", singular: "microsecond", plural: "microseconds"),
                UnitPrefixedEntry(symbol: "us", singular: "microsecond", plural: "microseconds"),
                UnitPrefixedEntry(symbol: "ms", singular: "millisecond", plural: "milliseconds"),
                UnitPrefixedEntry(symbol: "mg", singular: "milligram", plural: "milligrams"),
                UnitPrefixedEntry(symbol: "kg", singular: "kilogram", plural: "kilograms"),
                UnitPrefixedEntry(symbol: "Hz", singular: "hertz", plural: "hertz"),
                UnitPrefixedEntry(symbol: "kHz", singular: "kilohertz", plural: "kilohertz"),
                UnitPrefixedEntry(symbol: "MHz", singular: "megahertz", plural: "megahertz"),
                UnitPrefixedEntry(symbol: "GHz", singular: "gigahertz", plural: "gigahertz"),
                UnitPrefixedEntry(symbol: "THz", singular: "terahertz", plural: "terahertz"),
                UnitPrefixedEntry(symbol: "mV", singular: "millivolt", plural: "millivolts"),
                UnitPrefixedEntry(symbol: "kV", singular: "kilovolt", plural: "kilovolts"),
                UnitPrefixedEntry(symbol: "mA", singular: "milliampere", plural: "milliamperes"),
                UnitPrefixedEntry(symbol: "μA", singular: "microampere", plural: "microamperes"),
                UnitPrefixedEntry(symbol: "mW", singular: "milliwatt", plural: "milliwatts"),
                UnitPrefixedEntry(symbol: "kW", singular: "kilowatt", plural: "kilowatts"),
                UnitPrefixedEntry(symbol: "MW", singular: "megawatt", plural: "megawatts"),
                UnitPrefixedEntry(symbol: "GW", singular: "gigawatt", plural: "gigawatts"),
                UnitPrefixedEntry(symbol: "eV", singular: "electron volt", plural: "electron volts"),
                UnitPrefixedEntry(symbol: "keV", singular: "kiloelectron volt", plural: "kiloelectron volts"),
                UnitPrefixedEntry(symbol: "MeV", singular: "megaelectron volt", plural: "megaelectron volts"),
                UnitPrefixedEntry(symbol: "GeV", singular: "gigaelectron volt", plural: "gigaelectron volts"),
                UnitPrefixedEntry(symbol: "Pa", singular: "pascal", plural: "pascals"),
                UnitPrefixedEntry(symbol: "kPa", singular: "kilopascal", plural: "kilopascals"),
                UnitPrefixedEntry(symbol: "MPa", singular: "megapascal", plural: "megapascals"),
                UnitPrefixedEntry(symbol: "mbar", singular: "millibar", plural: "millibars"),
                UnitPrefixedEntry(symbol: "bar", singular: "bar", plural: "bars"),
                UnitPrefixedEntry(symbol: "pF", singular: "picofarad", plural: "picofarads"),
                UnitPrefixedEntry(symbol: "nF", singular: "nanofarad", plural: "nanofarads"),
                UnitPrefixedEntry(symbol: "μF", singular: "microfarad", plural: "microfarads"),
                UnitPrefixedEntry(symbol: "uF", singular: "microfarad", plural: "microfarads"),
                UnitPrefixedEntry(symbol: "kΩ", singular: "kilo-ohm", plural: "kilo-ohms"),
                UnitPrefixedEntry(symbol: "MΩ", singular: "mega-ohm", plural: "mega-ohms"),
                UnitPrefixedEntry(symbol: "Ω", singular: "ohm", plural: "ohms"),
                UnitPrefixedEntry(symbol: "dB", singular: "decibel", plural: "decibels"),
                UnitPrefixedEntry(symbol: "mol", singular: "mole", plural: "moles"),
                UnitPrefixedEntry(symbol: "mmol", singular: "millimole", plural: "millimoles"),
                UnitPrefixedEntry(symbol: "KB", singular: "kilobyte", plural: "kilobytes"),
                UnitPrefixedEntry(symbol: "MB", singular: "megabyte", plural: "megabytes"),
                UnitPrefixedEntry(symbol: "GB", singular: "gigabyte", plural: "gigabytes"),
                UnitPrefixedEntry(symbol: "TB", singular: "terabyte", plural: "terabytes"),
                UnitPrefixedEntry(symbol: "V", singular: "volt", plural: "volts"),
                UnitPrefixedEntry(symbol: "W", singular: "watt", plural: "watts"),
                UnitPrefixedEntry(symbol: "J", singular: "joule", plural: "joules"),
                UnitPrefixedEntry(symbol: "N", singular: "newton", plural: "newtons")
            ]
        }
        
        if self.compoundUnits.isEmpty {
            self.compoundUnits = [
                CompoundUnitEntry(symbol: "km/h", spoken: "kilometers per hour"),
                CompoundUnitEntry(symbol: "m/s^2", spoken: "meters per second squared"),
                CompoundUnitEntry(symbol: "m/s²", spoken: "meters per second squared"),
                CompoundUnitEntry(symbol: "m/s", spoken: "meters per second"),
                CompoundUnitEntry(symbol: "kg/m^3", spoken: "kilograms per cubic meter"),
                CompoundUnitEntry(symbol: "kg/m³", spoken: "kilograms per cubic meter"),
                CompoundUnitEntry(symbol: "kW·h", spoken: "kilowatt hours"),
                CompoundUnitEntry(symbol: "kWh", spoken: "kilowatt hours")
            ]
        }
    }
    
    private func loadLatexMacros() {
        if let url = findFileURL(named: "latex_macros"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let rules = json["macro_rules"] as? [[String: Any]] {
                self.latexMacros = rules.compactMap { d in
                    guard let pat = d["pattern"] as? String,
                          let conv = d["conversational"] as? String,
                          let math = d["mathspeak"] as? String else { return nil }
                    return LatexMacroRule(pattern: pat, conversational: conv, mathspeak: math)
                }
            }
            if let delimiters = json["delimiter_rules"] as? [[String: Any]] {
                self.latexDelimiters = delimiters.compactMap { d in
                    guard let pat = d["pattern"] as? String,
                          let rep = d["replacement"] as? String else { return nil }
                    return DelimiterRule(pattern: pat, replacement: rep)
                }
            }
        }
        
        if self.latexMacros.isEmpty {
            self.latexMacros = [
                LatexMacroRule(pattern: "\\\\frac\\{([^\\{\\}]+)\\}\\{([^\\{\\}]+)\\}", conversational: "$1 over $2", mathspeak: "start fraction, $1, divided by, $2, end fraction"),
                LatexMacroRule(pattern: "\\\\sqrt\\[([^\\]]+)\\]\\{([^\\{\\}]+)\\}", conversational: "the $1th root of $2", mathspeak: "start root index $1, of, $2, end root"),
                LatexMacroRule(pattern: "\\\\sqrt\\{([^\\{\\}]+)\\}", conversational: "square root of $1", mathspeak: "start square root, $1, end square root"),
                LatexMacroRule(pattern: "\\\\sum_\\{([^\\}]+)\\}\\^\\{([^\\}]+)\\}", conversational: "sum from $1 to $2 of", mathspeak: "sum from $1 to $2 of"),
                LatexMacroRule(pattern: "\\\\sum_\\{([^\\}]+)\\}\\^([a-zA-Z0-9]+)", conversational: "sum from $1 to $2 of", mathspeak: "sum from $1 to $2 of"),
                LatexMacroRule(pattern: "\\\\sum_([a-zA-Z0-9]+)\\^([a-zA-Z0-9]+)", conversational: "sum from $1 to $2 of", mathspeak: "sum from $1 to $2 of"),
                LatexMacroRule(pattern: "\\\\int_\\{([^\\}]+)\\}\\^\\{([^\\}]+)\\}", conversational: "integral from $1 to $2 of", mathspeak: "integral from $1 to $2 of"),
                LatexMacroRule(pattern: "\\\\int_\\{([^\\}]+)\\}\\^([a-zA-Z0-9]+)", conversational: "integral from $1 to $2 of", mathspeak: "integral from $1 to $2 of"),
                LatexMacroRule(pattern: "\\\\int_([a-zA-Z0-9]+)\\^([a-zA-Z0-9]+)", conversational: "integral from $1 to $2 of", mathspeak: "integral from $1 to $2 of"),
                LatexMacroRule(pattern: "\\\\prod_\\{([^\\}]+)\\}\\^\\{([^\\}]+)\\}", conversational: "product from $1 to $2 of", mathspeak: "product from $1 to $2 of"),
                LatexMacroRule(pattern: "\\\\mathbf\\{([^\\}]+)\\}", conversational: "bold $1", mathspeak: "bold $1"),
                LatexMacroRule(pattern: "\\\\mathbb\\{([^\\}]+)\\}", conversational: "$1", mathspeak: "blackboard bold $1"),
                LatexMacroRule(pattern: "\\\\mathcal\\{([^\\}]+)\\}", conversational: "calligraphic $1", mathspeak: "calligraphic $1"),
                LatexMacroRule(pattern: "\\\\(?:text|mathrm|textrm)\\{([^\\}]+)\\}", conversational: "$1", mathspeak: "$1")
            ]
        }
        
        if self.latexDelimiters.isEmpty {
            self.latexDelimiters = [
                DelimiterRule(pattern: "\\\\left\\(", replacement: "("),
                DelimiterRule(pattern: "\\\\right\\)", replacement: ")"),
                DelimiterRule(pattern: "\\\\left\\[", replacement: "["),
                DelimiterRule(pattern: "\\\\right\\]", replacement: "]"),
                DelimiterRule(pattern: "\\\\left\\\\\\{", replacement: "{"),
                DelimiterRule(pattern: "\\\\right\\\\\\}", replacement: "}"),
                DelimiterRule(pattern: "\\\\left\\|", replacement: "|"),
                DelimiterRule(pattern: "\\\\right\\|", replacement: "|")
            ]
        }
    }
    
    // MARK: - Regular Expression Helper
    
    private func regex(for pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        regexLock.lock()
        defer { regexLock.unlock() }
        let key = "\(pattern)_\(options.rawValue)"
        if let cached = cachedRegexes[key] {
            return cached
        }
        if let compiled = try? NSRegularExpression(pattern: pattern, options: options) {
            cachedRegexes[key] = compiled
            return compiled
        }
        return nil
    }
    
    // MARK: - Main Normalization Pipeline
    
    public func normalizeMath(_ text: String, style: MathSpeechStyle = .conversational) -> String {
        return TextNormalizer.shared.normalizeForSpeech(text, mathStyle: style)
    }
    
    // MARK: - 1. LaTeX Macros
    
    public func translateLatexMacros(_ text: String, style: MathSpeechStyle) -> String {
        guard text.contains("\\") else { return text }
        var result = text
        
        // Delimiters
        for delim in latexDelimiters {
            result = result.replacingOccurrences(of: delim.pattern, with: delim.replacement, options: .regularExpression)
        }
        
        // Macros (loop to support nested macros like \frac{\frac{a}{b}}{c})
        for macro in latexMacros {
            let template = (style == .mathSpeakRigorous) ? macro.mathspeak : macro.conversational
            var changed = true
            var passes = 0
            while changed && passes < 5 {
                let prev = result
                result = result.replacingOccurrences(of: macro.pattern, with: template, options: .regularExpression)
                changed = (result != prev)
                passes += 1
            }
        }
        
        return result
    }
    
    // MARK: - 2. Scientific Notation
    
    public func vocalizeScientificNotation(_ text: String, style: MathSpeechStyle) -> String {
        var result = text
        
        // A. Standard e-notation: 6.022e23, 1.5E-4, -3e-9, 1e3
        let ePattern = #"(?<![a-zA-Z0-9_])([+-]?\d+(?:\.\d+)?)[eE]([+-]?\d+)(?![a-zA-Z0-9_])"#
        if let regex = regex(for: ePattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                let mantissa = nsString.substring(with: match.range(at: 1))
                let exponentStr = nsString.substring(with: match.range(at: 2))
                if let exp = Int(exponentStr) {
                    let spoken = spokenScientificForm(mantissa: mantissa, exponent: exp, style: style)
                    result = (result as NSString).replacingCharacters(in: match.range, with: spoken)
                }
            }
        }
        
        // B. Explicit power of ten: 6.022 x 10^23, 1.5 * 10^-4, 3.0 × 10^8
        let explicitPattern = #"(?<![a-zA-Z0-9_])([+-]?\d+(?:\.\d+)?)\s*(?:[x×*]|\*|\\times)\s*10\s*(?:\^|\*\*)\s*\{?([+-]?\d+)\}?(?![a-zA-Z0-9_])"#
        if let regex = regex(for: explicitPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                let mantissa = nsString.substring(with: match.range(at: 1))
                let exponentStr = nsString.substring(with: match.range(at: 2))
                if let exp = Int(exponentStr) {
                    let spoken = spokenScientificForm(mantissa: mantissa, exponent: exp, style: style)
                    result = (result as NSString).replacingCharacters(in: match.range, with: spoken)
                }
            }
        }
        
        return result
    }
    
    private func spokenScientificForm(mantissa: String, exponent: Int, style: MathSpeechStyle) -> String {
        var mantissaSpoken = mantissa
        if mantissaSpoken.hasPrefix("-") {
            mantissaSpoken = "negative " + mantissaSpoken.dropFirst()
        } else if mantissaSpoken.hasPrefix("+") {
            mantissaSpoken = String(mantissaSpoken.dropFirst())
        }
        
        switch style {
        case .conversational:
            if exponent == 0 {
                return "\(mantissaSpoken) times ten to the power of zero"
            } else if exponent > 0 {
                if exponent == 2 {
                    return "\(mantissaSpoken) times ten squared"
                } else if exponent == 3 {
                    return "\(mantissaSpoken) times ten cubed"
                } else if let ordinal = ordinalPowers[exponent] {
                    return "\(mantissaSpoken) times ten to the \(ordinal)"
                } else {
                    let cardinalWord = spellOutFormatter.string(from: NSNumber(value: exponent)) ?? "\(exponent)"
                    return "\(mantissaSpoken) times ten to the power of \(cardinalWord)"
                }
            } else {
                let absExp = abs(exponent)
                let cardinalWord = spellOutFormatter.string(from: NSNumber(value: absExp)) ?? "\(absExp)"
                return "\(mantissaSpoken) times ten to the minus \(cardinalWord)"
            }
            
        case .mathSpeakRigorous:
            if exponent >= 0 {
                let cardinalWord = spellOutFormatter.string(from: NSNumber(value: exponent)) ?? "\(exponent)"
                return "\(mantissaSpoken) times ten to the power \(cardinalWord)"
            } else {
                let absExp = abs(exponent)
                let cardinalWord = spellOutFormatter.string(from: NSNumber(value: absExp)) ?? "\(absExp)"
                return "\(mantissaSpoken) times ten to the negative \(cardinalWord) power"
            }
        }
    }
    
    // MARK: - 3. SI Units and Prefixes
    
    public func vocalizeSIUnits(_ text: String) -> String {
        var result = text
        
        // 1. Compound units (e.g., km/h, m/s, m/s^2, m/s², kW·h, kWh)
        let sortedCompounds = compoundUnits.sorted { $0.symbol.count > $1.symbol.count }
        for compound in sortedCompounds {
            let escaped = NSRegularExpression.escapedPattern(for: compound.symbol)
            let pattern = #"(\b\d+(?:\.\d+)?)\s*"# + escaped + #"(?![a-zA-Z0-9/·^²³])"#
            if let regex = self.regex(for: pattern) {
                let ns = result as NSString
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length))
                if !matches.isEmpty {
                    let mutable = NSMutableString(string: result)
                    for match in matches.reversed() {
                        let num = ns.substring(with: match.range(at: 1))
                        mutable.replaceCharacters(in: match.range, with: "\(num) \(compound.spoken)")
                    }
                    result = mutable as String
                }
            }
        }
        
        // 2. Prefixed & base units preceded by numeric digits: e.g. 5 nm, 2.4 GHz, 100 ms, 12 V
        let sortedPrefixed = prefixedUnits.sorted { $0.symbol.count > $1.symbol.count }
        let unitSymbols = sortedPrefixed.map { NSRegularExpression.escapedPattern(for: $0.symbol) }.joined(separator: "|")
        let unitPattern = #"(\b\d+(?:\.\d+)?)\s*("# + unitSymbols + #")\b"#
        
        if let regex = self.regex(for: unitPattern) {
            let ns = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                let unitMap = Dictionary(prefixedUnits.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
                let mutable = NSMutableString(string: result)
                for match in matches.reversed() {
                    let num = ns.substring(with: match.range(at: 1))
                    let unit = ns.substring(with: match.range(at: 2))
                    if let entry = unitMap[unit] {
                        let isSingular = (num == "1" || num == "1.0")
                        let spoken = isSingular ? entry.singular : entry.plural
                        mutable.replaceCharacters(in: match.range, with: "\(num) \(spoken)")
                    }
                }
                result = mutable as String
            }
        }
        
        return result
    }
    
    // MARK: - 4. Functions and Limits
    
    public func vocalizeFunctions(_ text: String, style: MathSpeechStyle) -> String {
        var result = text
        
        // Limits: lim_{x -> 0} or lim_{x \to \infty}
        let limPattern = #"\blim\s*_\s*\{?([a-zA-Z])\s*(?:[→⟶]|\\to|->|-->)\s*([0-9a-zA-Z∞]+)\}?"#
        result = result.replacingOccurrences(
            of: limPattern,
            with: "limit as $1 approaches $2 of ",
            options: .regularExpression
        )
        
        // Trigonometric, logarithmic, and linear algebra functions
        for fn in functions {
            let spoken = (style == .mathSpeakRigorous) ? fn.mathspeak : fn.conversational
            // Function followed by parenthesis: sin(x) -> sine of (x)
            let fnWithParen = "\\b" + fn.name + "\\s*\\("
            result = result.replacingOccurrences(of: fnWithParen, with: spoken + " (", options: .regularExpression)
        }
        
        return result
    }
    
    // MARK: - 5. Operators, Relations, and Symbols
    
    public func vocalizeSymbols(_ text: String, style: MathSpeechStyle) -> String {
        var result = text
        for entry in symbols {
            guard result.contains(entry.char) else { continue }
            let spoken = (style == .mathSpeakRigorous) ? entry.mathspeak : entry.conversational
            result = result.replacingOccurrences(of: entry.char, with: " \(spoken) ")
        }
        return result
    }
    
    // MARK: - 6. Greek Alphabet
    
    public func vocalizeGreek(_ text: String, style: MathSpeechStyle) -> String {
        var result = text
        for letter in greekLetters {
            guard result.contains(letter.char) else { continue }
            let spoken = (style == .mathSpeakRigorous) ? letter.mathspeak : letter.conversational
            result = result.replacingOccurrences(of: letter.char, with: " \(spoken) ")
        }
        return result
    }
    
    // MARK: - 7. Subscripts, Linear Algebra Equations, and Ellipses
    
    public func vocalizeSubscriptsAndEquations(_ text: String, style: MathSpeechStyle) -> String {
        var result = text
        
        // 1. Spacing around equality and operators in equations
        // e.g. xn= b1 -> xn = b1, a11x1+···+a1nxn= b1 -> a11x1 + ··· + a1nxn = b1
        result = result.replacingOccurrences(of: #"([a-zA-Z0-9])=([a-zA-Z0-9])"#, with: "$1 = $2", options: .regularExpression)
        result = result.replacingOccurrences(of: #"([a-zA-Z0-9])=\s*"#, with: "$1 = ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s*=([a-zA-Z0-9])"#, with: " = $1", options: .regularExpression)
        
        // 2. Midline ellipsis surrounded by plus operators: +···+ or + ··· + or +...+
        let ellipsisSpoken = (style == .mathSpeakRigorous) ? "plus ellipsis, plus" : "plus and so on, plus"
        result = result.replacingOccurrences(
            of: #"\+\s*(?:···|⋯|\.\.\.|…)\s*\+"#,
            with: " \(ellipsisSpoken) ",
            options: .regularExpression
        )
        
        // 3. Sequence ellipsis with commas: x1,...,xn or (x1,...,xn) or R1,..., R m
        // Replace with "x 1 through x n" (conversational) or "x 1, ellipsis, x n" (mathspeak)
        let seqEllipsisSpoken = (style == .mathSpeakRigorous) ? ", ellipsis, " : " through "
        result = result.replacingOccurrences(
            of: #"\b([a-zA-Z][0-9a-zA-Z]?)\s*,\s*(?:\.\.\.|···|…)\s*,\s*([a-zA-Z])\s*([0-9a-zA-Z]?)\b"#,
            with: "$1\(seqEllipsisSpoken)$2 $3",
            options: .regularExpression
        )
        
        // 4. Linear combination coefficient-variables (fused or space-separated):
        // a11x1, a12x2, a1nxn, ai1x1, am1x1, amnxn, aijxj, amn xn
        // Restricted to coefficient letters a..d, A..D, u..w, U..W with valid subscript:
        // - digits: "11", "12", "1"
        // - mixed: "1n", "2n", "m1", "i1"
        // - dual indices: "mn", "ij", "ik"
        // Followed optionally by spaces, then variable x..z, X..Z with index:
        // - digits: "1", "2"
        // - index letters: "n", "j", "i", "m", "k"
        let fusedRegex = #"\b([a-dA-Du-wU-W])([0-9]{1,2}|[0-9][a-zA-Z]|[a-zA-Z][0-9]|[ijknmIJKNM]{2})\s*([x-zX-Z])([0-9]{1,2}|[ijknmIJKNM])\b"#
        if let regex = regex(for: fusedRegex) {
            let ns = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                let ms = NSMutableString(string: result)
                for m in matches.reversed() {
                    let coeffLetter = ns.substring(with: m.range(at: 1))
                    let coeffSub = ns.substring(with: m.range(at: 2))
                    let varLetter = ns.substring(with: m.range(at: 3))
                    let varSub = ns.substring(with: m.range(at: 4))
                    
                    let coeffSubSpoken = formatSubscript(coeffSub, style: style)
                    let varSubSpoken = formatSubscript(varSub, style: style)
                    
                    let replacement = "\(coeffLetter) \(coeffSubSpoken), \(varLetter) \(varSubSpoken)"
                    ms.replaceCharacters(in: m.range, with: replacement)
                }
                result = ms as String
            }
        }
        
        // 5. Standalone double-digit matrix elements: a11, a12, a21, a22, b11
        // Spoken digit-by-digit: "a 1 1" or "a sub 1 1", NEVER "a eleven"
        let doubleSubRegex = #"\b([a-dA-Du-wU-W]|[x-zX-Z]|[bB])([0-9])([0-9])\b"#
        if let regex = regex(for: doubleSubRegex) {
            let ns = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                let ms = NSMutableString(string: result)
                for m in matches.reversed() {
                    let letter = ns.substring(with: m.range(at: 1))
                    let d1 = ns.substring(with: m.range(at: 2))
                    let d2 = ns.substring(with: m.range(at: 3))
                    let rep = (style == .mathSpeakRigorous) ? "\(letter) sub \(d1) \(d2)" : "\(letter) \(d1) \(d2)"
                    ms.replaceCharacters(in: m.range, with: rep)
                }
                result = ms as String
            }
        }
        
        // 6. Common matrix elements with symbolic/mixed subscripts: a1n, am1, amn, aij, ai1
        let commonMatrixSubs = [
            ("a1n", style == .mathSpeakRigorous ? "a sub 1 n" : "a 1 n"),
            ("am1", style == .mathSpeakRigorous ? "a sub m 1" : "a m 1"),
            ("amn", style == .mathSpeakRigorous ? "a sub m n" : "a m n"),
            ("ai1", style == .mathSpeakRigorous ? "a sub i 1" : "a i 1"),
            ("aij", style == .mathSpeakRigorous ? "a sub i j" : "a i j")
        ]
        for (token, spoken) in commonMatrixSubs {
            result = result.replacingOccurrences(of: "\\b\(token)\\b", with: spoken, options: .regularExpression)
        }
        
        // 7. Single-letter variables with numeric or symbolic subscripts:
        // A. Numeric subscripts: x1, x2, b1, b2, a1, R1
        let numericSubPattern = #"\b([a-dA-Du-zU-Z]|[rR])([0-9]{1,2})\b"#
        if let regex = regex(for: numericSubPattern) {
            let ns = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                let ms = NSMutableString(string: result)
                for m in matches.reversed() {
                    let letter = ns.substring(with: m.range(at: 1))
                    let sub = ns.substring(with: m.range(at: 2))
                    let rep = (style == .mathSpeakRigorous) ? "\(letter) sub \(sub)" : "\(letter) \(sub)"
                    ms.replaceCharacters(in: m.range, with: rep)
                }
                result = ms as String
            }
        }
        
        // B. Symbolic subscripts for variables (x, y, z) and vectors (b): xj, xi, xn, xm, bi, bm
        // Strictly lowercase index letters to avoid colliding with acronyms (like AI, BI, AM)
        let symbolicSubPattern = #"\b([xyzXYZ]|[bB])([ijknm])\b"#
        if let regex = regex(for: symbolicSubPattern) {
            let ns = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                let ms = NSMutableString(string: result)
                for m in matches.reversed() {
                    let letter = ns.substring(with: m.range(at: 1))
                    let sub = ns.substring(with: m.range(at: 2))
                    let rep = (style == .mathSpeakRigorous) ? "\(letter) sub \(sub)" : "\(letter) \(sub)"
                    ms.replaceCharacters(in: m.range, with: rep)
                }
                result = ms as String
            }
        }
        
        // 8. Standalone equals in equation context
        result = result.replacingOccurrences(of: #"(?<=\s)=(?=\s)"#, with: "equals", options: .regularExpression)
        
        return result
    }
    
    private func formatSubscript(_ sub: String, style: MathSpeechStyle) -> String {
        // Break multiple characters into spaced characters: e.g. "11" -> "1 1", "1n" -> "1 n", "m1" -> "m 1"
        let spaced = sub.map { String($0) }.joined(separator: " ")
        if style == .mathSpeakRigorous {
            return "sub \(spaced)"
        } else {
            return spaced
        }
    }
}
