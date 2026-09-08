//
//  ReadingProgressTracker.swift
//  Vachanam
//
//  Tracks reading history, page positions, progress percentages, and time estimates.
//

import Foundation
import Combine

public struct ReadingRecord: Identifiable, Codable, Equatable {
    public var id: String { documentPath }
    public let documentPath: String
    public let title: String
    public var currentPage: Int
    public var totalPages: Int
    public var lastOpened: Date
    public var estimatedRemainingMinutes: Int
    
    public var progressFraction: Double {
        guard totalPages > 0 else { return 0.0 }
        return Double(currentPage + 1) / Double(totalPages)
    }
    
    public var progressPercentString: String {
        let percent = Int(progressFraction * 100)
        return "\(min(max(percent, 0), 100))%"
    }
    
    public init(documentPath: String, title: String, currentPage: Int, totalPages: Int, lastOpened: Date = Date(), estimatedRemainingMinutes: Int = 0) {
        self.documentPath = documentPath
        self.title = title
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.lastOpened = lastOpened
        self.estimatedRemainingMinutes = estimatedRemainingMinutes
    }
}

public class ReadingProgressTracker: ObservableObject {
    public static let shared = ReadingProgressTracker()
    
    private let storageKey = "vachanam_reading_history"
    @Published public var history: [ReadingRecord] = []
    
    public init() {
        loadHistory()
    }
    
    public func recordProgress(documentURL: URL, title: String, currentPage: Int, totalPages: Int, remainingWords: Int = 0, wpm: Int = 180) {
        let path = documentURL.path
        let speed = max(wpm, 60)
        let estMinutes = remainingWords > 0 ? (remainingWords / speed) : max((totalPages - currentPage - 1) * 2, 0)
        
        var record = ReadingRecord(
            documentPath: path,
            title: title,
            currentPage: currentPage,
            totalPages: totalPages,
            lastOpened: Date(),
            estimatedRemainingMinutes: estMinutes
        )
        
        if let existingIdx = history.firstIndex(where: { $0.documentPath == path }) {
            record.currentPage = currentPage
            record.totalPages = totalPages
            record.lastOpened = Date()
            record.estimatedRemainingMinutes = estMinutes
            history.remove(at: existingIdx)
        }
        history.insert(record, at: 0)
        saveHistory()
    }
    
    public func record(for documentURL: URL) -> ReadingRecord? {
        history.first { $0.documentPath == documentURL.path }
    }
    
    public func lastPage(for documentURL: URL) -> Int {
        record(for: documentURL)?.currentPage ?? 0
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
