import Foundation
import MisakiSwift

/// MisakiSwift-backed English phonemizer used by the raw-text SDK.
///
/// This matches the Gist iOS app pattern: use the mattmireles MisakiSwift fork
/// for on-device English G2P and keep it out of the lower-floor
/// ``KokoroPipeline`` package.
public final class KokoroMisakiPhonemizer: KokoroPhonemizer {
    /// Underlying Misaki English grapheme-to-phoneme engine.
    ///
    /// MisakiSwift initializes MLX resources when `EnglishG2P` is created.
    /// Keep this cached instance lazy so `KokoroTTS.load` can validate
    /// resources and return from app startup without touching MLX; the first
    /// `prepare` or `synthesize` call pays the G2P setup cost.
    private var cachedG2P: EnglishG2P?

    /// Serializes access to ``cachedG2P`` and its mutable NLP state.
    ///
    /// Swift `lazy var` is not a synchronization primitive, and Misaki's
    /// `EnglishG2P` owns mutable tagger state. This class is public, so callers
    /// may share one phonemizer across tasks even though the `KokoroTTS` facade
    /// itself is actor-isolated.
    private let g2pLock = NSLock()

    /// Whether this phonemizer uses the British English Misaki path.
    public let british: Bool

    /// Creates a MisakiSwift-backed phonemizer.
    ///
    /// - Parameter british: When true, asks MisakiSwift for British English
    ///   phonemes. The default is the U.S. English path used by `af_*` voices.
    public init(british: Bool = false) {
        self.british = british
    }

    /// Marker Misaki substitutes for a word it could not resolve.
    ///
    /// Matches `EnglishG2P(unk:)`'s default. The marker has no Kokoro vocab
    /// entry, so it evaporates during tokenization: without counting it here the
    /// loss leaves no trace at all.
    static let unknownMarker: Character = "❓"

    /// Converts raw text to Kokoro-compatible phonemes with MisakiSwift.
    ///
    /// - Parameter text: Raw English text.
    /// - Returns: Non-empty phonemes, their UTF-16 length, and the dropped-word count.
    public func phonemize(_ text: String) throws -> KokoroPhonemeResult {
        let result = phonemizeLocked(text)
        guard !result.phonemes.isEmpty else {
            throw KokoroPhonemizerError.emptyOutput
        }
        return KokoroPhonemeResult(
            phonemes: result.phonemes,
            droppedTokens: result.droppedTokens
        )
    }

    /// Runs Misaki under lock because `EnglishG2P` owns mutable NLP state.
    ///
    /// Misaki's per-word `MToken` type is vended by a transitive dependency that
    /// this package does not import, so the token array is consumed inline where
    /// type inference supplies its element type. Only the two fields that matter
    /// cross into ``isDroppedToken(text:phonemes:)``, which stays testable.
    ///
    /// - Parameter text: Raw English text.
    /// - Returns: Phoneme string and the count of words that lost their sound.
    private func phonemizeLocked(_ text: String) -> (phonemes: String, droppedTokens: Int) {
        g2pLock.lock()
        defer { g2pLock.unlock() }
        #if targetEnvironment(simulator)
        return phonemizeSimulator(text)
        #else
        let g2p: EnglishG2P
        if let cachedG2P {
            g2p = cachedG2P
        } else {
            g2p = EnglishG2P(british: british)
            cachedG2P = g2p
        }
        let result = g2p.phonemize(text: text)
        let droppedTokens = result.1.reduce(into: 0) { total, token in
            if Self.isDroppedToken(text: token.text, phonemes: token.phonemes) {
                total += 1
            }
        }
        return (result.0, droppedTokens)
        #endif
    }

    /// Returns whether one Misaki token lost the word it stood for.
    ///
    /// Only words carrying letters or digits count. Punctuation tokens
    /// legitimately carry no phonemes and must never be reported as loss.
    ///
    /// - Parameters:
    ///   - text: Source word the token covers.
    ///   - phonemes: Phonemes Misaki resolved for it, if any.
    /// - Returns: True when a speech-bearing word produced no usable phonemes.
    static func isDroppedToken(text: String, phonemes: String?) -> Bool {
        guard text.contains(where: { $0.isLetter || $0.isNumber }) else {
            return false
        }
        let resolved = phonemes ?? ""
        return resolved.allSatisfy(\.isWhitespace) || resolved.contains(unknownMarker)
    }

    #if targetEnvironment(simulator)
    private static var simulatorDictCache: [Bool: [String: String]] = [:]
    private static let cacheLock = NSLock()

