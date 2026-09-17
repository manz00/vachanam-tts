//
//  DeveloperInspectorView.swift
//  Vachanam
//
//  Comprehensive Developer & Diagnostics Inspector allowing export and inspection
//  of page layout, blocks, bounding boxes, sentence normalization, and phonemes,
//  alongside the interactive voice testing sandbox.
//

import SwiftUI
import CoreGraphics
import KokoroTTS

public struct DeveloperInspectorView: View {
    public let document: ReaderDocument?
    public let currentPageIndex: Int
    
    @Environment(\.dismiss) private var dismiss
    
    public enum InspectorTab: String, CaseIterable, Identifiable {
        case pageStructure = "Page Structure"
        case paragraphs = "Paragraphs & Lines"
        case voiceSandbox = "Voice Sandbox"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .pageStructure: return "doc.text.magnifyingglass"
            case .paragraphs: return "text.alignleft"
            case .voiceSandbox: return "waveform.badge.mic"
            }
        }
    }
    
    @State private var selectedTab: InspectorTab = .pageStructure
    @State private var sandboxText: String = ""
    @State private var pageExport: PageStructureExport? = nil
    @State private var pageJSONString: String = ""
    @State private var tempPageFileURL: URL? = nil
    @State private var isProcessing: Bool = false
    @State private var feedbackToast: String? = nil
    @State private var paragraphSearchQuery: String = ""
    @State private var showRawJSONViewer: Bool = false
    
    public init(document: ReaderDocument?, currentPageIndex: Int = 0) {
        self.document = document
        self.currentPageIndex = currentPageIndex
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Header Selector
                tabSelectorHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Color(red: 0.09, green: 0.12, blue: 0.17))
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Active Content Tab
                ZStack {
                    switch selectedTab {
                    case .pageStructure:
                        pageStructureTab
                    case .paragraphs:
                        paragraphsTab
                    case .voiceSandbox:
                        voiceSandboxTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(red: 0.06, green: 0.08, blue: 0.12).ignoresSafeArea())
            .navigationTitle("Developer Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if pageExport != nil {
                        Menu {
                            Button {
                                copyToPasteboard(pageJSONString, label: "Page JSON copied!")
                            } label: {
                                Label("Copy Page JSON", systemImage: "doc.on.doc")
                            }
                            
                            if let tempURL = tempPageFileURL {
                                ShareLink(item: tempURL) {
                                    Label("Share / Save JSON", systemImage: "square.and.arrow.up")
                                }
                            }
                            
                            Button {
                                showRawJSONViewer = true
                            } label: {
                                Label("View Raw JSON", systemImage: "curlybraces")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = feedbackToast {
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(20)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showRawJSONViewer) {
                rawJSONSheet
            }
            .task {
                loadPageStructure()
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelectorHeader: some View {
        HStack(spacing: 8) {
            ForEach(InspectorTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 13, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? Color(red: 0.18, green: 0.23, blue: 0.32)
                            : Color.white.opacity(0.04)
                    )
                    .cornerRadius(8)
                }
            }
            Spacer()
        }
    }
    
    // MARK: - Tab 1: Page Structure
    
    private var pageStructureTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let export = pageExport {
                    // Document & Page Info Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(export.documentTitle)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text("Page \(export.pageNumber) (Index \(export.pageIndex)) • \(String(format: "%.1f", export.pageWidth)) × \(String(format: "%.1f", export.pageHeight)) pt")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            if let tempURL = tempPageFileURL {
                                ShareLink(item: tempURL) {
                                    Label("Export", systemImage: "arrow.down.doc")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.amberAccent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.amberAccent.opacity(0.15))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Summary Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            metricBadge(title: "Blocks", value: "\(export.totalBlocksOnPage)", color: .blue)
                            metricBadge(title: "Sentences", value: "\(export.totalSentencesOnPage)", color: .green)
                            metricBadge(title: "Words", value: "\(export.totalWordsOnPage)", color: .purple)
                            metricBadge(title: "TTS Chunks", value: "\(export.chunks.count)", color: .orange)
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.10, green: 0.13, blue: 0.19))
                    .cornerRadius(12)
                    
                    // Quick Action Buttons
                    HStack(spacing: 12) {
                        Button {
                            copyToPasteboard(pageJSONString, label: "Page JSON copied to clipboard!")
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Page JSON")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Button {
                            showRawJSONViewer = true
                        } label: {
                            HStack {
                                Image(systemName: "curlybraces")
                                Text("View Raw JSON")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Blocks Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detected Layout Blocks (\(export.blocks.count))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        if export.blocks.isEmpty {
                            Text("No blocks detected on this page.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(export.blocks, id: \.blockID) { b in
                                blockCard(b)
                            }
                        }
                    }
                    
                    // Chunks Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Speech Chunker Chunks (\(export.chunks.count))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        if export.chunks.isEmpty {
                            Text("No chunks generated for this page.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(export.chunks, id: \.chunkID) { c in
                                chunkCard(c)
                            }
                        }
                    }
                } else if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Analyzing and serializing page structure...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text("No Document Loaded")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Open a document to inspect its page structure.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Tab 2: Paragraphs & Lines
    
    private var paragraphsTab: some View {
        VStack(spacing: 0) {
            // Search & Filter Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search sentences or words on page...", text: $paragraphSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                
                if !paragraphSearchQuery.isEmpty {
                    Button {
                        paragraphSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            ScrollView {
                LazyVStack(spacing: 14) {
                    if let export = pageExport {
                        let filteredSentences = export.sentences.filter { s in
                            paragraphSearchQuery.isEmpty ||
                            s.rawText.localizedCaseInsensitiveContains(paragraphSearchQuery) ||
                            s.normalizedSpeechText.localizedCaseInsensitiveContains(paragraphSearchQuery) ||
                            (s.phonemes?.localizedCaseInsensitiveContains(paragraphSearchQuery) ?? false)
                        }
                        
                        if filteredSentences.isEmpty {
                            VStack(spacing: 8) {
                                Text("No sentences matching '\(paragraphSearchQuery)'")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(filteredSentences, id: \.sentenceID) { sentence in
                                sentenceCard(sentence)
                            }
                        }
                    } else {
                        ProgressView()
                            .padding(.top, 40)
                    }
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - Tab 3: Voice Sandbox
    
    private var voiceSandboxTab: some View {
        VoiceTestingSandboxView(
            text: $sandboxText,
            documentTitle: document?.title ?? "Document Test"
        )
    }
    
    // MARK: - Subviews & Cards
    
    private func metricBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
    
    private func blockCard(_ b: PageStructureExport.BlockExport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Block #\(b.blockID)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(b.type)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colorForBlockType(b.type))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colorForBlockType(b.type).opacity(0.18))
                    .cornerRadius(4)
                
                if let marker = b.marker {
                    Text(marker)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(b.sentenceIDs.count) sent.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Text("Bounds: [\(b.bounds.map { String(format: "%.1f", $0) }.joined(separator: ", "))]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.13, blue: 0.18))
        .cornerRadius(8)
    }
    
    private func chunkCard(_ c: PageStructureExport.ChunkExport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Chunk #\(c.chunkID)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(c.blockType)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colorForBlockType(c.blockType))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colorForBlockType(c.blockType).opacity(0.18))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("\(c.wordCount) words • ~\(String(format: "%.1fs", c.estimatedDuration))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Text(c.normalizedSpeechText)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.13, blue: 0.18))
        .cornerRadius(8)
    }
    
    private func sentenceCard(_ s: PageStructureExport.SentenceExport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with IDs and actions
            HStack {
                Text("Sentence #\(s.sentenceID)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(s.blockType)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colorForBlockType(s.blockType))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colorForBlockType(s.blockType).opacity(0.18))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("\(s.wordCount) words")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Raw text
            VStack(alignment: .leading, spacing: 3) {
                Text("RAW TEXT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Text(s.rawText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
            
            // Normalized speech text
            if s.normalizedSpeechText != s.rawText {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NORMALIZED SPEECH")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.tealAccent)
                    Text(s.normalizedSpeechText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.tealAccent)
                }
            }
            
            // Phonemes
            if let phonemes = s.phonemes, !phonemes.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("PHONEMES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.amberAccent)
                        Spacer()
                        Text("\(phonemes.utf16.count) chars")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(phonemes)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.amberAccent)
                        .lineLimit(2)
                }
            }
            
            // Word tokens count & coordinates disclosure
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(s.words.prefix(20), id: \.wordID) { w in
                        HStack {
                            Text("#\(w.wordID)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(w.text)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                            Spacer()
                            Text("[\(w.bounds.map { String(format: "%.1f", $0) }.joined(separator: ", "))]")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    if s.words.count > 20 {
                        Text("... and \(s.words.count - 20) more words")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("Word Bounding Boxes (\(s.words.count))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Action Buttons
            HStack(spacing: 10) {
                // Copy JSON
                Button {
                    copySentenceJSON(s)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy JSON")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                
                // Share / Download JSON file
                let sentenceJSON = PageStructureExporter.exportJSONString(from: s)
                if let tempURL = PageStructureExporter.writeTemporaryJSONFile(
                    filename: "paragraph_\(s.sentenceID).json",
                    jsonString: sentenceJSON
                ) {
                    ShareLink(item: tempURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Download")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                // Send to Sandbox
                Button {
                    sandboxText = s.rawText
                    withAnimation {
                        selectedTab = .voiceSandbox
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.badge.mic")
                        Text("Test in Sandbox")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(6)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.13, blue: 0.19))
        .cornerRadius(10)
    }
    
    // MARK: - Raw JSON Viewer Sheet
    
    private var rawJSONSheet: some View {
        NavigationStack {
            ScrollView {
                Text(pageJSONString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.05, green: 0.07, blue: 0.10).ignoresSafeArea())
            .navigationTitle("Raw Page JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showRawJSONViewer = false
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyToPasteboard(pageJSONString, label: "Page JSON copied!")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers & Data Loading
    
    private func loadPageStructure() {
        guard let doc = document else { return }
        isProcessing = true
        
        Task.detached(priority: .userInitiated) {
            let export = PageStructureExporter.exportPage(pageIndex: currentPageIndex, document: doc)
            let jsonString = PageStructureExporter.exportJSONString(from: export)
            let tempURL = PageStructureExporter.writeTemporaryJSONFile(
                filename: "page_\(currentPageIndex + 1)_structure.json",
                jsonString: jsonString
            )
            
            await MainActor.run {
                self.pageExport = export
                self.pageJSONString = jsonString
                self.tempPageFileURL = tempURL
                self.isProcessing = false
            }
        }
    }
    
    private func copySentenceJSON(_ s: PageStructureExport.SentenceExport) {
        let json = PageStructureExporter.exportJSONString(from: s)
        copyToPasteboard(json, label: "Sentence #\(s.sentenceID) JSON copied!")
    }
    
    private func copyToPasteboard(_ content: String, label: String) {
        UIPasteboard.general.string = content
        withAnimation {
            feedbackToast = label
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                if feedbackToast == label {
                    feedbackToast = nil
                }
            }
        }
    }
    
    private func colorForBlockType(_ type: String) -> Color {
        switch type.lowercased() {
        case "heading": return .orange
        case "paragraph": return .blue
        case "math": return .purple
        case "table": return .green
        case "listitem": return .teal
        case "code": return .yellow
        case "header", "footer": return .gray
        default: return .cyan
        }
    }
}
