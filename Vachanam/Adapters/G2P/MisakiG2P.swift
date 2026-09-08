//
//  MisakiG2P.swift
//  Vachanam
//
//  Lightweight English phonemizer based on Misaki rules for Kokoro TTS.
//

import Foundation

public class MisakiG2P: G2PProtocol {
    public static let shared = MisakiG2P()
    
    // Core phonetic lookup cache for common English words
    private let phonemeDictionary: [String: String] = [
        "the": "ðə", "of": "ʌv", "to": "tuː", "and": "ænd", "a": "ə",
        "in": "ɪn", "is": "ɪz", "it": "ɪt", "you": "juː", "that": "ðæt",
        "he": "hiː", "was": "wɒz", "for": "fɔːr", "on": "ɒn", "are": "ɑːr",
        "with": "wɪð", "as": "æz", "i": "aɪ", "his": "hɪz", "they": "ðeɪ",
        "be": "biː", "at": "æt", "one": "wʌn", "have": "hæv", "this": "ðɪs",
        "from": "frɒm", "by": "baɪ", "not": "nɒt", "word": "wɜːrd", "but": "bʌt",
        "what": "wɒt", "some": "sʌm", "we": "wiː", "can": "kæn", "out": "aʊt",
        "other": "ˈʌðər", "were": "wɜːr", "all": "ɔːl", "there": "ðɛər", "when": "wɛn"
    ]
    
    public init() {}
    
    public func phonemize(text: String, language: String = "en-US") -> [String] {
        let cleanText = text.lowercased().filter { $0.isLetter || $0.isWhitespace }
        let words = cleanText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        return words.map { word in
            if let mapped = phonemeDictionary[word] {
                return mapped
            }
            return fallbackPhonemizeWord(word)
        }
    }
    
    private func fallbackPhonemizeWord(_ word: String) -> String {
        // Fallback rule-based phonetic approximation
        var result = ""
        for char in word {
            switch char {
            case "a": result += "æ"
            case "e": result += "e"
            case "i": result += "ɪ"
            case "o": result += "ɒ"
            case "u": result += "ʌ"
            case "c": result += "k"
            case "j": result += "dʒ"
            case "q": result += "kw"
            case "x": result += "ks"
            default: result += String(char)
            }
        }
        return result
    }
}
