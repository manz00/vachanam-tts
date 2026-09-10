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
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var currentPageIndex: Int
    @State private var readingMode: ReadingMode = .pdfLayout
    @State private var activeAnnotationTool: AnnotationTool = .none
    @State private var strokeColor: Color = Color.amberAccent
    @State private var strokeWidth: CGFloat = 3.0
    
    @State private var isTOCPresented: Bool = false
    @State private var isThumbnailsPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isExportPresented: Bool = false
    @State private var isShortcutsPresented: Bool = false
    @State private var extractedSentences: [SentenceItem] = []
    @State private var progressSaveTask: Task<Void, Never>?
    @State private var isLayoutTransitioning: Bool = false
    @State private var isDocumentInitialized: Bool = false
    
    public init(document: ReaderDocument) {
        self.document = document
        let savedPage = ReadingProgressTracker.shared.lastPage(for: document.fileURL)
        let validPage = (savedPage >= 0 && savedPage < document.pageCount) ? savedPage : 0
        self._currentPageIndex = State(initialValue: validPage)
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
                            .allowsHitTesting(activeAnnotationTool == .shape)
                            
                            CanvasOverlay(
                                pageIndex: currentPageIndex,
                                isDrawingActive: .constant(activeAnnotationTool == .pen || activeAnnotationTool == .highlighter || activeAnnotationTool == .eraser),
                                selectedTool: activeAnnotationTool,
                                strokeColor: strokeColor,
                                strokeWidth: strokeWidth
                            )
                            .allowsHitTesting(activeAnnotationTool == .pen || activeAnnotationTool == .highlighter || activeAnnotationTool == .eraser)
                            
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
            
            // Floating Overlays: Annotation Toolbar, Prompt Pill, Scrubber & TTS Controls
            VStack(spacing: 8) {
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
                
                // Page Scrubber & Scroll Navigation Toolbar
                ReaderScrubberBar(
                    currentPageIndex: $currentPageIndex,
                    totalPages: document.pageCount,
                    isPDF: document.format == .pdf
                )
                .padding(.horizontal, 20)
                
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
        }
        .onChange(of: currentPageIndex) { _, _ in
            guard isDocumentInitialized else { return }
            // Debounce progress saving to prevent cascading updates during rapid navigation or mode switches
            progressSaveTask?.cancel()
            progressSaveTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled {
                    saveCurrentProgress()
                }
            }
        }
        .onReceive(playbackCoordinator.$visiblePageIndex) { newPage in
            // Guard: do not let the coordinator's stale value overwrite the restored page
            // until initializeDocument() has finished syncing the coordinator.
            guard isDocumentInitialized else { return }
            if currentPageIndex != newPage && newPage >= 0 && newPage < document.pageCount {
                currentPageIndex = newPage
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                saveCurrentProgress()
            }
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
        .sheet(isPresented: $isShortcutsPresented) {
            KeyboardShortcutsSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .readerGoToNextPage)) { _ in
            if readingMode == .readerView, currentPageIndex < document.pageCount - 1 {
                currentPageIndex += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .readerGoToPreviousPage)) { _ in
            if readingMode == .readerView, currentPageIndex > 0 {
                currentPageIndex -= 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .readerJumpToPage)) { notif in
            if let target = notif.userInfo?["pageIndex"] as? Int, target >= 0, target < document.pageCount {
                currentPageIndex = target
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            NotificationCenter.default.post(name: .readerPageDown, object: nil)
            return .handled
        }
        .onKeyPress { keyPress in
            if keyPress.characters == "?" {
                isShortcutsPresented.toggle()
                return .handled
            }
            return .ignored
        }
        .background(
            // Hidden keyboard shortcut buttons ensuring macOS/iPad keyboard shortcuts trigger reliably
            ZStack {
                Group {
                    Button("") { NotificationCenter.default.post(name: .readerGoToNextPage, object: nil) }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                    Button("") { NotificationCenter.default.post(name: .readerGoToPreviousPage, object: nil) }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                    Button("") { NotificationCenter.default.post(name: .readerScrollDown, object: nil) }
                        .keyboardShortcut(.downArrow, modifiers: [])
                    Button("") { NotificationCenter.default.post(name: .readerScrollUp, object: nil) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                    Button("") { NotificationCenter.default.post(name: .readerGoToFirstPage, object: nil) }
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button("") { NotificationCenter.default.post(name: .readerGoToLastPage, object: nil) }
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                    Button("") { NotificationCenter.default.post(name: .readerGoToFirstPage, object: nil) }
                        .keyboardShortcut(.upArrow, modifiers: .command)
                    Button("") { NotificationCenter.default.post(name: .readerGoToLastPage, object: nil) }
                        .keyboardShortcut(.downArrow, modifiers: .command)
                    Button("") { NotificationCenter.default.post(name: .readerZoomIn, object: nil) }
                        .keyboardShortcut("+", modifiers: .command)
                    Button("") { NotificationCenter.default.post(name: .readerZoomIn, object: nil) }
                        .keyboardShortcut("=", modifiers: .command)
                    Button("") { NotificationCenter.default.post(name: .readerZoomOut, object: nil) }
                        .keyboardShortcut("-", modifiers: .command)
                    Button("") { NotificationCenter.default.post(name: .readerResetZoom, object: nil) }
                        .keyboardShortcut("0", modifiers: .command)
                }
                Group {
                    Button("") {
                        if ttsController.isPlaying {
                            ttsController.pause()
                        } else {
                            ttsController.play()
                        }
                    }
                    .keyboardShortcut(.space, modifiers: .option)
                    
                    Button("") { ttsController.nextSentence() }
                        .keyboardShortcut(.rightArrow, modifiers: .option)
                    Button("") { ttsController.previousSentence() }
                        .keyboardShortcut(.leftArrow, modifiers: .option)
                    Button("") { ttsController.nextSentence() }
                        .keyboardShortcut("]", modifiers: .command)
                    Button("") { ttsController.previousSentence() }
                        .keyboardShortcut("[", modifiers: .command)
                    
                    Button("") {
                        bookmarkManager.toggleBookmark(
                            documentURL: document.fileURL,
                            pageIndex: currentPageIndex,
                            pageTitle: "Page \(currentPageIndex + 1)"
                        )
                    }
                    .keyboardShortcut("b", modifiers: .command)
                    
                    Button("") { isTOCPresented.toggle() }
                        .keyboardShortcut("t", modifiers: .command)
                    
                    Button("") { isThumbnailsPresented.toggle() }
                        .keyboardShortcut("g", modifiers: .command)
                    
                    Button("") { isSettingsPresented.toggle() }
                        .keyboardShortcut(",", modifiers: .command)
                    
                    Button("") { isExportPresented.toggle() }
                        .keyboardShortcut("e", modifiers: .command)
                    
                    Button("") {
                        withAnimation {
                            accessibilityManager.isReadingRulerEnabled.toggle()
                        }
                    }
                    .keyboardShortcut("d", modifiers: .command)
                    
                    Button("") { isShortcutsPresented.toggle() }
                        .keyboardShortcut("/", modifiers: .command)
                    
                    Button("") {
                        accessibilityManager.pdfDisplayLayout = .singlePage
                    }
                    .keyboardShortcut("1", modifiers: .command)
                    
                    Button("") {
                        accessibilityManager.pdfDisplayLayout = .singlePageContinuous
                    }
                    .keyboardShortcut("2", modifiers: .command)
                    
                    Button("") {
                        accessibilityManager.pdfDisplayLayout = .twoUp
                    }
                    .keyboardShortcut("3", modifiers: .command)
                    
                    Button("") {
                        accessibilityManager.pdfDisplayLayout = .twoUpContinuous
                    }
                    .keyboardShortcut("4", modifiers: .command)
                    
                    Button("") {
                        saveCurrentProgress()
                        ttsController.stop()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            AppState.shared.closeCurrentDocument()
                        }
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
            .opacity(0.001)
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
        )
    }
    
    private func saveCurrentProgress() {
        if isLayoutTransitioning && currentPageIndex == 0 {
            if progressTracker.lastPage(for: document.fileURL) > 0 {
                return
            }
        }
        
        let coord = PlaybackCoordinator.shared
        let isMatchingDoc = coord.activeSemanticDocument?.documentID == document.id || coord.activeSemanticDocument?.title == document.title
        
        let page: Int
        let wordID: Int?
        let sentenceID: Int?
        
        if coord.isPlaying, isMatchingDoc, let c = coord.cursor {
            // Actively listening: record real-time spoken cursor
            page = c.pageIndex
            wordID = coord.currentWordID ?? c.globalWordID
            sentenceID = coord.currentSentenceID ?? c.sentenceIndex
        } else if isMatchingDoc, let c = coord.cursor, c.pageIndex == currentPageIndex {
            // Paused/stopped on current visible page: preserve spoken cursor position
            page = currentPageIndex
            wordID = coord.currentWordID ?? c.globalWordID
            sentenceID = coord.currentSentenceID ?? c.sentenceIndex
        } else {
            // Reading / scrolling: record visible page index
            page = currentPageIndex
            // Only preserve wordID if it belongs to this page
            if let savedWid = progressTracker.lastWordID(for: document.fileURL),
               let semDoc = coord.activeSemanticDocument,
               isMatchingDoc,
               let w = semDoc.word(id: savedWid),
               w.pageIndex == currentPageIndex {
                wordID = savedWid
                sentenceID = progressTracker.lastSentenceID(for: document.fileURL)
            } else {
                wordID = nil
                sentenceID = nil
            }
        }
        
        progressTracker.recordProgress(
            documentURL: document.fileURL,
            title: document.title,
            currentPage: page,
            totalPages: document.pageCount,
            lastWordID: wordID,
            lastSentenceID: sentenceID
        )
    }
    
    private var readerHeader: some View {
        HStack(spacing: 14) {
            Button {
                saveCurrentProgress()
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
                                isLayoutTransitioning = true
                                accessibilityManager.pdfDisplayLayout = mode
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    isLayoutTransitioning = false
                                }
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
        // Mark initialization as complete so onChange and onReceive handlers begin processing.
        // This must happen AFTER the coordinator is synced to the restored page, so the initial
        // Combine emission from $visiblePageIndex (which delivers the current value on subscription)
        // does not overwrite currentPageIndex with a stale or wrong page.
        isDocumentInitialized = true
        
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
                        guard AppState.shared.currentDocument?.id == targetDoc.id else { return }
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
                guard AppState.shared.currentDocument?.id == targetDoc.id else { return }
                let savedRecord = progressTracker.record(for: fileURL)
                let initialSentenceID: Int?
                let initialWordID: Int?
                if let savedWordID = savedRecord?.lastWordID,
                   let word = semDoc.word(id: savedWordID),
                   word.pageIndex == currentPageIndex {
                    initialWordID = savedWordID
                    initialSentenceID = savedRecord?.lastSentenceID
                } else if let savedSentenceID = savedRecord?.lastSentenceID,
                          let sentence = semDoc.sentence(id: savedSentenceID),
                          sentence.pageSpans.contains(currentPageIndex) {
                    initialWordID = nil
                    initialSentenceID = savedSentenceID
                } else if let firstWordOnPage = semDoc.firstWord(onPageIndex: currentPageIndex) {
                    initialWordID = firstWordOnPage.globalWordID
                    initialSentenceID = firstWordOnPage.sentenceID
                } else {
                    initialWordID = nil
                    initialSentenceID = nil
                }
                
                ttsController.loadDocument(semDoc, initialSentenceID: initialSentenceID, initialWordID: initialWordID)
                extractedSentences = semDoc.sentences.map { SentenceItem(from: $0) }
            }
        }
    }
    
    private var jumpToSpokenSentencePill: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                playbackCoordinator.jumpToSpokenSentence()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: playbackCoordinator.scrolledAwayDirection == .above ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(playbackCoordinator.scrolledAwayDirection == .above ? "Spoken text is above" : "Spoken text is below")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let page = playbackCoordinator.scrolledAwayPageIndex {
                            Text("P. \(page + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white.opacity(0.9))
                                .cornerRadius(4)
                        }
                    }
                    
                    if !playbackCoordinator.scrolledAwaySnippet.isEmpty {
                        Text(playbackCoordinator.scrolledAwaySnippet)
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: 240, alignment: .leading)
                
                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Auto-Scroll")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.25))
                .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
                .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(red: 0.09, green: 0.13, blue: 0.20).opacity(0.96))
                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
