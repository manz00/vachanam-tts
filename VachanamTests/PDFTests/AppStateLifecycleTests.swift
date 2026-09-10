//
//  AppStateLifecycleTests.swift
//  VachanamTests
//
//  Verifies AppState persistence, closeCurrentDocument behavior, and AudioSession interruption hooks.
//

import XCTest
import AVFoundation
import PDFKit
@testable import Vachanam

final class AppStateLifecycleTests: XCTestCase {
    
    func testAppStateOpenAndCloseDocumentLifecycle() {
        let appState = AppState.shared
        let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
        guard let doc = ReaderDocument(url: benchmarkURL) else {
            XCTFail("Failed to initialize ReaderDocument for Benchmark")
            return
        }
        
        // Opening document updates currentDocument and stores path in UserDefaults
        appState.openDocument(doc)
        XCTAssertNotNil(appState.currentDocument)
        XCTAssertEqual(appState.currentDocument?.fileURL.path, benchmarkURL.path)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "vachanam_last_opened_document_path"), benchmarkURL.path)
        
        // Closing document clears currentDocument and removes path from UserDefaults
        appState.closeCurrentDocument()
        XCTAssertNil(appState.currentDocument)
        XCTAssertNil(UserDefaults.standard.string(forKey: "vachanam_last_opened_document_path"))
    }
    
    func testAudioSessionInterruptionObserversSetup() {
        var beganCalled = false
        var endedCalled = false
        var routeChangeCalled = false
        
        AudioSession.shared.setupInterruptionObservers(
            onInterruptionBegan: {
                beganCalled = true
            },
            onInterruptionEnded: { _ in
                endedCalled = true
            },
            onRouteChangeShouldPause: {
                routeChangeCalled = true
            }
        )
        
        // Simulate Began Notification
        let beganUserInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: beganUserInfo
        )
        
        XCTAssertTrue(beganCalled, "Expected onInterruptionBegan to be called on .began")
        
        // Simulate Ended Notification
        let endedUserInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: endedUserInfo
        )
        
        XCTAssertTrue(endedCalled, "Expected onInterruptionEnded to be called on .ended")
        
        // Simulate Route Change (Headphones unplugged)
        let routeUserInfo: [AnyHashable: Any] = [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: routeUserInfo
        )
        
        XCTAssertTrue(routeChangeCalled, "Expected onRouteChangeShouldPause to be called on oldDeviceUnavailable")
    }
    
    func testProgressTrackingAndRestoreSimulation() {
        let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
        guard let doc = ReaderDocument(url: benchmarkURL) else {
            XCTFail("Failed to initialize ReaderDocument for Benchmark")
            return
        }
        
        UserDefaults.standard.set(true, forKey: "vachanam_has_launched_before")
        UserDefaults.standard.set(benchmarkURL.path, forKey: "vachanam_last_opened_document_path")
        
        ReadingProgressTracker.shared.recordProgress(
            documentURL: benchmarkURL,
            title: doc.title,
            currentPage: 3,
            totalPages: doc.pageCount
        )
        
        let restoredAppState = AppState()
        XCTAssertNotNil(restoredAppState.currentDocument)
        XCTAssertEqual(restoredAppState.currentDocument?.fileURL.path, benchmarkURL.path)
        
        let progress = ReadingProgressTracker.shared.progress(for: benchmarkURL)
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.currentPage, 3)
    }
    
    func testWordAndSentenceLevelProgressPersistenceAndTTSCursor() {
        let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
        guard let doc = ReaderDocument(url: benchmarkURL) else {
            XCTFail("Failed to initialize ReaderDocument for Benchmark")
            return
        }
        
        let tracker = ReadingProgressTracker.shared
        tracker.recordProgress(
            documentURL: benchmarkURL,
            title: doc.title,
            currentPage: 2,
            totalPages: doc.pageCount,
            lastWordID: 15,
            lastSentenceID: 2
        )
        
        guard let record = tracker.progress(for: benchmarkURL) else {
            XCTFail("Expected saved record")
            return
        }
        XCTAssertEqual(record.currentPage, 2)
        XCTAssertEqual(record.lastWordID, 15)
        XCTAssertEqual(record.lastSentenceID, 2)
        XCTAssertEqual(tracker.lastWordID(for: benchmarkURL), 15)
        XCTAssertEqual(tracker.lastSentenceID(for: benchmarkURL), 2)
        
        // Test SemanticDocument loading with initial Word/Sentence
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            let p1 = "Page one content sentence."
            p1.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            
            context.beginPage()
            let p2 = "Page two target word sentence."
            p2.draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        guard let testPDF = PDFDocument(data: data) else {
            XCTFail("Failed to create test PDF")
            return
        }
        let semDoc = SentenceSegmenter.shared.parseDocument(pdfDocument: testPDF, title: "TestDoc")
        guard let pageTwoWord = semDoc.firstWord(onPageIndex: 1) else {
            XCTFail("Expected first word on page 1")
            return
        }
        
        let coord = PlaybackCoordinator.shared
        coord.loadDocument(semDoc, initialSentenceID: pageTwoWord.sentenceID, initialWordID: pageTwoWord.globalWordID)
        XCTAssertNotNil(coord.cursor)
        XCTAssertEqual(coord.cursor?.globalWordID, pageTwoWord.globalWordID)
        XCTAssertEqual(coord.cursor?.pageIndex, 1)
        XCTAssertEqual(coord.cursor?.sentenceIndex, pageTwoWord.sentenceID)
        
        // Verify closeCurrentDocument flushes cursor and clears path
        AppState.shared.openDocument(doc)
        AppState.shared.closeCurrentDocument()
        XCTAssertNil(AppState.shared.currentDocument)
        XCTAssertNil(UserDefaults.standard.string(forKey: "vachanam_last_opened_document_path"))
    }
    
    func testCloseDocumentDoesNotOverwriteScrolledPageWithStaleCursor() {
        let benchmarkURL = DocumentLibraryView.ensureBenchmarkDocumentExists()
        guard let doc = ReaderDocument(url: benchmarkURL) else {
            XCTFail("Failed to initialize ReaderDocument for Benchmark")
            return
        }
        
        let tracker = ReadingProgressTracker.shared
        // User opens document and cursor initializes on page 0
        AppState.shared.openDocument(doc)
        PlaybackCoordinator.shared.setVisiblePageIndex(0)
        
        // User scrolls to page 16
        tracker.recordProgress(
            documentURL: benchmarkURL,
            title: doc.title,
            currentPage: 16,
            totalPages: doc.pageCount,
            lastWordID: nil,
            lastSentenceID: nil
        )
        
        // Close document to return to Library
        AppState.shared.closeCurrentDocument()
        
        // Ensure ReadingProgressTracker retained page 16 and was not clobbered back to 0
        let savedPage = tracker.lastPage(for: benchmarkURL)
        XCTAssertEqual(savedPage, 16, "Expected tracker to maintain scrolled page 16, but got \(savedPage)")
    }
}
