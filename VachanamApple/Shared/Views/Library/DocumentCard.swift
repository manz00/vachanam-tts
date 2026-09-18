//
//  DocumentCard.swift
//  Vachanam
//
//  Card preview for a document showing thumbnail, format, reading progress,
//  favorite/finished badges, and Apple Books-style context menu actions.
//

import SwiftUI

public struct DocumentCard: View {
    public let title: String
    public let progressFraction: Double
    public let progressPercent: String
    public let pageCount: Int?
    public let lastOpenedDate: Date?
    public let format: DocumentFormat
    public let documentPath: String
    public let isFavorite: Bool
    public let isFinished: Bool
    public let isPrepared: Bool
    public let onSelect: () -> Void
    public let onToggleFavorite: (() -> Void)?
    public let onToggleFinished: (() -> Void)?
    public let onPrepare: (() -> Void)?
    public let onDelete: (() -> Void)?
    
    public init(
        title: String,
        progressFraction: Double = 0.0,
        progressPercent: String = "0%",
        pageCount: Int? = nil,
        lastOpenedDate: Date? = nil,
        format: DocumentFormat = .pdf,
        documentPath: String = "",
        isFavorite: Bool = false,
        isFinished: Bool = false,
        isPrepared: Bool = false,
        onSelect: @escaping () -> Void,
        onToggleFavorite: (() -> Void)? = nil,
        onToggleFinished: (() -> Void)? = nil,
        onPrepare: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.progressFraction = progressFraction
        self.progressPercent = progressPercent
        self.pageCount = pageCount
        self.lastOpenedDate = lastOpenedDate
        self.format = format
        self.documentPath = documentPath
        self.isFavorite = isFavorite
        self.isFinished = isFinished
        self.isPrepared = isPrepared
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
        self.onToggleFinished = onToggleFinished
        self.onPrepare = onPrepare
        self.onDelete = onDelete
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
                    
                    // Badges Overlay (Top Bar)
                    VStack {
                        HStack(spacing: 6) {
                            if isFavorite {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.pink)
                                    .padding(5)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            }
                            
                            if isFinished {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green)
                                    .padding(5)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            }
                            
                            if isPrepared {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.amberAccent)
                                    .padding(5)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text(format.badgeText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.40))
                                .cornerRadius(5)
                        }
                        .padding(8)
                        
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
        .contextMenu {
            if let onToggleFavorite = onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart.fill")
                }
            }
            
            if let onToggleFinished = onToggleFinished {
                Button {
                    onToggleFinished()
                } label: {
                    Label(isFinished ? "Mark as In Progress" : "Mark as Finished", systemImage: isFinished ? "arrow.uturn.backward" : "checkmark.seal.fill")
                }
            }
            
            if let onPrepare = onPrepare {
                Button {
                    onPrepare()
                } label: {
                    Label(isPrepared ? "Ready for Voice" : "Prepare for Voice", systemImage: "sparkles")
                }
                .disabled(isPrepared)
            }
            
            Divider()
            
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Book", systemImage: "trash")
                }
            }
        }
    }
}
