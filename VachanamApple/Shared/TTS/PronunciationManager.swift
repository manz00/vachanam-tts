//
//  PronunciationManager.swift
//  Vachanam
//
//  Layered pronunciation dictionary system supporting Global, Book, and User rules
//  with case-insensitive word-boundary replacements, phonetic overrides, and cache invalidation.
//

import Foundation

public enum PronunciationScope: String, Codable, Sendable {
    case global
    case book
    case user
}

public struct PronunciationRule: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var match: String
    public var spokenText: String
    public var phonemes: String?
    public var scope: PronunciationScope
    public var documentID: UUID?
    public var note: String?
    
    public init(
        id: UUID = UUID(),
        match: String,
        spokenText: String,
        phonemes: String? = nil,
        scope: PronunciationScope = .user,
        documentID: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.match = match
        self.spokenText = spokenText
        self.phonemes = phonemes
        self.scope = scope
        self.documentID = documentID
        self.note = note
    }
}

public class PronunciationManager: ObservableObject, @unchecked Sendable {
    public static let shared = PronunciationManager()
    
    @Published public private(set) var userRules: [PronunciationRule] = []
    @Published public private(set) var bookRules: [UUID: [PronunciationRule]] = [:]
    @Published public private(set) var revision: Int = 1
    
    private let lock = NSLock()
    private let userDefaultsKey = "vachanam_user_pronunciation_rules"
    private let bookDefaultsKey = "vachanam_book_pronunciation_rules"
    
    // Built-in global technical, mathematical, and common pronunciation rules
    public let globalRules: [PronunciationRule] = [
        PronunciationRule(match: "TTS", spokenText: "text to speech", scope: .global, note: "Acronym"),
        PronunciationRule(match: "API", spokenText: "A P I", scope: .global, note: "Acronym"),
        PronunciationRule(match: "APIs", spokenText: "A P I's", scope: .global, note: "Acronym"),
        PronunciationRule(match: "PDF", spokenText: "P D F", scope: .global, note: "Acronym"),
        PronunciationRule(match: "PDFs", spokenText: "P D F's", scope: .global, note: "Acronym"),
        PronunciationRule(match: "GUI", spokenText: "gooey", scope: .global, note: "Acronym"),
        PronunciationRule(match: "CLI", spokenText: "C L I", scope: .global, note: "Acronym"),
        PronunciationRule(match: "SQL", spokenText: "sequel", scope: .global, note: "Technical"),
        PronunciationRule(match: "regex", spokenText: "reg ex", scope: .global, note: "Technical"),
        PronunciationRule(match: "arXiv", spokenText: "archive", scope: .global, note: "Academic"),
        PronunciationRule(match: "LaTeX", spokenText: "LAY-tek", scope: .global, note: "Academic"),
        PronunciationRule(match: "Gaussian", spokenText: "GOW-see-an", scope: .global, note: "Proper name"),
        PronunciationRule(match: "Euler", spokenText: "Oiler", scope: .global, note: "Proper name"),
        PronunciationRule(match: "PyTorch", spokenText: "pie torch", scope: .global, note: "Technical"),
        PronunciationRule(match: "macOS", spokenText: "Mac O S", scope: .global, note: "Platform"),
        PronunciationRule(match: "iOS", spokenText: "eye O S", scope: .global, note: "Platform")
    ]
    
    public init() {
        loadPersistedRules()
    }
    
    // MARK: - Rule Management
    
    public func addRule(_ rule: PronunciationRule) {
        lock.lock()
        defer {
            revision += 1
            lock.unlock()
            savePersistedRules()
        }
        
        switch rule.scope {
        case .user:
            userRules.removeAll(where: { $0.id == rule.id || $0.match.caseInsensitiveCompare(rule.match) == .orderedSame })
            userRules.append(rule)
        case .book:
            if let docID = rule.documentID {
                var current = bookRules[docID] ?? []
                current.removeAll(where: { $0.id == rule.id || $0.match.caseInsensitiveCompare(rule.match) == .orderedSame })
                current.append(rule)
                bookRules[docID] = current
            }
        case .global:
            break // Global rules are statically defined
        }
    }
    
    public func removeRule(id: UUID) {
        lock.lock()
        defer {
            revision += 1
            lock.unlock()
            savePersistedRules()
        }
        
        userRules.removeAll(where: { $0.id == id })
        for (docID, rules) in bookRules {
            bookRules[docID] = rules.filter { $0.id != id }
        }
    }
    
    public func rules(for documentID: UUID? = nil) -> [PronunciationRule] {
        lock.lock()
        defer { lock.unlock() }
        
        var combined: [PronunciationRule] = []
        // Highest priority: User rules
        combined.append(contentsOf: userRules)
        
        // Next priority: Book-specific rules
        if let docID = documentID, let bRules = bookRules[docID] {
            combined.append(contentsOf: bRules)
        }
        
        // Base priority: Global rules
        combined.append(contentsOf: globalRules)
        return combined
    }
    
    // MARK: - Application
    
    /// Applies layered pronunciation rules to text using case-insensitive word boundary replacement.
    public func applyPronunciations(to text: String, documentID: UUID? = nil) -> String {
        guard !text.isEmpty else { return "" }
        let activeRules = rules(for: documentID)
        guard !activeRules.isEmpty else { return text }
        
        var result = text
        for rule in activeRules {
            let escaped = NSRegularExpression.escapedPattern(for: rule.match)
            let pattern = "\\b\(escaped)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (result as NSString).length)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: rule.spokenText
                )
            }
        }
        return result
    }
    
    /// Generates a revision fingerprint for a document, useful for cache keys.
    public func revisionHash(for documentID: UUID? = nil) -> String {
        lock.lock()
        defer { lock.unlock() }
        let count = userRules.count + (documentID.flatMap { bookRules[$0]?.count } ?? 0)
        return "rev_\(revision)_\(count)"
    }
    
    // MARK: - Persistence
    
    private func savePersistedRules() {
        if let data = try? JSONEncoder().encode(userRules) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        if let data = try? JSONEncoder().encode(bookRules) {
            UserDefaults.standard.set(data, forKey: bookDefaultsKey)
        }
    }
    
    private func loadPersistedRules() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let rules = try? JSONDecoder().decode([PronunciationRule].self, from: data) {
            userRules = rules
        }
        if let data = UserDefaults.standard.data(forKey: bookDefaultsKey),
           let rules = try? JSONDecoder().decode([UUID: [PronunciationRule]].self, from: data) {
            bookRules = rules
        }
    }
}
