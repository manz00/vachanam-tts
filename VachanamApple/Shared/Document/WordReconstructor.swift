//
//  WordReconstructor.swift
//  Vachanam
//
//  Reconstructs words broken across PDF visual line breaks while preserving
//  genuine hyphenated compounds (e.g. 'well-known', 'state-of-the-art').
//

#if canImport(UIKit)
import UIKit
#endif
import Foundation

public struct WordReconstructionResult: Equatable {
    public let reconstructedWord: String
    public let wasHyphenJoined: Bool
    public let preservedHyphen: Bool
    
    public init(reconstructedWord: String, wasHyphenJoined: Bool, preservedHyphen: Bool) {
        self.reconstructedWord = reconstructedWord
        self.wasHyphenJoined = wasHyphenJoined
        self.preservedHyphen = preservedHyphen
    }
}

public class WordReconstructor {
    public static let shared = WordReconstructor()
    
    #if canImport(UIKit)
    private let textChecker = UITextChecker()
    #endif
    
    // Common morphemes/suffixes that appear in line-break hyphenations
    private let commonSuffixes: Set<String> = [
        "ity", "tion", "sion", "ment", "ing", "ed", "able", "ible",
        "ize", "ise", "ness", "ical", "ous", "ence", "ance", "istic",
        "ally", "ive", "ful", "less", "est", "er", "or", "ly", "ism",
        "ist", "ary", "ery", "ory", "al", "ial", "ian", "ic", "logy",
        "graphy", "meter", "scopic", "phobia", "philic", "genesis"
    ]
    
    public init() {}
    
    /// Evaluates two consecutive word fragments separated by a line break.
    /// Returns the resolved word and whether the hyphen was dropped or retained.
    public func resolveHyphenation(firstPart: String, secondPart: String) -> WordReconstructionResult {
        let trimmedFirst = firstPart.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecond = secondPart.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedFirst.hasSuffix("-") || trimmedFirst.hasSuffix("\u{2010}") || trimmedFirst.hasSuffix("\u{2011}") else {
            return WordReconstructionResult(
                reconstructedWord: trimmedFirst + " " + trimmedSecond,
                wasHyphenJoined: false,
                preservedHyphen: false
            )
        }
        
        let prefix = String(trimmedFirst.dropLast()).trimmingCharacters(in: .whitespaces)
        let suffix = trimmedSecond
        
        guard !prefix.isEmpty && !suffix.isEmpty else {
            return WordReconstructionResult(
                reconstructedWord: trimmedFirst + trimmedSecond,
                wasHyphenJoined: false,
                preservedHyphen: true
            )
        }
        
        let merged = prefix + suffix
        let hyphenated = prefix + "-" + suffix
        
        #if canImport(UIKit)
        let mergedValid = isValidWord(merged)
        let hyphenatedValid = isValidWord(hyphenated)
        let prefixValid = isValidWord(prefix)
        let suffixValid = isValidWord(suffix)
        
        // 1. If merged is a valid word and hyphenated is not, definitely join without hyphen (e.g. "probability")
        if mergedValid && !hyphenatedValid {
            return WordReconstructionResult(
                reconstructedWord: merged,
                wasHyphenJoined: true,
                preservedHyphen: false
            )
        }
        
        // 2. If hyphenated is valid and merged is not, keep the hyphen (e.g. "well-known")
        if hyphenatedValid && !mergedValid {
            return WordReconstructionResult(
                reconstructedWord: hyphenated,
                wasHyphenJoined: true,
                preservedHyphen: true
            )
        }
        
        // 3. Both prefix and suffix are standalone valid words -> strong signal for compound word
        if prefixValid && suffixValid {
            // E.g. "user" and "friendly", "high" and "level", "state" and "of"
            return WordReconstructionResult(
                reconstructedWord: hyphenated,
                wasHyphenJoined: true,
                preservedHyphen: true
            )
        }
        #endif
        
        // 4. Suffix heuristic check: if second part is a known bound morpheme / suffix
        let lowerSuffix = suffix.lowercased()
        if commonSuffixes.contains(lowerSuffix) {
            return WordReconstructionResult(
                reconstructedWord: merged,
                wasHyphenJoined: true,
                preservedHyphen: false
            )
        }
        
        // 5. If second part starts with lowercase and is not a stand-alone word
        if let firstChar = suffix.first, firstChar.isLowercase {
            return WordReconstructionResult(
                reconstructedWord: merged,
                wasHyphenJoined: true,
                preservedHyphen: false
            )
        }
        
        // Default fallback: preserve hyphen if unclear
        return WordReconstructionResult(
            reconstructedWord: hyphenated,
            wasHyphenJoined: true,
            preservedHyphen: true
        )
    }
    
    #if canImport(UIKit)
    private func isValidWord(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelled = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en_US"
        )
        return misspelled.location == NSNotFound
    }
    #endif
}
