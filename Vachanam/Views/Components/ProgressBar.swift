//
//  ProgressBar.swift
//  Vachanam
//
//  Linear reading progress bar with subtle gradients.
//

import SwiftUI

public struct ProgressBar: View {
    public let progress: Double
    
    public init(progress: Double) {
        self.progress = progress
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color.amberAccent, Color.tealAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(max(min(progress, 1.0), 0.0)), height: 6)
            }
        }
        .frame(height: 6)
    }
}
