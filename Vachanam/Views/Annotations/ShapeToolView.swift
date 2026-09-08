//
//  ShapeToolView.swift
//  Vachanam
//
//  Geometric shape overlay for rectangles, circles, arrows, and callouts.
//

import SwiftUI

public struct ShapeToolView: View {
    public let pageIndex: Int
    public let isShapeActive: Bool
    public let strokeColor: Color
    public let strokeWidth: CGFloat
    @ObservedObject var annotationManager = AnnotationManager.shared
    
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var selectedShapeType: ShapeType = .rectangle
    
    public init(pageIndex: Int, isShapeActive: Bool, strokeColor: Color = Color.amberAccent, strokeWidth: CGFloat = 3.0) {
        self.pageIndex = pageIndex
        self.isShapeActive = isShapeActive
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }
    
    public var body: some View {
        ZStack {
            // Render existing shapes
            ForEach(annotationManager.shapes.filter { $0.pageIndex == pageIndex }) { shape in
                renderShape(shape)
            }
            
            // Render currently dragging shape preview
            if let start = dragStart, let current = dragCurrent {
                let preview = ShapeAnnotation(
                    pageIndex: pageIndex,
                    shapeType: selectedShapeType,
                    startPoint: start,
                    endPoint: current,
                    strokeColorHex: "#F59E0B",
                    lineWidth: strokeWidth
                )
                renderShape(preview)
                    .opacity(0.85)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            isShapeActive ? DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = value.startLocation
                    }
                    dragCurrent = value.location
                }
                .onEnded { value in
                    if let start = dragStart {
                        let newShape = ShapeAnnotation(
                            pageIndex: pageIndex,
                            shapeType: selectedShapeType,
                            startPoint: start,
                            endPoint: value.location,
                            strokeColorHex: "#F59E0B",
                            lineWidth: strokeWidth
                        )
                        annotationManager.addShape(newShape)
                    }
                    dragStart = nil
                    dragCurrent = nil
                } : nil
        )
    }
    
    @ViewBuilder
    private func renderShape(_ shape: ShapeAnnotation) -> some View {
        let rect = CGRect(
            x: min(shape.startPoint.x, shape.endPoint.x),
            y: min(shape.startPoint.y, shape.endPoint.y),
            width: max(abs(shape.endPoint.x - shape.startPoint.x), 10),
            height: max(abs(shape.endPoint.y - shape.startPoint.y), 10)
        )
        
        switch shape.shapeType {
        case .rectangle:
            RoundedRectangle(cornerRadius: 4)
                .stroke(strokeColor, lineWidth: shape.lineWidth)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .circle:
            Ellipse()
                .stroke(strokeColor, lineWidth: shape.lineWidth)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .line, .arrow:
            Path { path in
                path.move(to: shape.startPoint)
                path.addLine(to: shape.endPoint)
            }
            .stroke(strokeColor, lineWidth: shape.lineWidth)
        }
    }
}
