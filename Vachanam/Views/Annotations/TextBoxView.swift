//
//  TextBoxView.swift
//  Vachanam
//
//  Draggable, editable typed text box annotations for PDF pages.
//

import SwiftUI

public struct TextBoxView: View {
    @Binding public var box: TextBoxAnnotation
    public let onDelete: () -> Void
    @FocusState private var isFocused: Bool
    
    public init(box: Binding<TextBoxAnnotation>, onDelete: @escaping () -> Void) {
        self._box = box
        self.onDelete = onDelete
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            TextField("Type note...", text: $box.text)
                .font(.system(size: box.fontSize, weight: .medium))
                .foregroundColor(.white)
                .focused($isFocused)
                .textFieldStyle(.plain)
            
            if isFocused {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.15, green: 0.20, blue: 0.28).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? Color.amberAccent : Color.white.opacity(0.2), lineWidth: 1.5)
                )
        )
        .position(box.position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    box.position = value.location
                }
        )
    }
}
