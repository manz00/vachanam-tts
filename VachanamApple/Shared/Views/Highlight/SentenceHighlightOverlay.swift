//
//  SentenceHighlightOverlay.swift
//  Vachanam
//
//  Sentence-level highlight band enclosing the currently spoken sentence.
//

import SwiftUI

public struct SentenceHighlightOverlay: View {
    public let sentenceRect: CGRect?
    public let pageScale: CGFloat
    public let pageOffset: CGPoint
    public let highlightColor: Color
    
    public init(sentenceRect: CGRect?, pageScale: CGFloat = 1.0, pageOffset: CGPoint = .zero, highlightColor: Color = Color.tealAccent) {
        self.sentenceRect = sentenceRect
        self.pageScale = pageScale
        self.pageOffset = pageOffset
        self.highlightColor = highlightColor
    }
    
    public var body: some View {
        if let rect = sentenceRect, !rect.isEmpty {
            let adjustedRect = CGRect(
                x: (rect.origin.x * pageScale) + pageOffset.x,
                y: (rect.origin.y * pageScale) + pageOffset.y,
                width: rect.width * pageScale,
                height: rect.height * pageScale
            )
            
            RoundedRectangle(cornerRadius: 4.0)
                .fill(highlightColor.opacity(0.18))
                .frame(width: adjustedRect.width, height: adjustedRect.height)
                .position(x: adjustedRect.midX, y: adjustedRect.midY)
                .animation(.easeInOut(duration: 0.18), value: rect)
        }
    }
}
