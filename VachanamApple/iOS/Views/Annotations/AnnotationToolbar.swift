//
//  AnnotationToolbar.swift
//  Vachanam
//
//  Floating toolbar for Pen, Highlighter, Shapes, Notes, Text boxes, and Undo/Redo.
//

import SwiftUI

public enum AnnotationTool: String, CaseIterable, Identifiable {
    case none = "Navigate"
    case pen = "Pen"
    case highlighter = "Highlighter"
    case eraser = "Eraser"
    case shape = "Shapes"
    case stickyNote = "Note"
    case textBox = "Text"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .none: return "hand.point.up.left"
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .shape: return "square.on.circle"
        case .stickyNote: return "note.text.badge.plus"
        case .textBox: return "character.cursor.ibeam"
        }
    }
}

public struct AnnotationToolbar: View {
    @Binding public var activeTool: AnnotationTool
    @Binding public var strokeColor: Color
    @Binding public var strokeWidth: CGFloat
    @ObservedObject var undoRedo = UndoRedoManager.shared
    
    public let availableColors: [Color] = [
        Color.amberAccent,
        Color.tealAccent,
        Color(red: 0.94, green: 0.35, blue: 0.35),
        Color(red: 0.35, green: 0.65, blue: 0.95),
        Color(red: 0.98, green: 0.98, blue: 0.98)
    ]
    
    public init(activeTool: Binding<AnnotationTool>, strokeColor: Binding<Color>, strokeWidth: Binding<CGFloat>) {
        self._activeTool = activeTool
        self._strokeColor = strokeColor
        self._strokeWidth = strokeWidth
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Tools
            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    activeTool = (activeTool == tool && tool != .none) ? .none : tool
                } label: {
                    Image(systemName: tool.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(8)
                        .background(activeTool == tool ? Color.amberAccent.opacity(0.3) : Color.clear)
                        .clipShape(Circle())
                        .foregroundColor(activeTool == tool ? Color.amberAccent : .white)
                }
                .help(tool.rawValue)
            }
            
            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.3))
            
            // Color Palettes (visible when drawing tool is selected)
            if activeTool == .pen || activeTool == .highlighter || activeTool == .shape {
                HStack(spacing: 8) {
                    ForEach(0..<availableColors.count, id: \.self) { idx in
                        let color = availableColors[idx]
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: strokeColor == color ? 2.0 : 0)
                            )
                            .onTapGesture {
                                strokeColor = color
                            }
                    }
                }
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.3))
            }
            
            // Undo & Redo
            Button {
                undoRedo.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15))
                    .foregroundColor(undoRedo.canUndo ? .white : .white.opacity(0.35))
            }
            .disabled(!undoRedo.canUndo)
            
            Button {
                undoRedo.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 15))
                    .foregroundColor(undoRedo.canRedo ? .white : .white.opacity(0.35))
            }
            .disabled(!undoRedo.canRedo)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.92))
                .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
        )
    }
}
