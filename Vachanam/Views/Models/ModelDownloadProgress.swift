//
//  ModelDownloadProgress.swift
//  Vachanam
//
//  Visual download progress bar for TTS neural model weights.
//

import SwiftUI

public struct ModelDownloadProgress: View {
    public let progress: Double
    
    public init(progress: Double) {
        self.progress = progress
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.tealAccent)
                        .frame(width: geometry.size.width * CGFloat(max(min(progress, 1.0), 0.0)), height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(progress * 100))% downloaded")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
