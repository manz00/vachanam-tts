//
//  PageThumbnailGrid.swift
//  Vachanam
//
//  Visual thumbnail grid sheet for scrubbing and jumping between pages.
//

import SwiftUI
import PDFKit

public struct PageThumbnailGrid: View {
    public let document: ReaderDocument
    @Binding public var currentPageIndex: Int
    @Environment(\.dismiss) var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]
    
    public init(document: ReaderDocument, currentPageIndex: Binding<Int>) {
        self.document = document
        self._currentPageIndex = currentPageIndex
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(0..<document.pageCount, id: \.self) { pIdx in
                        Button {
                            currentPageIndex = pIdx
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(red: 0.15, green: 0.19, blue: 0.26))
                                        .aspectRatio(0.75, contentMode: .fit)
                                    
                                    Text("\(pIdx + 1)")
                                        .font(.title2.bold())
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(currentPageIndex == pIdx ? Color.amberAccent : Color.clear, lineWidth: 3)
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                                
                                Text("Page \(pIdx + 1)")
                                    .font(.caption)
                                    .foregroundColor(currentPageIndex == pIdx ? Color.amberAccent : .secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Page Overview")
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
