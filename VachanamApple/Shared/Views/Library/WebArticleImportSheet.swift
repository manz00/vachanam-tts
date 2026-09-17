//
//  WebArticleImportSheet.swift
//  Vachanam
//
//  Sheet to fetch, extract, and read online articles via URL.
//

import SwiftUI

public struct WebArticleImportSheet: View {
    public let onDocumentImported: (ReaderDocument) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var urlString: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    public init(onDocumentImported: @escaping (ReaderDocument) -> Void) {
        self.onDocumentImported = onDocumentImported
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header Icon
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.tealAccent.opacity(0.18))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "globe")
                            .font(.system(size: 32))
                            .foregroundColor(Color.tealAccent)
                    }
                    
                    Text("Import Web Article")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Paste any web article link. Vachanam strips ads and navigation to provide an accessible, high-speed reading experience.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 16)
                
                // URL Input Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("https://example.com/article...", text: $urlString)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .foregroundColor(.white)
                        
                        if !urlString.isEmpty {
                            Button {
                                urlString = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    Button {
                        if let pasted = UIPasteboard.general.string {
                            urlString = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste from Clipboard")
                        }
                        .font(.caption)
                        .foregroundColor(Color.amberAccent)
                    }
                    .padding(.top, 2)
                    #endif
                }
                .padding(.horizontal, 24)
                
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Action Button
                Button {
                    Task {
                        await fetchArticle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Fetch & Read Article")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? Color.gray.opacity(0.5) : Color.amberAccent)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color(red: 0.08, green: 0.11, blue: 0.16))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    @MainActor
    private func fetchArticle() async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var url = URL(string: trimmed) else {
            errorMessage = "Please enter a valid URL."
            return
        }
        
        if url.scheme == nil {
            url = URL(string: "https://" + trimmed) ?? url
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let parsed = try await WebArticleParser().parse(from: .webURL(url))
            let docID = UUID()
            let semDoc = SemanticDocumentBuilder.shared.build(from: parsed, documentID: docID)
            
            // Save local cache for offline reading and persistent history
            let appDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let webArticlesDir = appDocs.appendingPathComponent("WebArticles", isDirectory: true)
            try? FileManager.default.createDirectory(at: webArticlesDir, withIntermediateDirectories: true)
            
            let safeTitle = parsed.title.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
            let localURL = webArticlesDir.appendingPathComponent("\(safeTitle.prefix(40))_\(docID.uuidString.prefix(6)).txt")
            
            let plainText = parsed.chapters.flatMap { $0.blocks.map { $0.text } }.joined(separator: "\n\n")
            try? plainText.write(to: localURL, atomically: true, encoding: .utf8)
            
            let readerDoc = ReaderDocument(
                parsedDocument: parsed,
                fileURL: localURL,
                semanticDocument: semDoc
            )
            
            ReadingProgressTracker.shared.recordProgress(
                documentURL: localURL,
                title: parsed.title,
                currentPage: 0,
                totalPages: semDoc.pageCount
            )
            
            isLoading = false
            dismiss()
            onDocumentImported(readerDoc)
        } catch {
            isLoading = false
            errorMessage = "Failed to fetch article: \(error.localizedDescription)"
        }
    }
}
