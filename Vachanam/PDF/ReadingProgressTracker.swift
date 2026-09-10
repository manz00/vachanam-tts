//
//  ReadingProgressTracker.swift
//  Vachanam
//
//  Tracks reading history, page positions, progress percentages, and time estimates.
//

import Foundation
import Combine

public struct ReadingRecord: Identifiable, Codable, Equatable, Hashable {
    public var id: String { documentPath }
    public let documentPath: String
    public let title: String
    public var currentPage: Int
    public var totalPages: Int
    public var lastOpened: Date
    public var estimatedRemainingMinutes: Int
    public var lastWordID: Int?
    public var lastSentenceID: Int?
    
    public var progressFraction: Double {
        guard totalPages > 0 else { return 0.0 }
        return Double(currentPage + 1) / Double(totalPages)
    }
    
    public var progressPercentString: String {
        let percent = Int(progressFraction * 100)
        return "\(min(max(percent, 0), 100))%"
    }
    
    public var format: DocumentFormat {
        DocumentFormat.detect(from: URL(fileURLWithPath: documentPath))
    }
    
    public init(
        documentPath: String,
        title: String,
        currentPage: Int,
        totalPages: Int,
        lastOpened: Date = Date(),
        estimatedRemainingMinutes: Int = 0,
        lastWordID: Int? = nil,
        lastSentenceID: Int? = nil
    ) {
        self.documentPath = documentPath
        self.title = title
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.lastOpened = lastOpened
        self.estimatedRemainingMinutes = estimatedRemainingMinutes
        self.lastWordID = lastWordID
        self.lastSentenceID = lastSentenceID
    }
}

public class ReadingProgressTracker: ObservableObject {
    public static let shared = ReadingProgressTracker()
    
    private let storageKey = "vachanam_reading_history"
    @Published public var history: [ReadingRecord] = []
    
    public init() {
        loadHistory()
    }
    
    public func recordProgress(
        documentURL: URL,
        title: String,
        currentPage: Int,
        totalPages: Int,
        remainingWords: Int = 0,
        wpm: Int = 180,
        lastWordID: Int? = nil,
        lastSentenceID: Int? = nil
    ) {
        let path = documentURL.path
        let speed = max(wpm, 60)
        let estMinutes = remainingWords > 0 ? (remainingWords / speed) : max((totalPages - currentPage - 1) * 2, 0)
        
        let existing = history.first { $0.documentPath == path }
        let resolvedWordID = lastWordID ?? (existing?.currentPage == currentPage ? existing?.lastWordID : nil)
        let resolvedSentenceID = lastSentenceID ?? (existing?.currentPage == currentPage ? existing?.lastSentenceID : nil)
        
        // Deduplicate: If the saved position has not changed, avoid redundant writes and log spam
        if let ex = existing,
           ex.currentPage == currentPage,
           ex.lastWordID == resolvedWordID,
           ex.lastSentenceID == resolvedSentenceID,
           ex.totalPages == totalPages {
            return
        }
        
        var logDetail = "page \(currentPage)"
        if let w = resolvedWordID { logDetail += ", word \(w)" }
        if let s = resolvedSentenceID { logDetail += ", sentence \(s)" }
        print("[PROGRESS] saving \(logDetail) for \(documentURL.lastPathComponent)")
        
        let record = ReadingRecord(
            documentPath: path,
            title: title,
            currentPage: currentPage,
            totalPages: totalPages,
            lastOpened: Date(),
            estimatedRemainingMinutes: estMinutes,
            lastWordID: resolvedWordID,
            lastSentenceID: resolvedSentenceID
        )
        
        if let existingIdx = history.firstIndex(where: { $0.documentPath == path }) {
            history.remove(at: existingIdx)
        }
        history.insert(record, at: 0)
        saveHistory()
    }
    
    public func progress(for documentURL: URL) -> ReadingRecord? {
        record(for: documentURL)
    }
    
    public func record(for documentURL: URL) -> ReadingRecord? {
        history.first { $0.documentPath == documentURL.path }
    }
    
    public func lastPage(for documentURL: URL) -> Int {
        record(for: documentURL)?.currentPage ?? 0
    }
    
    public func lastWordID(for documentURL: URL) -> Int? {
        record(for: documentURL)?.lastWordID
    }
    
    public func lastSentenceID(for documentURL: URL) -> Int? {
        record(for: documentURL)?.lastSentenceID
    }
    
    public func updatePath(oldPath: String, newURL: URL) {
        if let idx = history.firstIndex(where: { $0.documentPath == oldPath }) {
            let old = history[idx]
            let updated = ReadingRecord(
                documentPath: newURL.path,
                title: old.title,
                currentPage: old.currentPage,
                totalPages: old.totalPages,
                lastOpened: old.lastOpened,
                estimatedRemainingMinutes: old.estimatedRemainingMinutes,
                lastWordID: old.lastWordID,
                lastSentenceID: old.lastSentenceID
            )
            history[idx] = updated
            saveHistory()
        }
    }
    
    public func removeRecord(path: String) {
        history.removeAll { $0.documentPath == path }
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ReadingRecord].self, from: data) {
            self.history = decoded
        }
    }
}
