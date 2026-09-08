//
//  DocumentLibraryView.swift
//  Vachanam
//
//  Primary library view: browse PDFs, open via file picker, search, and manage settings.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

public struct DocumentLibraryView: View {
    @ObservedObject var progressTracker = ReadingProgressTracker.shared
    public let onSelectDocument: (ReaderDocument) -> Void
    
    @State private var isFilePickerPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isModelManagerPresented: Bool = false
    @State private var searchText: String = ""
    @State private var sampleDocumentURL: URL?
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]
    
    public init(onSelectDocument: @escaping (ReaderDocument) -> Void) {
        self.onSelectDocument = onSelectDocument
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Banner
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Library")
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                            Text("Accessibility-first PDF reader with on-device neural voice")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            isFilePickerPresented = true
                        } label: {
                            Label("Open PDF", systemImage: "plus")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.amberAccent)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Documents Grid
                    if progressTracker.history.isEmpty {
                        // Empty State with Sample PDF prompt
                        VStack(spacing: 16) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 56))
                                .foregroundColor(Color.amberAccent)
                                .padding(.top, 40)
                            
                            Text("No Documents Open Yet")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            
                            Text("Open any PDF from your Files or iCloud Drive, or open our built-in Accessibility Guide to try reading aloud.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 440)
                            
                            Button {
                                openBuiltinSample()
                            } label: {
                                Label("Open Sample Guide", systemImage: "book.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.tealAccent.opacity(0.25))
                                    .foregroundColor(Color.tealAccent)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    } else {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(filteredHistory) { record in
                                let url = URL(fileURLWithPath: record.documentPath)
                                DocumentCard(
                                    title: record.title,
                                    progressFraction: record.progressFraction,
                                    progressPercent: record.progressPercentString,
                                    pageCount: record.totalPages,
                                    lastOpenedDate: record.lastOpened
                                ) {
                                    if let doc = ReaderDocument(url: url) {
                                        onSelectDocument(doc)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.05, green: 0.08, blue: 0.13))
            .searchable(text: $searchText, prompt: "Search documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            isModelManagerPresented = true
                        } label: {
                            Image(systemName: "brain")
                                .foregroundColor(Color.tealAccent)
                        }
                        .help("TTS Neural Models")
                        
                        Button {
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundColor(.white)
                        }
                        .help("Settings")
                    }
                }
            }
            .fileImporter(
                isPresented: $isFilePickerPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        // Copy to app documents for persistent local access
                        let localDocURL = copyToLocalDocuments(url: url)
                        if let doc = ReaderDocument(url: localDocURL) {
                            progressTracker.recordProgress(
                                documentURL: localDocURL,
                                title: doc.title,
                                currentPage: 0,
                                totalPages: doc.pageCount
                            )
                            onSelectDocument(doc)
                        }
                    } else if let doc = ReaderDocument(url: url) {
                        onSelectDocument(doc)
                    }
                case .failure(let error):
                    print("File picker error: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
            .sheet(isPresented: $isModelManagerPresented) {
                ModelManagerView()
            }
        }
    }
    
    private var filteredHistory: [ReadingRecord] {
        if searchText.isEmpty {
            return progressTracker.history
        }
        return progressTracker.history.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func copyToLocalDocuments(url: URL) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dest = docs.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: dest)
        return FileManager.default.fileExists(atPath: dest.path) ? dest : url
    }
    
    private func openBuiltinSample() {
        // Create an accessibility sample PDF document programmatically
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Vachanam_Getting_Started.pdf")
        
        try? pdfRenderer.writePDF(to: tempURL) { context in
            context.beginPage()
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 26),
                .foregroundColor: UIColor.black
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.darkGray
            ]
            
            "Welcome to Vachanam".draw(at: CGPoint(x: 54, y: 60), withAttributes: titleAttributes)
            
            let sampleBody = """
            Vachanam is an accessibility-focused PDF reader designed for iPad and Mac.
            It features on-device neural text-to-speech, synchronized word and sentence highlighting, \
            an OpenDyslexic typography mode, and complete Apple Pencil annotation tools.

            Press the Play button below to hear this text read aloud with live karaoke-style word highlighting. \
            You can adjust reading speed from 0.5x to 2.0x, switch between Original PDF and Reader View, \
            and draw or take notes with the floating toolbar.
            """
            
            let rect = CGRect(x: 54, y: 120, width: 504, height: 600)
            sampleBody.draw(in: rect, withAttributes: bodyAttributes)
        }
        
        if let doc = ReaderDocument(url: tempURL) {
            progressTracker.recordProgress(documentURL: tempURL, title: doc.title, currentPage: 0, totalPages: 1)
            onSelectDocument(doc)
        }
    }
}
