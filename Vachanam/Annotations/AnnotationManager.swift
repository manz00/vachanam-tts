//
//  AnnotationManager.swift
//  Vachanam
//
//  Manages PencilKit drawings, shapes, sticky notes, and text annotations per PDF page.
//

import Foundation
import SwiftUI
import PDFKit
import Combine

public enum ShapeType: String, Codable, CaseIterable, Identifiable {
    case rectangle = "Rectangle"
    case circle = "Circle"
    case arrow = "Arrow"
    case line = "Line"
    
    public var id: String { rawValue }
}

public struct ShapeAnnotation: Identifiable, Codable, Equatable {
    public let id: UUID
    public let pageIndex: Int
    public var shapeType: ShapeType
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var strokeColorHex: String
    public var lineWidth: CGFloat
    
    public init(id: UUID = UUID(), pageIndex: Int, shapeType: ShapeType, startPoint: CGPoint, endPoint: CGPoint, strokeColorHex: String = "#F59E0B", lineWidth: CGFloat = 3.0) {
        self.id = id
        self.pageIndex = pageIndex
        self.shapeType = shapeType
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.strokeColorHex = strokeColorHex
        self.lineWidth = lineWidth
    }
}

public struct StickyNoteAnnotation: Identifiable, Codable, Equatable {
    public let id: UUID
    public let pageIndex: Int
    public var position: CGPoint
    public var content: String
    public var colorHex: String
    public var createdAt: Date
    
    public init(id: UUID = UUID(), pageIndex: Int, position: CGPoint, content: String, colorHex: String = "#FBBF24", createdAt: Date = Date()) {
        self.id = id
        self.pageIndex = pageIndex
        self.position = position
        self.content = content
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

public struct TextBoxAnnotation: Identifiable, Codable, Equatable {
    public let id: UUID
    public let pageIndex: Int
    public var position: CGPoint
    public var text: String
    public var fontSize: CGFloat
    public var colorHex: String
    
    public init(id: UUID = UUID(), pageIndex: Int, position: CGPoint, text: String, fontSize: CGFloat = 16.0, colorHex: String = "#FFFFFF") {
        self.id = id
        self.pageIndex = pageIndex
        self.position = position
        self.text = text
        self.fontSize = fontSize
        self.colorHex = colorHex
    }
}

public class AnnotationManager: ObservableObject {
    public static let shared = AnnotationManager()
    
    @Published public var drawings: [Int: Data] = [:] // pageIndex -> PKDrawing Data
    @Published public var shapes: [ShapeAnnotation] = []
    @Published public var stickyNotes: [StickyNoteAnnotation] = []
    @Published public var textBoxes: [TextBoxAnnotation] = []
    
    private var currentDocURL: URL?
    
    public init() {}
    
    public func loadAnnotations(for documentURL: URL) {
        self.currentDocURL = documentURL
        let storageKey = "vachanam_annotations_\(documentURL.lastPathComponent)"
        
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            clearCurrent()
            return
        }
        
        struct EncodedContainer: Codable {
            let drawings: [Int: Data]
            let shapes: [ShapeAnnotation]
            let stickyNotes: [StickyNoteAnnotation]
            let textBoxes: [TextBoxAnnotation]
        }
        
        if let container = try? JSONDecoder().decode(EncodedContainer.self, from: data) {
            self.drawings = container.drawings
            self.shapes = container.shapes
            self.stickyNotes = container.stickyNotes
            self.textBoxes = container.textBoxes
        }
    }
    
    public func saveAnnotations() {
        guard let docURL = currentDocURL else { return }
        let storageKey = "vachanam_annotations_\(docURL.lastPathComponent)"
        
        struct EncodedContainer: Codable {
            let drawings: [Int: Data]
            let shapes: [ShapeAnnotation]
            let stickyNotes: [StickyNoteAnnotation]
            let textBoxes: [TextBoxAnnotation]
        }
        
        let container = EncodedContainer(
            drawings: drawings,
            shapes: shapes,
            stickyNotes: stickyNotes,
            textBoxes: textBoxes
        )
        
        if let encoded = try? JSONEncoder().encode(container) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    public func saveDrawingData(_ data: Data, forPage pageIndex: Int) {
        drawings[pageIndex] = data
        saveAnnotations()
    }
    
    public func addShape(_ shape: ShapeAnnotation) {
        shapes.append(shape)
        saveAnnotations()
    }
    
    public func addStickyNote(_ note: StickyNoteAnnotation) {
        stickyNotes.append(note)
        saveAnnotations()
    }
    
    public func addTextBox(_ box: TextBoxAnnotation) {
        textBoxes.append(box)
        saveAnnotations()
    }
    
    public func clearCurrent() {
        drawings.removeAll()
        shapes.removeAll()
        stickyNotes.removeAll()
        textBoxes.removeAll()
    }
}
