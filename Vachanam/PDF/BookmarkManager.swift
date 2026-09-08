//
//  BookmarkManager.swift
//  Vachanam
//
//  Manages document page bookmarks and persistent storage.
//

import Foundation
import Combine

public struct Bookmark: Identifiable, Codable, Equatable {
    public let id: UUID
    public let documentURL: URL
    public let pageIndex: Int
    public let pageTitle: String
    public let createdAt: Date
    public var note: String?
    
    public init(id: UUID = UUID(), documentURL: URL, pageIndex: Int, pageTitle: String = "", note: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.documentURL = documentURL
        self.pageIndex = pageIndex
        self.pageTitle = pageTitle
        self.note = note
        self.createdAt = createdAt
    }
}

public class BookmarkManager: ObservableObject {
    public static let shared = BookmarkManager()
    
    private let storageKey = "vachanam_saved_bookmarks"
    @Published public var bookmarks: [Bookmark] = []
    
    public init() {
        loadBookmarks()
    }
    
    public func isBookmarked(documentURL: URL, pageIndex: Int) -> Bool {
        bookmarks.contains { $0.documentURL.path == documentURL.path && $0.pageIndex == pageIndex }
    }
    
    public func toggleBookmark(documentURL: URL, pageIndex: Int, pageTitle: String = "") {
        if isBookmarked(documentURL: documentURL, pageIndex: pageIndex) {
            removeBookmark(documentURL: documentURL, pageIndex: pageIndex)
        } else {
            addBookmark(Bookmark(documentURL: documentURL, pageIndex: pageIndex, pageTitle: pageTitle))
        }
    }
    
    public func addBookmark(_ bookmark: Bookmark) {
        if !isBookmarked(documentURL: bookmark.documentURL, pageIndex: bookmark.pageIndex) {
            bookmarks.append(bookmark)
            saveBookmarks()
        }
    }
    
    public func removeBookmark(documentURL: URL, pageIndex: Int) {
        bookmarks.removeAll { $0.documentURL.path == documentURL.path && $0.pageIndex == pageIndex }
        saveBookmarks()
    }
    
    public func bookmarks(for documentURL: URL) -> [Bookmark] {
        bookmarks.filter { $0.documentURL.path == documentURL.path }.sorted { $0.pageIndex < $1.pageIndex }
    }
    
    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            self.bookmarks = decoded
        }
    }
}
