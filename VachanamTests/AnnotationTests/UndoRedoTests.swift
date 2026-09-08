//
//  UndoRedoTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class UndoRedoTests: XCTestCase {
    
    func testUndoRedoStackOperations() {
        let undoRedo = UndoRedoManager.shared
        undoRedo.clear()
        
        var counter = 0
        
        // Register 10 actions
        for _ in 1...10 {
            undoRedo.register(action: UndoableAction(
                name: "Increment",
                undoBlock: { counter -= 1 },
                redoBlock: { counter += 1 }
            ))
            counter += 1
        }
        
        XCTAssertEqual(counter, 10)
        XCTAssertTrue(undoRedo.canUndo)
        XCTAssertFalse(undoRedo.canRedo)
        
        // Undo 5 operations
        for _ in 1...5 {
            undoRedo.undo()
        }
        XCTAssertEqual(counter, 5)
        XCTAssertTrue(undoRedo.canUndo)
        XCTAssertTrue(undoRedo.canRedo)
        
        // Redo 3 operations
        for _ in 1...3 {
            undoRedo.redo()
        }
        XCTAssertEqual(counter, 8)
        XCTAssertTrue(undoRedo.canUndo)
        XCTAssertTrue(undoRedo.canRedo)
    }
}