    private func loadSimulatorDictionary() -> [String: String] {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        if let cached = Self.simulatorDictCache[british] {
            return cached
        }
        var dict: [String: String] = [:]
        let names = british ? ["gb_gold", "gb_silver"] : ["us_gold", "us_silver"]
        for name in names {
            if let url = Self.findResourceURL(name: name, ext: "json"),
               let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (k, v) in json {
                    if let s = v as? String {
                        dict[k] = s
                        dict[k.lowercased()] = s
                    }
                }
            }
        }
        // Common fallback mappings
        let common: [String: String] = [
            "accessibility": "əksˌɛsəbˈɪləɾi",
            "empowers": "ɪmpˈWəɹz",
            "empower": "ɪmpˈWəɹ",
            "every": "ˈɛvəɹi",
            "reader": "ɹˈidəɹ",
            "with": "wɪð",
            "voice": "vˈYs",
            "hello": "həlˈoʊ",
            "world": "wˈɜːrld",
            "ready": "ɹˈɛdi",
            "the": "ðə", "of": "ʌv", "to": "tuː", "and": "ænd", "a": "ə",
            "in": "ɪn", "is": "ɪz", "it": "ɪt", "you": "juː", "that": "ðæt",
            "he": "hiː", "was": "wɒz", "for": "fɔːr", "on": "ɒn", "are": "ɑːr",
            "as": "æz", "i": "aɪ", "his": "hɪz", "they": "ðeɪ", "be": "biː",
            "at": "æt", "one": "wʌn", "have": "hæv", "this": "ðɪs", "from": "frɒm",
            "by": "baɪ", "not": "nɒt", "word": "wɜːrd", "but": "bʌt", "what": "wɒt",
            "some": "sʌm", "we": "wiː", "can": "kæn", "out": "aʊt", "other": "ˈʌðər",
            "were": "wɜːr", "all": "ɔːl", "there": "ðɛər", "when": "wɛn"
        ]
        for (k, v) in common {
            dict[k] = v
        }
        Self.simulatorDictCache[british] = dict
        return dict
    }

    private static func findResourceURL(name: String, ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "KokoroModels") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "KokoroModels") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "MisakiData") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private func phonemizeSimulator(_ text: String) -> (phonemes: String, droppedTokens: Int) {
        let dict = loadSimulatorDictionary()
        var result = ""
        var currentWord = ""
        
        func flushWord() {
            guard !currentWord.isEmpty else { return }
            let lower = currentWord.lowercased()
            if let p = dict[currentWord] ?? dict[lower] {
                result += p
            } else if lower.hasSuffix("s") && lower.count > 2, let p = dict[String(lower.dropLast())] {
                result += p + "z"
            } else if lower.hasSuffix("ed") && lower.count > 3, let p = dict[String(lower.dropLast(2))] {
                result += p + "d"
            } else if lower.hasSuffix("ing") && lower.count > 4, let p = dict[String(lower.dropLast(3))] {
                result += p + "ɪŋ"
            } else if lower.hasSuffix("ly") && lower.count > 3, let p = dict[String(lower.dropLast(2))] {
                result += p + "li"
            } else {
                result += ruleBasedPhonemize(lower)
            }
            currentWord = ""
        }
        
        for char in text {
            if char.isLetter || char == "'" {
                currentWord.append(char)
            } else {
                flushWord()
                result.append(char)
            }
        }
        flushWord()
        
        return (result, 0)
    }

    private func ruleBasedPhonemize(_ word: String) -> String {
        var phonemes = ""
        let chars = Array(word)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next: Character? = (i + 1 < chars.count) ? chars[i + 1] : nil
            if c == "t" && next == "h" {
                phonemes += "ð"
                i += 2
                continue
            }
            if c == "s" && next == "h" {
                phonemes += "ʃ"
                i += 2
                continue
            }
            if c == "c" && next == "h" {
                phonemes += "ʧ"
                i += 2
                continue
            }
            if c == "p" && next == "h" {
                phonemes += "f"
                i += 2
                continue
            }
            if c == "n" && next == "g" {
                phonemes += "ŋ"
                i += 2
                continue
            }
            if c == "e" && next == "e" {
                phonemes += "i"
                i += 2
                continue
            }
            if c == "o" && next == "o" {
                phonemes += "u"
                i += 2
                continue
            }
            switch c {
            case "a": phonemes += "æ"
            case "e": phonemes += "ɛ"
            case "i": phonemes += "ɪ"
            case "o": phonemes += "ɑ"
            case "u": phonemes += "ʌ"
            case "c": phonemes += (next == "e" || next == "i" || next == "y") ? "s" : "k"
            case "j": phonemes += "ʤ"
            case "q": phonemes += "kw"
            case "r": phonemes += "ɹ"
            case "x": phonemes += "ks"
            case "y": phonemes += "i"
            default:
                if c.isLetter {
                    phonemes += String(c)
                }
            }
            i += 1
        }
        return phonemes.isEmpty ? word : phonemes
    }
    #endif
}
