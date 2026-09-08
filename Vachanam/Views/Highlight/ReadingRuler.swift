//
//  ReadingRuler.swift
//  Vachanam
//
//  Dyslexia reading ruler overlay with customizable height, opacity, and vertical tracking.
//

import SwiftUI

public struct ReadingRuler: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @ObservedObject var ttsController = TTSController.shared
    @State private var dragOffset: CGFloat = 0.0
    
    public init() {}
    
    public var body: some View {
        if accessibilityManager.isReadingRulerEnabled {
            let currentY = ttsController.currentSentenceViewRect?.origin.y ?? 200
            GeometryReader { geometry in
                let targetY = max(min(currentY + dragOffset, geometry.size.height - accessibilityManager.readingRulerHeight), 0)
                
                ZStack(alignment: .top) {
                    // Top Dimmer
                    Color.black.opacity(0.40)
                        .frame(height: targetY)
                    
                    // Transparent Ruler Window with Border Guide
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(accessibilityManager.colorChoice.wordColor)
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(accessibilityManager.colorChoice.sentenceColor.opacity(accessibilityManager.readingRulerOpacity))
                            .frame(height: accessibilityManager.readingRulerHeight - 4)
                        
                        Rectangle()
                            .fill(accessibilityManager.colorChoice.wordColor)
                            .frame(height: 2)
                    }
                    .frame(height: accessibilityManager.readingRulerHeight)
                    .offset(y: targetY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.height
                            }
                            .onEnded { _ in
                                // Keep manual adjustments
                            }
                    )
                    
                    // Bottom Dimmer
                    Color.black.opacity(0.40)
                        .frame(height: max(geometry.size.height - (targetY + accessibilityManager.readingRulerHeight), 0))
                        .offset(y: targetY + accessibilityManager.readingRulerHeight)
                }
                .allowsHitTesting(true)
            }
        }
    }
}
