//
//  ReaderContainerView.swift
//  Vachanam
//
//  Main reading container hosting PDF & Reader views, overlays, controls, and annotations.
//

import SwiftUI
import PDFKit

public struct ReaderContainerView: View {
    public let document: ReaderDocument
    private let ttsController = TTSController.shared
    @ObservedObject var annotationManager = AnnotationManager.shared
    @ObservedObject var bookmarkManager = BookmarkManager.shared
    @ObservedObject var progressTracker = ReadingProgressTracker.shared
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @ObservedObject var playbackCoordinator = PlaybackCoordinator.shared
    
    @State private var currentPageIndex: Int = 0
    @State private var readingMode: ReadingMode = .pdfLayout
    @State private var activeAnnotationTool: AnnotationTool = .none
    @State private var strokeColor: Color = Color.amberAccent
    @State private var strokeWidth: CGFloat = 3.0
    
    @State private var isTOCPresented: Bool = false
    @State private var isThumbnailsPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isExportPresented: Bool = false
    @State private var extractedSentences: [SentenceItem] = []
    
    public init(document: ReaderDocument) {
        self.document = document
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            VStack(spacing: 0) {
                // Top Navigation Bar
                readerHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.08, green: 0.11, blue: 0.16))
                
                // Document Display (PDF or Reader View)
                ZStack {
                    if readingMode == .pdfLayout {
                        ZStack {
                            PDFReaderView(
                                document: document,
                                currentPageIndex: $currentPageIndex,
                                layoutMode: accessibilityManager.pdfDisplayLayout
                            )
                            

                            
                            // Annotations (Shapes & Drawings)
                            ShapeToolView(
                                pageIndex: currentPageIndex,
                                isShapeActive: activeAnnotationTool == .shape,
                                strokeColor: strokeColor,
                                strokeWidth: strokeWidth
                            )
                            
                            CanvasOverlay(
                                pageIndex: currentPageIndex,
                                isDrawingActive: .constant(activeAnnotationTool == .pen || activeAnnotationTool == .highlighter || activeAnnotationTool == .eraser),
                                selectedTool: activeAnnotationTool,
                                strokeColor: strokeColor,
                                strokeWidth: strokeWidth
                            )
                            
                            // Sticky Notes for current page
                            ForEach($annotationManager.stickyNotes.filter { $0.wrappedValue.pageIndex == currentPageIndex }) { $note in
                                StickyNoteView(note: $note) {
                                    annotationManager.stickyNotes.removeAll { $0.id == note.id }
                                    annotationManager.saveAnnotations()
                                }
                            }
                            
                            // Text Boxes for current page
                            ForEach($annotationManager.textBoxes.filter { $0.wrappedValue.pageIndex == currentPageIndex }) { $box in
                                TextBoxView(box: $box) {
                                    annotationManager.textBoxes.removeAll { $0.id == box.id }
                                    annotationManager.saveAnnotations()
                                }
                            }
                        }
                    } else {
                        ReaderTextView(sentences: extractedSentences)
                    }
                    
                    // Dyslexia Reading Ruler Guide
                    ReadingRuler()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Floating Overlays: Annotation Toolbar, Prompt Pill & TTS Controls
            VStack(spacing: 10) {
                if activeAnnotationTool != .none {
                    AnnotationToolbar(
                        activeTool: $activeAnnotationTool,
                        strokeColor: $strokeColor,
                        strokeWidth: $strokeWidth
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                if playbackCoordinator.isPlaying && playbackCoordinator.isUserScrolledAway {
                    jumpToSpokenSentencePill
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
                
                TTSControlBar(documentTitle: document.title)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .background(Color(red: 0.05, green: 0.08, blue: 0.13))
        .navigationBarHidden(true)
        .onAppear {
            initializeDocument()
            annotationManager.loadAnnotations(for: document.fileURL)
            let savedPage = progressTracker.lastPage(for: document.fileURL)
            if savedPage > 0 && savedPage < document.pageCount {
                currentPageIndex = savedPage
            }
        }
        .onChange(of: currentPageIndex) { _, newPage in
            progressTracker.recordProgress(
                documentURL: document.fileURL,
                title: document.title,
                currentPage: newPage,
                totalPages: document.pageCount
            )
        }
        .sheet(isPresented: $isTOCPresented) {
            TOCView(document: document, currentPageIndex: $currentPageIndex)
        }
        .sheet(isPresented: $isThumbnailsPresented) {
            PageThumbnailGrid(document: document, currentPageIndex: $currentPageIndex)
        }
        .sheet(isPresented: $isSettingsPresented) {
            HighlightSettingsView()
        }
        .sheet(isPresented: $isExportPresented) {
            let md = AnnotationExporter.exportToMarkdown(
                documentTitle: document.title,
                stickyNotes: annotationManager.stickyNotes,
                textBoxes: annotationManager.textBoxes,
                shapes: annotationManager.shapes,
                bookmarks: bookmarkManager.bookmarks(for: document.fileURL)
            )
            AnnotationExportView(markdownContent: md)
        }
    }
    
    private var readerHeader: some View {
        HStack(spacing: 14) {
            Button {
                ttsController.stop()
                withAnimation(.easeInOut(duration: 0.25)) {
                    AppState.shared.closeCurrentDocument()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Library")
                }
                .foregroundColor(.white)
            }
            
            Spacer()
            
            if document.format == .pdf {
                ReadingModeToggle(selectedMode: $readingMode)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: document.format.systemImage)
                        .font(.system(size: 12))
                        .foregroundColor(Color.amberAccent)
                    Text(document.format.badgeText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Header Action Buttons
            HStack(spacing: 12) {
                Button {
                    bookmarkManager.toggleBookmark(
                        documentURL: document.fileURL,
                        pageIndex: currentPageIndex,
                        pageTitle: "Page \(currentPageIndex + 1)"
                    )
                } label: {
                    Image(systemName: bookmarkManager.isBookmarked(documentURL: document.fileURL, pageIndex: currentPageIndex) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(Color.amberAccent)
                }
                
                Button {
                    isTOCPresented = true
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.white)
                }
                
                Button {
                    isThumbnailsPresented = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.white)
                }
                
                if document.format == .pdf && readingMode == .pdfLayout {
                    Menu {
                        ForEach(PDFDisplayLayoutMode.allCases) { mode in
                            Button {
                                accessibilityManager.pdfDisplayLayout = mode
                            } label: {
                                HStack {
                                    Text(mode.rawValue)
                                    if accessibilityManager.pdfDisplayLayout == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: accessibilityManager.pdfDisplayLayout.iconName)
                            .foregroundColor(.white)
                    }
                }
                
                Button {
                    withAnimation {
                        activeAnnotationTool = (activeAnnotationTool == .none) ? .pen : .none
                    }
                } label: {
                    Image(systemName: "pencil.and.outline")
                        .foregroundColor(activeAnnotationTool != .none ? Color.amberAccent : .white)
                }
                
                Button {
                    isExportPresented = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white)
                }
                
                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func initializeDocument() {
        let docTitle = document.title
        let docID = document.id
        let docFormat = document.format
        let pdfDoc = document.pdfDocument
        let existingSemDoc = document.semanticDocument
        let fileURL = document.fileURL
        let targetDoc = document
        
        PlaybackCoordinator.shared.setVisiblePageIndex(currentPageIndex)
        
        if docFormat != .pdf {
            readingMode = .readerView
        }
        
        Task.detached(priority: .userInitiated) {
            let semDoc: SemanticDocument
            if docFormat == .pdf {
                semDoc = await SentenceSegmenter.shared.parseDocumentAsync(
                    pdfDocument: pdfDoc,
                    title: docTitle,
                    documentID: docID
                )
            } else if let existing = existingSemDoc {
                semDoc = existing
            } else {
                do {
                    let parsed = try await DocumentParserResolver.shared.parse(
                        source: .fileURL(fileURL),
                        format: docFormat
                    )
                    let built = SemanticDocumentBuilder.shared.build(from: parsed, documentID: docID)
                    await MainActor.run {
                        targetDoc.semanticDocument = built
                        targetDoc.parsedDocument = parsed
                        targetDoc.pageCount = built.pageCount
                    }
                    semDoc = built
                } catch {
                    print("Failed to parse non-PDF document: \(error.localizedDescription)")
                    let fallback = ParsedDocument(
                        title: docTitle,
                        format: docFormat,
                        chapters: [ParsedChapter(title: docTitle, blocks: [
                            ParsedBlock(type: .paragraph, text: "Could not load document: \(error.localizedDescription)")
                        ])]
                    )
                    semDoc = SemanticDocumentBuilder.shared.build(from: fallback, documentID: docID)
                }
            }
            
            await MainActor.run {
                ttsController.loadDocument(semDoc)
                extractedSentences = semDoc.sentences.map { SentenceItem(from: $0) }
            }
        }
        
        ttsController.onPageChanged = { [self] newPage in
            if self.currentPageIndex != newPage && newPage >= 0 && newPage < self.document.pageCount {
                self.currentPageIndex = newPage
                PlaybackCoordinator.shared.setVisiblePageIndex(newPage)
            }
        }
        
        ttsController.onPageCompleted = { [self] in
            // PlaybackCoordinator strictly enforces scope boundaries and stops automatically.
            // Record progress without forcing unwanted page looping.
            self.progressTracker.recordProgress(
                documentURL: self.document.fileURL,
                title: self.document.title,
                currentPage: self.currentPageIndex,
                totalPages: self.document.pageCount
            )
        }
    }
    
    private var jumpToSpokenSentencePill: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                playbackCoordinator.jumpToSpokenSentence()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: playbackCoordinator.scrolledAwayDirection == .above ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(playbackCoordinator.scrolledAwayDirection == .above ? "Spoken text is above" : "Spoken text is below")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        
                        if let page = playbackCoordinator.scrolledAwayPageIndex {
                            Text("Page \(page + 1)")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white.opacity(0.9))
                                .cornerRadius(6)
                        }
                    }
                    
                    if !playbackCoordinator.scrolledAwaySnippet.isEmpty {
                        Text(playbackCoordinator.scrolledAwaySnippet)
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 8)
                
                HStack(spacing: 4) {
                    Text("Jump")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.25))
                .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
                .cornerRadius(10)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.09, green: 0.13, blue: 0.20).opacity(0.96))
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }
}
