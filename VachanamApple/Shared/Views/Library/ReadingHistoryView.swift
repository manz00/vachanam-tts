//
//  ReadingHistoryView.swift
//  Vachanam
//
//  Reading history list with resume reading options and reading statistics.
//

import SwiftUI

public struct ReadingHistoryView: View {
    @ObservedObject var tracker = ReadingProgressTracker.shared
    public let onSelectDocument: (URL) -> Void
    
    public init(onSelectDocument: @escaping (URL) -> Void) {
        self.onSelectDocument = onSelectDocument
    }
    
    public var body: some View {
        if tracker.history.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)
                Text("No Reading History")
                    .font(.headline)
                Text("Documents you open will appear here with your saved position.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(tracker.history) { record in
                Button {
                    let url = URL(fileURLWithPath: record.documentPath)
                    onSelectDocument(url)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundColor(Color.amberAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Text("Page \(record.currentPage + 1) of \(record.totalPages)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(record.progressPercentString)
                                    .font(.caption.bold())
                                    .foregroundColor(Color.tealAccent)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }
}
