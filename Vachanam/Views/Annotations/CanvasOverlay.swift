//
//  CanvasOverlay.swift
//  Vachanam
//
//  PencilKit canvas overlay with Apple Pencil & finger drawing support.
//

import SwiftUI
import PencilKit

public struct CanvasOverlay: UIViewRepresentable {
    public let pageIndex: Int
    @Binding public var isDrawingActive: Bool
    public var selectedTool: AnnotationTool
    public var strokeColor: Color
    public var strokeWidth: CGFloat
    
    public init(pageIndex: Int, isDrawingActive: Binding<Bool>, selectedTool: AnnotationTool = .pen, strokeColor: Color = Color.amberAccent, strokeWidth: CGFloat = 3.0) {
        self.pageIndex = pageIndex
        self._isDrawingActive = isDrawingActive
        self.selectedTool = selectedTool
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }
    
    public func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        
        #if targetEnvironment(macCatalyst)
        canvas.drawingPolicy = .anyInput
        #else
        canvas.drawingPolicy = .anyInput
        #endif
        
        // Load existing drawing if available
        if let data = AnnotationManager.shared.drawings[pageIndex],
           let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }
        
        context.coordinator.canvasView = canvas
        updateTool(for: canvas)
        return canvas
    }
    
    public func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isDrawingActive
        updateTool(for: uiView)
    }
    
    private func updateTool(for canvas: PKCanvasView) {
        let uiColor = UIColor(strokeColor)
        switch selectedTool {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: uiColor, width: strokeWidth)
        case .highlighter:
            canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.4), width: max(strokeWidth * 3.0, 14.0))
        case .eraser:
            canvas.tool = PKEraserTool(.vector)
        default:
            break
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasOverlay
        weak var canvasView: PKCanvasView?
        
        init(_ parent: CanvasOverlay) {
            self.parent = parent
        }
        
        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()
            AnnotationManager.shared.saveDrawingData(data, forPage: parent.pageIndex)
        }
    }
}
