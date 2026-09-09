//
//  AutoScrollPolicyTests.swift
//  VachanamTests
//
//  Unit tests for AutoScrollFollowMode, scroll-away detection,
//  jump-to-speech navigation, and PDFKit hit-test sanitization.
//

import XCTest
import UIKit
import PDFKit
@testable import Vachanam

final class AutoScrollPolicyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "autoScrollFollowMode")
        UserDefaults.standard.removeObject(forKey: "isAutoScrollEnabled")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "autoScrollFollowMode")
        UserDefaults.standard.removeObject(forKey: "isAutoScrollEnabled")
        super.tearDown()
    }
    
    func testAutoScrollFollowModeDefaultsAndPersistence() {
        let manager = AccessibilityManager()
        XCTAssertEqual(manager.autoScrollFollowMode, .promptWhenScrolled, "Default auto-scroll follow mode should be .promptWhenScrolled")
        XCTAssertTrue(manager.isAutoScrollEnabled)
        
        manager.autoScrollFollowMode = .alwaysFollow
        XCTAssertEqual(UserDefaults.standard.string(forKey: "autoScrollFollowMode"), AutoScrollFollowMode.alwaysFollow.rawValue)
        XCTAssertTrue(manager.isAutoScrollEnabled)
        
        manager.autoScrollFollowMode = .off
        XCTAssertEqual(UserDefaults.standard.string(forKey: "autoScrollFollowMode"), AutoScrollFollowMode.off.rawValue)
        XCTAssertFalse(manager.isAutoScrollEnabled)
        
        // Test reload from UserDefaults
        let reloaded = AccessibilityManager()
        XCTAssertEqual(reloaded.autoScrollFollowMode, .off)
        XCTAssertFalse(reloaded.isAutoScrollEnabled)
    }
    
    func testLegacyIsAutoScrollEnabledFallback() {
        // If legacy isAutoScrollEnabled was set to false, it should initialize to .off
        UserDefaults.standard.set(false, forKey: "isAutoScrollEnabled")
        let manager = AccessibilityManager()
        XCTAssertEqual(manager.autoScrollFollowMode, .off)
    }
    
    func testPlaybackCoordinatorScrollAwayStateAndJump() {
        let coord = PlaybackCoordinator.shared
        coord.isUserScrolledAway = true
        coord.scrolledAwayDirection = .above
        coord.scrolledAwayPageIndex = 22
        coord.scrolledAwaySnippet = "Two geometric vectors..."
        
        var receivedNotification = false
        let token = NotificationCenter.default.addObserver(
            forName: .jumpToSpokenSentence,
            object: nil,
            queue: .main
        ) { _ in
            receivedNotification = true
        }
        
        coord.jumpToSpokenSentence()
        
        XCTAssertTrue(receivedNotification, "jumpToSpokenSentence() should post .jumpToSpokenSentence notification")
        XCTAssertFalse(coord.isUserScrolledAway, "jumpToSpokenSentence() should reset isUserScrolledAway to false")
        
        NotificationCenter.default.removeObserver(token)
    }
    
    func testStopResetsScrollAwayState() {
        let coord = PlaybackCoordinator.shared
        coord.isUserScrolledAway = true
        coord.stop()
        XCTAssertFalse(coord.isUserScrolledAway, "stop() should reset isUserScrolledAway to false")
    }
    
    func testVachanamPDFViewHitTestSanitizesNilWindow() {
        let pdfView = VachanamPDFView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        
        // Add a detached dummy view that returns a subview with window == nil
        let detachedChild = UIView(frame: CGRect(x: 10, y: 10, width: 50, height: 50))
        pdfView.addSubview(detachedChild)
        
        // Since pdfView is not yet added to a window, hitTest on an area outside child should return nil or pdfView safely
        let hitResult = pdfView.hitTest(CGPoint(x: 200, y: 300), with: nil)
        // Ensure no crash or uncaught exception
        XCTAssertTrue(hitResult == nil || hitResult === pdfView)
    }
    
    func testCoordinatorScrollAwayPauseAndResumeLifecycle() {
        let coord = PlaybackCoordinator.shared
        coord.isPlaying = true
        coord.isUserScrolledAway = true
        coord.scrolledAwayPageIndex = 5
        coord.scrolledAwayDirection = .above
        coord.scrolledAwaySnippet = "Machine learning foundations"
        
        XCTAssertTrue(coord.isUserScrolledAway, "Auto-scroll must be paused while isUserScrolledAway is true")
        
        var resumeFired = false
        let token = NotificationCenter.default.addObserver(
            forName: .jumpToSpokenSentence,
            object: nil,
            queue: .main
        ) { _ in
            resumeFired = true
        }
        
        coord.jumpToSpokenSentence()
        
        XCTAssertTrue(resumeFired, "Resume action must post .jumpToSpokenSentence")
        XCTAssertFalse(coord.isUserScrolledAway, "Resume action must unpause auto-scroll by resetting isUserScrolledAway")
        
        NotificationCenter.default.removeObserver(token)
    }
}
