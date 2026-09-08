//
//  StickyNoteView.swift
//  Vachanam
//
//  Draggable, expandable sticky note pins with rich text editing.
//

import SwiftUI

public struct StickyNoteView: View {
    @Binding public var note: StickyNoteAnnotation
    public let onDelete: () -> Void
    @State private var isExpanded: Bool = false
    
    public init(note: Binding<StickyNoteAnnotation>, onDelete: @escaping () -> Void) {
        self._note = note
        self.onDelete = onDelete
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.black.opacity(0.8))
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black.opacity(0.6))
                }
                
                if isExpanded {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            
            if isExpanded {
                TextEditor(text: $note.content)
                    .frame(width: 180, height: 90)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(10)
        .background(Color(red: 0.99, green: 0.90, blue: 0.45))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
        .position(note.position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    note.position = value.location
                }
        )
    }
}
