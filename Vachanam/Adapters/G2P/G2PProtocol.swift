//
//  G2PProtocol.swift
//  Vachanam
//
//  Grapheme-to-Phoneme phonemizer abstraction for models requiring phonetic input.
//

import Foundation

public protocol G2PProtocol {
    func phonemize(text: String, language: String) -> [String]
    func phonemeString(from text: String, language: String) -> String
}

public extension G2PProtocol {
    func phonemeString(from text: String, language: String) -> String {
        phonemize(text: text, language: language).joined(separator: " ")
    }
}
