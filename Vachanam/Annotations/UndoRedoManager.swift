//
//  UndoRedoManager.swift
//  Vachanam
//
//  Command-based undo/redo transactional stack for annotations and edits.
//

import Foundation
import Combine

public struct UndoableAction {
    public let name: String
    public let undoBlock: () -> Void
    public let redoBlock: () -> Void
    
    public init(name: String, undoBlock: @escaping () -> Void, redoBlock: @escaping () -> Void) {
        self.name = name
        self.undoBlock = undoBlock
        self.redoBlock = redoBlock
    }
}

public class UndoRedoManager: ObservableObject {
    public static let shared = UndoRedoManager()
    
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false
    
    private var undoStack: [UndoableAction] = []
    private var redoStack: [UndoableAction] = []
    
    public init() {}
    
    public func register(action: UndoableAction) {
        undoStack.append(action)
        redoStack.removeAll()
        updateState()
    }
    
    public func undo() {
        guard let action = undoStack.popLast() else { return }
        action.undoBlock()
        redoStack.append(action)
        updateState()
    }
    
    public func redo() {
        guard let action = redoStack.popLast() else { return }
        action.redoBlock()
        undoStack.append(action)
        updateState()
    }
    
    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }
    
    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
