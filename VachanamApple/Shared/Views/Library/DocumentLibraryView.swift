//
//  DocumentLibraryView.swift
//  Vachanam
//
//  Primary library view: browse PDFs, open via file picker, search, and manage settings.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

public enum LibrarySortOption: String, CaseIterable, Identifiable {
    case recentlyOpened = "Recent"
    case title = "Title"
    case progress = "Progress"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .recentlyOpened: return "clock"
        case .title: return "textformat.abc"
        case .progress: return "chart.bar"
        }
    }
}

public enum LibraryFormatFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case epub = "EPUB"
    case pdf = "PDF"
    case articles = "Articles"
    
    public var id: String { rawValue }
}

public struct DocumentLibraryView: View {
    @ObservedObject var progressTracker = ReadingProgressTracker.shared
    @ObservedObject var collectionManager = BookCollectionManager.shared
    @ObservedObject var preparationService = BookPreparationService.shared
    public let onSelectDocument: (ReaderDocument) -> Void
    
    @State private var isFilePickerPresented: Bool = false
    @State private var isWebArticleImportPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isModelManagerPresented: Bool = false
    @State private var searchText: String = ""
    @State private var sampleDocumentURL: URL?
    
    @State private var selectedShelfID: String = "all"
    @State private var sortOption: LibrarySortOption = .recentlyOpened
    @State private var formatFilter: LibraryFormatFilter = .all
    @State private var isCreateShelfPresented: Bool = false
    @State private var newShelfName: String = ""
    @State private var documentToDelete: ReadingRecord? = nil
    @State private var isDeleteAlertPresented: Bool = false
    
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
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Library")
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                            Text("Accessibility-first reader with on-device neural voice (PDF, EPUB, MD, Web)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            openBenchmark()
                        } label: {
                            Label("Benchmark PDF", systemImage: "sparkles")
                                .font(.headline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.amberAccent.opacity(0.20))
                                .foregroundColor(Color.amberAccent)
                                .cornerRadius(10)
                        }
                        
                        Button {
                            isWebArticleImportPresented = true
                        } label: {
                            Label("Web Article", systemImage: "globe")
                                .font(.headline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.tealAccent.opacity(0.20))
                                .foregroundColor(Color.tealAccent)
                                .cornerRadius(10)
                        }
                        
