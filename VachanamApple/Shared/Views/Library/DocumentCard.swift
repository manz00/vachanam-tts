//
//  DocumentCard.swift
//  Vachanam
//
//  Card preview for a PDF document showing thumbnail, title, and reading progress.
//

import SwiftUI

public struct DocumentCard: View {
    public let title: String
    public let progressFraction: Double
    public let progressPercent: String
    public let pageCount: Int?
    public let lastOpenedDate: Date?
    public let format: DocumentFormat
    public let onSelect: () -> Void
    
    public init(
        title: String,
        progressFraction: Double = 0.0,
        progressPercent: String = "0%",
        pageCount: Int? = nil,
        lastOpenedDate: Date? = nil,
        format: DocumentFormat = .pdf,
        onSelect: @escaping () -> Void
    ) {
        self.title = title
        self.progressFraction = progressFraction
        self.progressPercent = progressPercent
        self.pageCount = pageCount
        self.lastOpenedDate = lastOpenedDate
        self.format = format
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover Graphic
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.16, blue: 0.24), Color(red: 0.08, green: 0.11, blue: 0.17)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(0.72, contentMode: .fit)
                    
                    VStack(spacing: 8) {
                        Image(systemName: format.systemImage)
                            .font(.system(size: 42))
                            .foregroundColor(format == .pdf ? Color.amberAccent : Color.tealAccent)
                        
                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 10)
                    }
                    
                    // Format badge top-trailing
                    VStack {
                        HStack {
                            Spacer()
                            Text(format.badgeText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(5)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
                
                // Document Info & Progress
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let date = lastOpenedDate {
                        Text("Opened \(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        ProgressBar(progress: progressFraction)
                        Text(progressPercent)
                            .font(.caption2.bold())
                            .foregroundColor(Color.amberAccent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
