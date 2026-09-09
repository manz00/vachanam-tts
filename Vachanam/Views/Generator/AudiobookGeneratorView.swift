//
//  AudiobookGeneratorView.swift
//  Vachanam
//
//  Mac Audiobook Studio: Pre-generates complete audiobook bundles with chaptered .m4a audio,
//  microsecond word timings, and automatic iCloud Drive sync for zero-latency iPad playback.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

public struct AudiobookGeneratorView: View {
    @ObservedObject var generator = AudiobookGenerator.shared
    @ObservedObject var progressTracker = ReadingProgressTracker.shared
    @ObservedObject var ttsController = TTSController.shared
    @ObservedObject var syncManager = iCloudSyncManager.shared
    
    @State private var selectedRecord: ReadingRecord?
    @State private var loadedDocument: SemanticDocument?
    @State private var isLoadingDoc: Bool = false
    @State private var isFilePickerPresented: Bool = false
    @State private var generatedManifest: AudiobookManifest?
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerBanner
                documentSection
                synthesisParametersSection
                generationControlsSection
                
                if let manifest = generatedManifest ?? generator.lastGeneratedManifest {
                    completedSummaryCard(manifest)
                }
            }
            .padding(28)
        }
        .background(Color(red: 0.06, green: 0.09, blue: 0.14))
        .navigationTitle("Audiobook Studio")
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.pdf, .epub, .plainText, UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImporterResult(result)
        }
        .onAppear {
            setupInitialDocument()
        }
    }
    
    // MARK: - Subviews
    
    private var headerBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.amberAccent, Color.tealAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 26))
                    .foregroundColor(.black)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Mac Audiobook Studio")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Pre-generate studio-quality audiobooks on your Mac and sync seamlessly to iPad via iCloud Drive")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.top, 10)
    }
    
    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("1. Target Document")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    isFilePickerPresented = true
                } label: {
                    Label("Select Other File", systemImage: "folder")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            if let doc = loadedDocument {
                documentCard(doc)
            } else {
                historyDocumentPicker
            }
        }
        .padding(20)
        .background(Color(red: 0.10, green: 0.13, blue: 0.19))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func documentCard(_ doc: SemanticDocument) -> some View {
        let isPreGen = syncManager.hasBundle(for: syncManager.computeHash(for: doc))
        
        HStack(spacing: 16) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 36))
                .foregroundColor(Color.amberAccent)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text(documentStatsText(doc))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            if isPreGen {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color.tealAccent)
                    Text("Pre-generated")
                        .font(.caption.bold())
                        .foregroundColor(Color.tealAccent)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.tealAccent.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var historyDocumentPicker: some View {
        if progressTracker.history.isEmpty {
            Text("No documents in history. Open a document to begin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            Picker("Choose Document", selection: $selectedRecord) {
                Text("Select from reading history...").tag(ReadingRecord?.none)
                ForEach(progressTracker.history) { record in
                    Text("\(record.title) (\(record.totalPages)p)").tag(ReadingRecord?.some(record))
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedRecord) { _, record in
                if let r = record {
                    loadDocumentFromRecord(r)
                }
            }
        }
    }
    
    private var synthesisParametersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("2. Synthesis Parameters")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Engine")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(Color.tealAccent)
                        Text(ttsController.activeAdapterMetadata.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(String(format: "%.2fx", ttsController.speechSpeed))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Audio Encoding")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("AAC (.m4a, 24kHz Mono)")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.amberAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.amberAccent.opacity(0.12))
                        .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color(red: 0.10, green: 0.13, blue: 0.19))
        .cornerRadius(16)
    }
    
    private var generationControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("3. Generation & Progress")
                .font(.headline)
                .foregroundColor(.white)
            
            if generator.isGenerating {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(generator.statusMessage)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(generator.progressFraction * 100))%")
                            .font(.title3.bold())
                            .foregroundColor(Color.amberAccent)
                    }
                    
                    ProgressView(value: generator.progressFraction)
                        .tint(Color.amberAccent)
                    
                    HStack {
                        Text("Chunk \(generator.currentChunkIndex) / \(generator.totalChunks)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Button("Cancel") {
                            generator.cancel()
                        }
                        .font(.caption.bold())
                        .foregroundColor(.red)
                    }
                }
                .padding(16)
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
            } else {
                Button {
                    Task {
                        await startGeneration()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .font(.system(size: 18))
                        Text(loadedDocument == nil ? "Select a Document First" : "Generate Complete Audiobook")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(loadedDocument == nil ? Color.gray.opacity(0.4) : Color.amberAccent)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .disabled(loadedDocument == nil)
            }
        }
        .padding(20)
        .background(Color(red: 0.10, green: 0.13, blue: 0.19))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func completedSummaryCard(_ manifest: AudiobookManifest) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Audiobook Ready")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Synced to iCloud Drive: \(manifest.title)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button("Reveal in Finder") {
                    revealInFinder(documentHash: manifest.documentHash)
                }
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Divider().background(Color.white.opacity(0.15))
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatDuration(manifest.totalDuration))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Chunks")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(manifest.totalChunks) chunks")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chapters")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(manifest.chapters.count) chapters")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .background(Color(red: 0.08, green: 0.14, blue: 0.12))
        .cornerRadius(16)
    }
    
    // MARK: - Actions
    
    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                loadDocumentFromURL(url)
            } else {
                loadDocumentFromURL(url)
            }
        }
    }
    
    private func setupInitialDocument() {
        if let activeDoc = PlaybackCoordinator.shared.activeSemanticDocument {
            self.loadedDocument = activeDoc
        } else if let firstRecord = progressTracker.history.first {
            self.selectedRecord = firstRecord
            loadDocumentFromRecord(firstRecord)
        }
    }
    
    private func loadDocumentFromRecord(_ record: ReadingRecord) {
        let url = URL(fileURLWithPath: record.documentPath)
        loadDocumentFromURL(url)
    }
    
    private func loadDocumentFromURL(_ url: URL) {
        isLoadingDoc = true
        let format = DocumentFormat.detect(from: url)
        let docTitle = url.deletingPathExtension().lastPathComponent
        let docID = UUID()
        
        Task.detached(priority: .userInitiated) {
            let semDoc: SemanticDocument?
            if format == .pdf, let pdf = PDFKit.PDFDocument(url: url) {
                semDoc = await SentenceSegmenter.shared.parseDocumentAsync(pdfDocument: pdf, title: docTitle, documentID: docID)
            } else {
                do {
                    let parsed = try await DocumentParserResolver.shared.parse(source: .fileURL(url), format: format)
                    semDoc = SemanticDocumentBuilder.shared.build(from: parsed, documentID: docID)
                } catch {
                    print("Failed to load document for generator: \(error.localizedDescription)")
                    semDoc = nil
                }
            }
            
            await MainActor.run {
                self.loadedDocument = semDoc
                self.isLoadingDoc = false
                if let doc = semDoc {
                    let docHash = iCloudSyncManager.shared.computeHash(for: doc)
                    self.generatedManifest = iCloudSyncManager.shared.loadManifest(for: docHash)
                }
            }
        }
    }
    
    private func startGeneration() async {
        guard let doc = loadedDocument else { return }
        do {
            let manifest = try await generator.generateAudiobook(for: doc, overwrite: true)
            await MainActor.run {
                self.generatedManifest = manifest
            }
        } catch {
            print("Audiobook generation error: \(error.localizedDescription)")
        }
    }
    
    private func revealInFinder(documentHash: String) {
        let dir = iCloudSyncManager.shared.bundleDirectory(for: documentHash)
        #if os(iOS) || targetEnvironment(macCatalyst)
        UIApplication.shared.open(dir)
        #endif
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        return "\(minutes)m \(seconds)s"
    }
    
    private func documentStatsText(_ doc: SemanticDocument) -> String {
        let pages = doc.pageCount
        let sentences = doc.sentences.count
        let words = doc.words.count
        return "\(pages) Pages • \(sentences) Sentences • \(words) Words"
    }
}
