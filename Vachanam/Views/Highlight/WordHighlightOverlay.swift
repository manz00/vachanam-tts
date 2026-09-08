//
//  WordHighlightOverlay.swift
//  Vachanam
//
//  Real-time word-by-word highlight overlay mapped to page coordinates.
//

import SwiftUI

public struct WordHighlightOverlay: View {
    public let wordRect: CGRect?
    public let pageScale: CGFloat
    public let pageOffset: CGPoint
    public let highlightColor: Color
    
    public init(wordRect: CGRect?, pageScale: CGFloat = 1.0, pageOffset: CGPoint = .zero, highlightColor: Color = Color.amberAccent) {
        self.wordRect = wordRect
        self.pageScale = pageScale
        self.pageOffset = pageOffset
        self.highlightColor = highlightColor
    }
    
    public var body: some View {
        if let rect = wordRect, !rect.isEmpty {
            let adjustedRect = CGRect(
                x: (rect.origin.x * pageScale) + pageOffset.x,
                y: (rect.origin.y * pageScale) + pageOffset.y,
                width: rect.width * pageScale,
                height: rect.height * pageScale
            )
            
            RoundedRectangle(cornerRadius: 3.0)
                .fill(highlightColor.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 3.0)
                        .stroke(highlightColor, lineWidth: 1.5)
                )
                .frame(width: adjustedRect.width, height: adjustedRect.height)
                .position(x: adjustedRect.midX, y: adjustedRect.midY)
                .animation(.easeInOut(duration: 0.12), value: rect)
        }
    }
}
