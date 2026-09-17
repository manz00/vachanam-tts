//
//  AppState.swift
//  Vachanam
//
//  Global application state managing the active document, playback status, and navigation.
//

import Foundation
import Combine

public class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var currentDocument: ReaderDocument?
    @Published public var selectedTab: String = "library"
    
    private let lastOpenedDocKey = "vachanam_last_opened_document_path"
    private let hasLaunchedBeforeKey = "vachanam_has_launched_before"
    
    public init() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        let savedPath = UserDefaults.standard.string(forKey: lastOpenedDocKey)
        print("[RESTORE] hasLaunchedBefore = \(hasLaunchedBefore)")
        print("[RESTORE] savedPath = \(savedPath ?? "nil")")
        print("[RESTORE] fileExists = \(FileManager.default.fileExists(atPath: savedPath ?? ""))")
        
        if let path = savedPath {
            let url = URL(fileURLWithPath: path)
            if let progress = ReadingProgressTracker.shared.progress(for: url) {
                var detail = "page = \(progress.currentPage), total = \(progress.totalPages)"
                if let w = progress.lastWordID { detail += ", word = \(w)" }
                if let s = progress.lastSentenceID { detail += ", sentence = \(s)" }
                print("[RESTORE] tracker \(detail)")
            } else {
                print("[RESTORE] NO progress found in tracker")
            }
        }
        
        if !hasLaunchedBefore {
            // First app launch: Auto-ingest and open benchmark PDF so user can immediately evaluate functioning
            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
            let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
            if let doc = ReaderDocument(url: benchmarkURL) {
                self.currentDocument = doc
                UserDefaults.standard.set(benchmarkURL.path, forKey: lastOpenedDocKey)
                ReadingProgressTracker.shared.recordProgress(
                    documentURL: benchmarkURL,
                    title: doc.title,
                    currentPage: 0,
                    totalPages: doc.pageCount
                )
            }
        } else if let savedPath = savedPath,
                  FileManager.default.fileExists(atPath: savedPath),
                  let doc = ReaderDocument(url: URL(fileURLWithPath: savedPath)) {
            // Subsequent launches: Restore last active document without resetting reading progress
            self.currentDocument = doc
        }
        // If user specifically closed the document, currentDocument remains nil (library view)
    }
    
    public func openDocument(_ document: ReaderDocument) {
        if let current = currentDocument, current.id != document.id {
            closeCurrentDocument()
        }
        self.currentDocument = document
        UserDefaults.standard.set(document.fileURL.path, forKey: lastOpenedDocKey)
        UserDefaults.standard.synchronize()
    }
    
    public func closeCurrentDocument() {
        if let doc = currentDocument {
            let coord = PlaybackCoordinator.shared
            let isMatchingDoc = coord.activeSemanticDocument?.documentID == doc.id || coord.activeSemanticDocument?.title == doc.title
            let tracker = ReadingProgressTracker.shared
            let trackerPage = tracker.lastPage(for: doc.fileURL)
            
            let page: Int
            let wordID: Int?
            let sentenceID: Int?
            
            if coord.isPlaying, isMatchingDoc, let c = coord.cursor {
                // Audio actively playing: spoken page and cursor are authoritative
                page = c.pageIndex
                wordID = coord.currentWordID ?? c.globalWordID
                sentenceID = coord.currentSentenceID ?? c.sentenceIndex
            } else if isMatchingDoc, let c = coord.cursor, c.pageIndex == trackerPage {
                // Playback paused/stopped on current reading page: preserve word/sentence cursor
                page = trackerPage
                wordID = coord.currentWordID ?? c.globalWordID
                sentenceID = coord.currentSentenceID ?? c.sentenceIndex
            } else {
                // Reading or scrolled away: tracker's visible page is authoritative
                page = trackerPage
                wordID = tracker.lastWordID(for: doc.fileURL)
                sentenceID = tracker.lastSentenceID(for: doc.fileURL)
            }
            
            tracker.recordProgress(
                documentURL: doc.fileURL,
                title: doc.title,
                currentPage: page,
                totalPages: doc.pageCount,
                lastWordID: wordID,
                lastSentenceID: sentenceID
            )
        }
        TTSController.shared.stop()
        self.currentDocument = nil
        UserDefaults.standard.removeObject(forKey: lastOpenedDocKey)
        UserDefaults.standard.synchronize()
    }
}
