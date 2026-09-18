//
//  BookPreparationService.swift
//  Vachanam
//
//  Background preparation and book intelligence engine: extracts chapter structure,
//  runs text normalization, computes precise word counts, estimated visual reading times,
//  and estimated neural TTS spoken audio duration.
//

import Foundation
import Combine

public struct ChapterPreparationSummary: Codable, Identifiable, Hashable {
    public var id: Int { chapterIndex }
    public let chapterIndex: Int
    public let title: String
    public let wordCount: Int
    public let estimatedAudioMinutes: Int
    
    public init(chapterIndex: Int, title: String, wordCount: Int, estimatedAudioMinutes: Int) {
        self.chapterIndex = chapterIndex
        self.title = title
        self.wordCount = wordCount
        self.estimatedAudioMinutes = max(estimatedAudioMinutes, 1)
    }
}

public struct BookPreparationRecord: Codable, Identifiable, Hashable {
    public var id: String { documentPath }
    public let documentPath: String
    public let wordCount: Int
    public let chapterCount: Int
    public let estimatedReadingMinutes: Int
    public let estimatedAudioMinutes: Int
    public let chapterSummaries: [ChapterPreparationSummary]
    public let preparedDate: Date
    
    public init(
        documentPath: String,
        wordCount: Int,
        chapterCount: Int,
        estimatedReadingMinutes: Int,
        estimatedAudioMinutes: Int,
        chapterSummaries: [ChapterPreparationSummary],
        preparedDate: Date = Date()
    ) {
        self.documentPath = documentPath
        self.wordCount = wordCount
        self.chapterCount = chapterCount
        self.estimatedReadingMinutes = max(estimatedReadingMinutes, 1)
        self.estimatedAudioMinutes = max(estimatedAudioMinutes, 1)
        self.chapterSummaries = chapterSummaries
        self.preparedDate = preparedDate
    }
}

public class BookPreparationService: ObservableObject {
    public static let shared = BookPreparationService()
    
    private let storageKey = "vachanam_prepared_books"
    
    @Published public var preparedRecords: [String: BookPreparationRecord] = [:]
    @Published public var activelyPreparingPaths: Set<String> = []
    
    public init() {
        loadData()
    }
    
    public func isPrepared(path: String) -> Bool {
        preparedRecords[path] != nil
    }
    
    public func isPreparing(path: String) -> Bool {
        activelyPreparingPaths.contains(path)
    }
    
    public func record(for path: String) -> BookPreparationRecord? {
        preparedRecords[path]
    }
    
    /// Prepares a book by extracting chapter structure, normalizing text,
    /// and computing reading time (225 wpm) and spoken audio duration (150 wpm).
    @discardableResult
    public func prepareBook(at url: URL) async throws -> BookPreparationRecord {
        let path = url.path
        _ = await MainActor.run {
            activelyPreparingPaths.insert(path)
        }
        
        defer {
            Task { @MainActor in
                activelyPreparingPaths.remove(path)
            }
        }
        
        let format = DocumentFormat.detect(from: url)
        var chapterSummaries: [ChapterPreparationSummary] = []
        var totalWords = 0
        
        if format == .pdf {
            // PDF: count words across pages
            let pdfDoc = ReaderDocument(url: url)?.pdfDocument
            let pageCount = pdfDoc?.pageCount ?? 0
            for p in 0..<pageCount {
                if let page = pdfDoc?.page(at: p), let text = page.string {
                    let words = text.split { $0.isWhitespace || $0.isNewline }
                    totalWords += words.count
                }
            }
            let audioMin = max(Int(ceil(Double(totalWords) / 150.0)), 1)
            chapterSummaries.append(
                ChapterPreparationSummary(
                    chapterIndex: 0,
                    title: url.deletingPathExtension().lastPathComponent,
                    wordCount: totalWords,
                    estimatedAudioMinutes: audioMin
                )
            )
        } else {
            // EPUB / MD / Web / Plain Text
            let parsed = try await DocumentParserResolver.shared.parse(source: .fileURL(url), format: format)
            for (idx, ch) in parsed.chapters.enumerated() {
                var chWords = 0
                for b in ch.blocks {
                    let normalized = TextNormalizer.shared.normalize(b.text)
                    let words = normalized.split { $0.isWhitespace || $0.isNewline }
                    chWords += words.count
                }
                totalWords += chWords
                let chAudioMin = max(Int(ceil(Double(chWords) / 150.0)), 1)
                chapterSummaries.append(
                    ChapterPreparationSummary(
                        chapterIndex: idx,
                        title: ch.title ?? "Chapter \(idx + 1)",
                        wordCount: chWords,
                        estimatedAudioMinutes: chAudioMin
                    )
                )
            }
        }
        
        let estAudioMin = max(Int(ceil(Double(totalWords) / 150.0)), 1)
        let estReadMin = max(Int(ceil(Double(totalWords) / 225.0)), 1)
        
        let record = BookPreparationRecord(
            documentPath: path,
            wordCount: totalWords,
            chapterCount: chapterSummaries.count,
            estimatedReadingMinutes: estReadMin,
            estimatedAudioMinutes: estAudioMin,
            chapterSummaries: chapterSummaries
        )
        
        await MainActor.run {
            preparedRecords[path] = record
            saveData()
        }
        
        return record
    }
    
    public func deletePreparation(for path: String) {
        preparedRecords.removeValue(forKey: path)
        saveData()
    }
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(preparedRecords) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: BookPreparationRecord].self, from: data) {
            self.preparedRecords = decoded
        }
    }
}
