//
//  BookmarkManagerTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class BookmarkManagerTests: XCTestCase {
    
    func testBookmarkLifecycle() {
        let manager = BookmarkManager.shared
        let dummyURL = URL(fileURLWithPath: "/tmp/sample_test_doc.pdf")
        
        // Remove if existing
        manager.removeBookmark(documentURL: dummyURL, pageIndex: 2)
        XCTAssertFalse(manager.isBookmarked(documentURL: dummyURL, pageIndex: 2))
        
        // Add
        manager.toggleBookmark(documentURL: dummyURL, pageIndex: 2, pageTitle: "Chapter 1")
        XCTAssertTrue(manager.isBookmarked(documentURL: dummyURL, pageIndex: 2))
        
        let bookmarks = manager.bookmarks(for: dummyURL)
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks.first?.pageIndex, 2)
        
        // Remove
        manager.removeBookmark(documentURL: dummyURL, pageIndex: 2)
        XCTAssertFalse(manager.isBookmarked(documentURL: dummyURL, pageIndex: 2))
    }
}
