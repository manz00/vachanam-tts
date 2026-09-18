//
//  BookStructureSheet.swift
//  Vachanam
//
//  Apple Books-inspired structural book intelligence modal sheet:
//  detailed breakdown of chapters, word counts, visual reading duration,
//  and neural TTS spoken audio duration.
//

import SwiftUI

public struct BookStructureSheet: View {
    public let document: ReaderDocument
    @ObservedObject var preparationService = BookPreparationService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var isPreparing: Bool = false
    @State private var preparationError: String? = nil
    
    public init(document: ReaderDocument) {
        self.document = document
    }
    
    private var record: BookPreparationRecord? {
        preparationService.record(for: document.fileURL.path)
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Document Overview Card
                    overviewCard
                    
                    // Chapters Breakdown
                    if let rec = record {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Chapters & Structure")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(rec.chapterCount) sections")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                            
                            ForEach(rec.chapterSummaries) { ch in
                                HStack(spacing: 12) {
                                    Text("\(ch.chapterIndex + 1)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.amberAccent)
                                        .frame(width: 24, height: 24)
                                        .background(Color.amberAccent.opacity(0.15))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ch.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text("\(ch.wordCount) words")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "headphones")
                                            .font(.system(size: 10))
                                        Text("~\(ch.estimatedAudioMinutes) min")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.tealAccent.opacity(0.18))
                                    .foregroundColor(Color.tealAccent)
                                    .cornerRadius(6)
                                }
                                .padding(12)
                                .background(Color(red: 0.10, green: 0.14, blue: 0.22))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                    } else {
                        // Unprepared State
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 44))
                                .foregroundColor(Color.amberAccent)
                                .padding(.top, 24)
                            
                            Text("Book Not Prepared Yet")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Run one-tap voice preparation to structure chapters, normalize text for neural speech, and calculate audio durations.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button {
                                triggerPreparation()
                            } label: {
                                HStack(spacing: 8) {
                                    if isPreparing {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Image(systemName: "bolt.fill")
                                    }
                                    Text(isPreparing ? "Analyzing & Normalizing..." : "Prepare Book for Voice")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.amberAccent)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                            }
                            .disabled(isPreparing)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color(red: 0.08, green: 0.11, blue: 0.17))
                        .cornerRadius(12)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.05, green: 0.08, blue: 0.13))
            .navigationTitle("Book Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.amberAccent)
                }
            }
            .onAppear {
                if record == nil {
                    triggerPreparation()
                }
            }
        }
    }
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: document.format.systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(Color.amberAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(document.format.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if record != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Voice Ready")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.20))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Stats Grid
            HStack(spacing: 16) {
                statItem(
                    title: "Word Count",
                    value: record != nil ? "\(record!.wordCount.formatted())" : "—",
                    icon: "character.book.closed"
                )
                
                statItem(
                    title: "Reading Time",
                    value: record != nil ? "~\(record!.estimatedReadingMinutes)m" : "—",
                    icon: "book"
                )
                
                statItem(
                    title: "Audio Time",
                    value: record != nil ? "~\(record!.estimatedAudioMinutes)m" : "—",
                    icon: "headphones"
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.15, blue: 0.23), Color(red: 0.08, green: 0.11, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(Color.amberAccent)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func triggerPreparation() {
        isPreparing = true
        Task {
            do {
                try await preparationService.prepareBook(at: document.fileURL)
                await MainActor.run {
                    isPreparing = false
                }
            } catch {
                await MainActor.run {
                    isPreparing = false
                    preparationError = error.localizedDescription
                }
            }
        }
    }
}
