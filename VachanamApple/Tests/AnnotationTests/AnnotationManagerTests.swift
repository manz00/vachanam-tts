//
//  AnnotationManagerTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class AnnotationManagerTests: XCTestCase {
    
    func testAddingAndListingAnnotations() {
        let manager = AnnotationManager.shared
        manager.clearCurrent()
        
        let shape = ShapeAnnotation(
            pageIndex: 0,
            shapeType: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 100, y: 100)
        )
        manager.addShape(shape)
        XCTAssertEqual(manager.shapes.count, 1)
        
        let note = StickyNoteAnnotation(
            pageIndex: 0,
            position: CGPoint(x: 50, y: 50),
            content: "Review this section carefully"
        )
        manager.addStickyNote(note)
        XCTAssertEqual(manager.stickyNotes.count, 1)
        
        let textBox = TextBoxAnnotation(
            pageIndex: 0,
            position: CGPoint(x: 60, y: 60),
            text: "Key takeaway here"
        )
        manager.addTextBox(textBox)
        XCTAssertEqual(manager.textBoxes.count, 1)
        
        manager.clearCurrent()
        XCTAssertEqual(manager.shapes.count, 0)
        XCTAssertEqual(manager.stickyNotes.count, 0)
        XCTAssertEqual(manager.textBoxes.count, 0)
    }
}
