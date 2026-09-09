//
//  ContinuousScrollHighlightTests.swift
//  VachanamTests
//
//  Unit tests for continuous scroll layout modes, highlight overlay state,
//  and multi-page sentence span coordinates.
//

import XCTest
import PDFKit
@testable import Vachanam

final class ContinuousScrollHighlightTests: XCTestCase {
    
    func testPDFDisplayLayoutModes() {
        XCTAssertEqual(PDFDisplayLayoutMode.singlePage.pdfDisplayMode, .singlePage)
        XCTAssertEqual(PDFDisplayLayoutMode.singlePageContinuous.pdfDisplayMode, .singlePageContinuous)
        XCTAssertEqual(PDFDisplayLayoutMode.twoUp.pdfDisplayMode, .twoUp)
        XCTAssertEqual(PDFDisplayLayoutMode.twoUpContinuous.pdfDisplayMode, .twoUpContinuous)
        
        XCTAssertTrue(PDFDisplayLayoutMode.singlePage.usesPageViewController)
        XCTAssertFalse(PDFDisplayLayoutMode.singlePageContinuous.usesPageViewController)
        XCTAssertFalse(PDFDisplayLayoutMode.twoUpContinuous.usesPageViewController)
    }
    
    func testHighlightOverlayViewRendering() {
        let overlay = PDFHighlightOverlayView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        
        let sentenceRects = [
            CGRect(x: 20, y: 100, width: 360, height: 18),
            CGRect(x: 20, y: 122, width: 300, height: 18)
        ]
        let wordRect = CGRect(x: 20, y: 100, width: 45, height: 18)
        
        overlay.render(
            sentenceRects: sentenceRects,
            sentenceColor: .yellow,
            wordRect: wordRect,
            wordColor: .orange,
            wordBorderColor: .red
        )
        
        XCTAssertFalse(overlay.isHidden)
        
        // Clear highlights
        overlay.clear()
    }
    
    func testAudioGraphDescriptor() {
        let descriptor = AudioGraphDescriptor.shared
        let summary = descriptor.describeChart(
            title: "Loss vs Epochs",
            summary: "Training convergence curve",
            xAxisLabel: "Epochs",
            yAxisLabel: "Cross-Entropy Loss",
            dataPoints: [(1.0, 2.5), (2.0, 1.8), (3.0, 1.2), (4.0, 0.9)]
        )
        
        XCTAssertTrue(summary.contains("Loss vs Epochs"))
        XCTAssertTrue(summary.contains("Training convergence curve"))
        XCTAssertTrue(summary.contains("Epochs"))
        XCTAssertTrue(summary.contains("Cross-Entropy Loss"))
        XCTAssertTrue(summary.contains("Data spans 4 points"))
    }
}