                        Button {
                            isFilePickerPresented = true
                        } label: {
                            Label("Open Document", systemImage: "plus")
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
                    
                    // Apple Books Shelves Bar
                    shelvesBar
                    
                    // Format Filter & Sort Controls
                    filterAndSortBar
                    
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
                            
                            HStack(spacing: 12) {
                                Button {
                                    openBenchmark()
                                } label: {
                                    Label("Open Benchmark PDF", systemImage: "sparkles")
                                        .font(.headline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.amberAccent)
                                        .foregroundColor(.black)
                                        .cornerRadius(8)
                                }
                                
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
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    } else {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(filteredAndSortedHistory) { record in
                                DocumentCard(
                                    title: record.title,
                                    progressFraction: record.progressFraction,
                                    progressPercent: record.progressPercentString,
                                    pageCount: record.totalPages,
                                    lastOpenedDate: record.lastOpened,
                                    format: record.format,
                                    documentPath: record.documentPath,
                                    isFavorite: collectionManager.isFavorite(path: record.documentPath),
                                    isFinished: collectionManager.isFinished(path: record.documentPath) || record.progressFraction >= 0.98,
                                    isPrepared: preparationService.isPrepared(path: record.documentPath),
                                    onSelect: {
                                        let url = resolveDocumentURL(for: record)
                                        if url.path != record.documentPath {
                                            progressTracker.updatePath(oldPath: record.documentPath, newURL: url)
                                        }
                                        if let doc = ReaderDocument(url: url) {
                                            onSelectDocument(doc)
                                        } else {
                                            let guideURL = ensureGettingStartedGuideExists()
                                            if let doc = ReaderDocument(url: guideURL) {
                                                progressTracker.recordProgress(documentURL: guideURL, title: doc.title, currentPage: 0, totalPages: doc.pageCount)
                                                onSelectDocument(doc)
                                            }
                                        }
                                    },
                                    onToggleFavorite: {
                                        collectionManager.toggleFavorite(path: record.documentPath)
                                    },
                                    onToggleFinished: {
                                        collectionManager.toggleFinished(path: record.documentPath)
                                    },
                                    onPrepare: {
                                        let url = resolveDocumentURL(for: record)
                                        Task {
                                            try? await preparationService.prepareBook(at: url)
                                        }
                                    },
                                    onDelete: {
                                        documentToDelete = record
                                        isDeleteAlertPresented = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 40)
            }
            .alert("Delete Book?", isPresented: $isDeleteAlertPresented, presenting: documentToDelete) { record in
                Button("Delete", role: .destructive) {
                    let url = resolveDocumentURL(for: record)
                    collectionManager.deleteDocument(at: url)
                }
                Button("Cancel", role: .cancel) {}
            } message: { record in
                Text("Are you sure you want to delete \"\(record.title)\"? This permanently removes the file and reading progress.")
            }
            .alert("New Shelf", isPresented: $isCreateShelfPresented) {
                TextField("Shelf Name", text: $newShelfName)
                Button("Create") {
                    if !newShelfName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let shelf = collectionManager.createShelf(name: newShelfName)
                        selectedShelfID = shelf.id
                        newShelfName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newShelfName = ""
                }
            } message: {
                Text("Enter a name for your new collection shelf.")
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
                allowedContentTypes: [
                    .pdf,
                    .epub,
                    .plainText,
                    UTType(filenameExtension: "md") ?? .plainText,
                    UTType("net.daringfireball.markdown") ?? .plainText
                ],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let isAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    let localDocURL = Self.copyToLocalDocuments(url: url)
                    if let doc = ReaderDocument(url: localDocURL) {
                        progressTracker.recordProgress(
                            documentURL: localDocURL,
                            title: doc.title,
                            currentPage: 0,
                            totalPages: doc.pageCount
                        )
                        onSelectDocument(doc)
                    }
                case .failure(let error):
                    #if DEBUG
                    print("File picker error: \(error.localizedDescription)")
                    #endif
                }
            }
            .sheet(isPresented: $isWebArticleImportPresented) {
                WebArticleImportSheet(onDocumentImported: onSelectDocument)
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
            .sheet(isPresented: $isModelManagerPresented) {
                ModelManagerView()
            }
            .onAppear {
                Self.ensureBenchmarkDocumentExists()
                ensureGettingStartedGuideExists()
                DispatchQueue.main.async {
                    reconcileHistoryPaths()
                }
            }
        }
    }
    
    private var filteredAndSortedHistory: [ReadingRecord] {
        var records = progressTracker.history
        
        // 1. Filter by shelf
        switch selectedShelfID {
        case "all":
            break
        case "reading":
            records = records.filter { $0.progressFraction > 0.0 && $0.progressFraction < 0.98 && !collectionManager.isFinished(path: $0.documentPath) }
        case "favorites":
            records = records.filter { collectionManager.isFavorite(path: $0.documentPath) }
        case "finished":
            records = records.filter { collectionManager.isFinished(path: $0.documentPath) || $0.progressFraction >= 0.98 }
        default:
            if let shelf = collectionManager.customShelves.first(where: { $0.id == selectedShelfID }) {
                records = records.filter { shelf.documentPaths.contains($0.documentPath) }
            }
        }
        
        // 2. Filter by search text
        if !searchText.isEmpty {
            records = records.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 3. Filter by format
        switch formatFilter {
        case .all:
            break
        case .epub:
            records = records.filter { $0.format == .epub }
        case .pdf:
            records = records.filter { $0.format == .pdf }
        case .articles:
            records = records.filter { $0.format == .markdown || $0.format == .webArticle || $0.format == .plainText }
        }
        
        // 4. Sort
        switch sortOption {
        case .recentlyOpened:
            records.sort { $0.lastOpened > $1.lastOpened }
        case .title:
            records.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            records.sort { $0.progressFraction > $1.progressFraction }
        }
        
        return records
    }
    
    private var shelvesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                shelfPill(id: "all", title: "All Books", icon: "square.grid.2x2", count: progressTracker.history.count)
                
                let readingCount = progressTracker.history.filter { $0.progressFraction > 0.0 && $0.progressFraction < 0.98 && !collectionManager.isFinished(path: $0.documentPath) }.count
                shelfPill(id: "reading", title: "Reading", icon: "book.circle", count: readingCount)
                
                shelfPill(id: "favorites", title: "Favorites", icon: "heart.fill", count: collectionManager.favoritePaths.count)
                
                let finishedCount = progressTracker.history.filter { collectionManager.isFinished(path: $0.documentPath) || $0.progressFraction >= 0.98 }.count
                shelfPill(id: "finished", title: "Finished", icon: "checkmark.seal.fill", count: finishedCount)
                
                ForEach(collectionManager.customShelves) { shelf in
                    shelfPill(id: shelf.id, title: shelf.name, icon: shelf.iconName, count: shelf.documentPaths.count)
                        .contextMenu {
                            Button(role: .destructive) {
                                if selectedShelfID == shelf.id {
                                    selectedShelfID = "all"
                                }
                                collectionManager.deleteShelf(id: shelf.id)
                            } label: {
                                Label("Delete Shelf", systemImage: "trash")
                            }
                        }
                }
                
                Button {
                    isCreateShelfPresented = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("New Shelf")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white.opacity(0.8))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func shelfPill(id: String, title: String, icon: String, count: Int) -> some View {
        let isSelected = selectedShelfID == id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedShelfID = id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .black : Color.amberAccent)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.black.opacity(0.2) : Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.amberAccent : Color.white.opacity(0.08))
            .foregroundColor(isSelected ? .black : .white)
            .cornerRadius(18)
        }
    }
    
    private var filterAndSortBar: some View {
        HStack(spacing: 12) {
            // Format chips
            ForEach(LibraryFormatFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        formatFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 12, weight: formatFilter == filter ? .bold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(formatFilter == filter ? Color.tealAccent.opacity(0.25) : Color.clear)
                        .foregroundColor(formatFilter == filter ? Color.tealAccent : .secondary)
                        .cornerRadius(8)
                }
            }
            
            Spacer()
            
            // Sort Menu
            Menu {
                ForEach(LibrarySortOption.allCases) { opt in
                    Button {
                        sortOption = opt
                    } label: {
                        HStack {
                            Text(opt.rawValue)
                            if sortOption == opt {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                    Text("Sort: \(sortOption.rawValue)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func resolveDocumentURL(for record: ReadingRecord) -> URL {
        let directURL = URL(fileURLWithPath: record.documentPath)
        if FileManager.default.fileExists(atPath: directURL.path) {
            return directURL
        }
        
        let filename = directURL.lastPathComponent
        
        // 1. Check in persistent Documents directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docURL = docs.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: docURL.path) {
            return docURL
        }
        
        // 2. If it's the Benchmark document, resolve via ensureBenchmarkDocumentExists
        if filename.contains("Benchmark") || record.title.contains("Benchmark") {
            return Self.ensureBenchmarkDocumentExists()
        }
        
        // 3. If it's the Getting Started guide, regenerate in Documents directory
        if filename.contains("Getting_Started") || record.title.contains("Getting_Started") || record.title.contains("Getting Started") {
            let guideURL = ensureGettingStartedGuideExists()
            return guideURL
        }
        
        return directURL
    }
    
    private func reconcileHistoryPaths() {
        for record in progressTracker.history {
            let resolved = resolveDocumentURL(for: record)
            if resolved.path != record.documentPath {
                progressTracker.updatePath(oldPath: record.documentPath, newURL: resolved)
            }
        }
    }
    
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    }
    
    @discardableResult
    public static func copyToLocalDocuments(url: URL) -> URL {
        let docs = documentsDirectory
        let dest = docs.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            #if DEBUG
            print("Failed to copy document to local documents: \(error.localizedDescription)")
            #endif
            return FileManager.default.fileExists(atPath: dest.path) ? dest : url
        }
    }
    
    @discardableResult
    private func ensureGettingStartedGuideExists() -> URL {
        let docs = Self.documentsDirectory
        let guideURL = docs.appendingPathComponent("Vachanam_Getting_Started.pdf")
        
        if FileManager.default.fileExists(atPath: guideURL.path) {
            return guideURL
        }
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try? pdfRenderer.writePDF(to: guideURL) { context in
            // Page 1: Welcome & Overview
            context.beginPage()
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 26),
                .foregroundColor: UIColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1.0)
            ]
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 17),
                .foregroundColor: UIColor(red: 0.85, green: 0.55, blue: 0.15, alpha: 1.0)
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray
            ]
            
            "Welcome to Vachanam".draw(at: CGPoint(x: 54, y: 60), withAttributes: titleAttributes)
            "Accessibility-First PDF Reading with On-Device Speech".draw(at: CGPoint(x: 54, y: 95), withAttributes: headingAttributes)
            
            let page1Body = """
            Vachanam is an accessibility-focused PDF reader designed for iPad and Mac. \
            It features on-device neural text-to-speech, synchronized word and sentence highlighting, \
            an OpenDyslexic typography mode, and complete Apple Pencil annotation tools.

            Press the Play button below to hear this text read aloud with live karaoke-style word highlighting. \
            You can adjust reading speed from 0.5x to 2.0x, switch between Original PDF and Reader View, \
            and draw or take notes with the floating toolbar.

            Key features include:
            • Word-by-word synchronized highlighting with customizable colors
            • Dyslexia reading ruler guide with adjustable height and opacity
            • Distraction-free Reader View with customizable OpenDyslexic fonts
            • Full Apple Pencil drawing, shapes, sticky notes, and text boxes
            • Privacy-first on-device speech with Kokoro and system voice profiles
            """
            page1Body.draw(in: CGRect(x: 54, y: 130, width: 504, height: 580), withAttributes: bodyAttributes)
            
            // Page 2: Navigation & Annotation Guide
            context.beginPage()
            "Annotations & Reading Modes".draw(at: CGPoint(x: 54, y: 60), withAttributes: titleAttributes)
            "Mastering Your Reading Experience".draw(at: CGPoint(x: 54, y: 95), withAttributes: headingAttributes)
            
            let page2Body = """
            You can customize every aspect of your reading experience in Vachanam.

            Using the Top Bar Controls:
            • Tap the pencil icon to toggle the Apple Pencil drawing and shapes toolbar.
            • Tap the bookmark icon to save this page for quick access.
            • Tap the grid icon to view thumbnail pages and jump anywhere in the document.
            • Tap the slider icon to customize highlight colors, font size, and themes.
            • Tap the segmented toggle to switch between PDF Layout and clean Reader View.

            Voice Profiles and Neural Models:
            • Tap the brain icon in the library to browse available on-device TTS models.
            • Use the Audio settings to manage the bundled Kokoro voice model.
            • Select distinct voice personalities such as Heart, Bella, Michael, or Emma.

            Enjoy reading with Vachanam!
            """
            page2Body.draw(in: CGRect(x: 54, y: 130, width: 504, height: 580), withAttributes: bodyAttributes)
        }
        
        return guideURL
    }
    
    @discardableResult
    public static func ensureBenchmarkDocumentExists() -> URL {
        let filename = "The_Ultimate_Multi_Discipline_TTS_Benchmark.pdf"
        let docs = documentsDirectory
        let destURL = docs.appendingPathComponent(filename)
        
        let bundleURL = Bundle.main.url(forResource: "The_Ultimate_Multi_Discipline_TTS_Benchmark", withExtension: "pdf", subdirectory: "Benchmark") ??
                        Bundle.main.url(forResource: "The_Ultimate_Multi_Discipline_TTS_Benchmark", withExtension: "pdf")
        let localRelPath = "Vachanam/Resources/Benchmark/\(filename)"
        let srcURL = bundleURL ?? (FileManager.default.fileExists(atPath: localRelPath) ? URL(fileURLWithPath: localRelPath) : nil)
        
        if let src = srcURL {
            let destAttrs = try? FileManager.default.attributesOfItem(atPath: destURL.path)
            let srcAttrs = try? FileManager.default.attributesOfItem(atPath: src.path)
            let destSize = destAttrs?[.size] as? UInt64 ?? 0
            let srcSize = srcAttrs?[.size] as? UInt64 ?? 0
            
            if !FileManager.default.fileExists(atPath: destURL.path) || destSize != srcSize {
                try? FileManager.default.removeItem(at: destURL)
                try? FileManager.default.copyItem(at: src, to: destURL)
            }
            return FileManager.default.fileExists(atPath: destURL.path) ? destURL : src
        }
        
        return destURL
    }
    
    private func openBenchmark() {
        let benchmarkURL = Self.ensureBenchmarkDocumentExists()
        if let doc = ReaderDocument(url: benchmarkURL) {
            let savedPage = progressTracker.lastPage(for: benchmarkURL)
            let savedWordID = progressTracker.lastWordID(for: benchmarkURL)
            let savedSentenceID = progressTracker.lastSentenceID(for: benchmarkURL)
            progressTracker.recordProgress(
                documentURL: benchmarkURL,
                title: doc.title,
                currentPage: savedPage,
                totalPages: doc.pageCount,
                lastWordID: savedWordID,
                lastSentenceID: savedSentenceID
            )
            onSelectDocument(doc)
        }
    }
    
    private func openBuiltinSample() {
        let guideURL = ensureGettingStartedGuideExists()
        if let doc = ReaderDocument(url: guideURL) {
            let savedPage = progressTracker.lastPage(for: guideURL)
            let savedWordID = progressTracker.lastWordID(for: guideURL)
            let savedSentenceID = progressTracker.lastSentenceID(for: guideURL)
            progressTracker.recordProgress(
                documentURL: guideURL,
                title: doc.title,
                currentPage: savedPage,
                totalPages: doc.pageCount,
                lastWordID: savedWordID,
                lastSentenceID: savedSentenceID
            )
            onSelectDocument(doc)
        }
    }
}
