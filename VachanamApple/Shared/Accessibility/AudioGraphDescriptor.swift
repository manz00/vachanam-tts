//
//  AudioGraphDescriptor.swift
//  Vachanam
//
//  Foundation for graph, chart, and plot accessibility descriptions and audio sonification.
//

import Foundation
import CoreGraphics

public struct AudioGraphDescriptor: Sendable {
    public static let shared = AudioGraphDescriptor()
    
    public init() {}
    
    /// Generates a natural language description of a chart or data plot for audio narration.
    public func describeChart(
        title: String,
        summary: String,
        xAxisLabel: String? = nil,
        yAxisLabel: String? = nil,
        dataPoints: [(x: Double, y: Double)] = []
    ) -> String {
        var parts: [String] = []
        
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedTitle.isEmpty {
            parts.append("Chart: \(cleanedTitle).")
        }
        
        let cleanedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedSummary.isEmpty {
            parts.append(cleanedSummary)
        }
        
        if let x = xAxisLabel, !x.isEmpty {
            parts.append("Horizontal axis represents \(x).")
        }
        if let y = yAxisLabel, !y.isEmpty {
            parts.append("Vertical axis represents \(y).")
        }
        
        if !dataPoints.isEmpty {
            let xs = dataPoints.map { $0.x }
            let ys = dataPoints.map { $0.y }
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? 0
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? 0
            parts.append("Data spans \(dataPoints.count) points with x from \(minX) to \(maxX), and y from \(minY) to \(maxY).")
        }
        
        return parts.joined(separator: " ")
    }
}
