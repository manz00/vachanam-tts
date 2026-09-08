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
    @ObservedObject var ttsController = TTSController.shared
    @ObservedObject var annotationManager = AnnotationManager.shared
    @ObservedObject var bookmarkManager = BookmarkManager.shared
    @ObservedObject var progressTracker = ReadingProgressTracker.shared
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    
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
    
    @Environment(\.dismiss) var dismiss
    
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
                            PDFReaderView(document: document, currentPageIndex: $currentPageIndex)
                            
                            // Highlighting Overlays (in PDF mode)
                            if ttsController.isPlaying {
                                if accessibilityManager.highlightMode == .both || accessibilityManager.highlightMode == .sentenceOnly {
                                    SentenceHighlightOverlay(
                                        sentenceRect: ttsController.currentSentence?.bounds,
                                        highlightColor: accessibilityManager.colorChoice.sentenceColor
                                    )
                                }
                                
                                if accessibilityManager.highlightMode == .both || accessibilityManager.highlightMode == .wordOnly {
                                    WordHighlightOverlay(
                                        wordRect: ttsController.currentWord?.bounds,
                                        highlightColor: accessibilityManager.colorChoice.wordColor
                                    )
                                }
                            }
                            
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
                    ReadingRuler(currentY: ttsController.currentSentence?.bounds.origin.y ?? 200)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Floating Overlays: Annotation Toolbar & TTS Controls
            VStack(spacing: 12) {
                if activeAnnotationTool != .none {
                    AnnotationToolbar(
                        activeTool: $activeAnnotationTool,
                        strokeColor: $strokeColor,
                        strokeWidth: $strokeWidth
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                TTSControlBar(documentTitle: document.title)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .background(Color(red: 0.05, green: 0.08, blue: 0.13))
        .navigationBarHidden(true)
        .onAppear {
            loadCurrentPageContent()
            annotationManager.loadAnnotations(for: document.fileURL)
            let savedPage = progressTracker.lastPage(for: document.fileURL)
            if savedPage > 0 && savedPage < document.pageCount {
                currentPageIndex = savedPage
            }
        }
        .onChange(of: currentPageIndex) { newPage in
            loadCurrentPageContent()
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
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Library")
                }
                .foregroundColor(.white)
            }
            
            Spacer()
            
            ReadingModeToggle(selectedMode: $readingMode)
            
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
    
    private func loadCurrentPageContent() {
        guard let page = document.page(at: currentPageIndex) else { return }
        extractedSentences = TextExtractor.shared.extractSentences(from: page, pageIndex: currentPageIndex)
        ttsController.loadSentences(extractedSentences)
        
        ttsController.onPageCompleted = {
            if self.currentPageIndex < self.document.pageCount - 1 {
                self.currentPageIndex += 1
                self.ttsController.play()
            } else {
                self.ttsController.stop()
            }
        }
    }
}
