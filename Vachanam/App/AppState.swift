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
    
    public init() {
        // Auto-load benchmark PDF on launch so user can immediately evaluate functioning
        let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
        if let doc = ReaderDocument(url: benchmarkURL) {
            self.currentDocument = doc
            ReadingProgressTracker.shared.recordProgress(
                documentURL: benchmarkURL,
                title: doc.title,
                currentPage: 0,
                totalPages: doc.pageCount
            )
        }
    }
    
    public func openDocument(_ document: ReaderDocument) {
        self.currentDocument = document
    }
    
    public func closeCurrentDocument() {
        self.currentDocument = nil
    }
}
