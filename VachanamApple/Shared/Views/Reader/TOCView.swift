//
//  TOCView.swift
//  Vachanam
//
//  Table of Contents drawer and Bookmarks sidebar with direct page navigation.
//

import SwiftUI

public struct TOCView: View {
    public let document: ReaderDocument
    @Binding public var currentPageIndex: Int
    @ObservedObject var bookmarkManager = BookmarkManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab: Int = 0
    
    public init(document: ReaderDocument, currentPageIndex: Binding<Int>) {
        self.document = document
        self._currentPageIndex = currentPageIndex
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    Text("Contents").tag(0)
                    Text("Bookmarks").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    if document.tocItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Table of Contents")
                                .font(.headline)
                            Text("This document does not contain an embedded outline.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        let prepRecord = BookPreparationService.shared.record(for: document.fileURL.path)
                        List(document.tocItems.indices, id: \.self) { idx in
                            let item = document.tocItems[idx]
                            let dur = prepRecord?.chapterSummaries.first(where: { $0.chapterIndex == idx || $0.title == item.title })?.estimatedAudioMinutes
                            TOCItemRow(item: item, durationMinutes: dur) { targetPage in
                                currentPageIndex = targetPage
                                dismiss()
                            }
                        }
                        .listStyle(.sidebar)
                    }
                } else {
                    let docBookmarks = bookmarkManager.bookmarks(for: document.fileURL)
                    if docBookmarks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bookmark.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Bookmarks Yet")
                                .font(.headline)
                            Text("Tap the bookmark icon on any page to add one.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(docBookmarks) { bookmark in
                            Button {
                                currentPageIndex = bookmark.pageIndex
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundColor(Color.amberAccent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookmark.pageTitle.isEmpty ? "Page \(bookmark.pageIndex + 1)" : bookmark.pageTitle)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Saved \(DateFormatter.localizedString(from: bookmark.createdAt, dateStyle: .short, timeStyle: .none))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TOCItemRow: View {
    let item: TOCItem
    var durationMinutes: Int? = nil
    let onSelect: (Int) -> Void
    
    var body: some View {
        Button {
            onSelect(item.pageIndex)
        } label: {
            HStack(spacing: 8) {
                Text(item.title)
                    .foregroundColor(.white)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                if let dur = durationMinutes {
                    HStack(spacing: 3) {
                        Image(systemName: "headphones")
                            .font(.system(size: 9))
                        Text("~\(dur)m")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.tealAccent.opacity(0.18))
                    .foregroundColor(Color.tealAccent)
                    .cornerRadius(4)
                }
                
                Text("p. \(item.pageIndex + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
        
        if !item.children.isEmpty {
            ForEach(item.children) { child in
                TOCItemRow(item: child, durationMinutes: nil, onSelect: onSelect)
                    .padding(.leading, 16)
            }
        }
    }
}
