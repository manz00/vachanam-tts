//
//  PaginatedReaderView.swift
//  Vachanam
//
//  Universal paginated reading view supporting both Single Page and Two-Page Book Spread
//  layouts with realistic page flipping, top running chapter headers, bottom page footers,
//  center spine divider, edge-tap navigation, and real-time TTS karaoke voice synchronization.
//

import SwiftUI

public struct PaginatedReaderView: View {
    public let sentences: [SentenceItem]
    @Binding public var currentPageIndex: Int
    public let pageCount: Int
    public let documentTitle: String
    public let isChromeVisible: Bool
    public let chapterTitleForPage: ((Int) -> String?)?
    public let onToggleChrome: () -> Void
    
    @ObservedObject var ttsController = TTSController.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var fontManager = FontManager.shared
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    
    // Group sentences by pageIndex for fast O(1) page lookups
    private var pageMap: [Int: [SentenceItem]] {
        Dictionary(grouping: sentences, by: { $0.pageIndex })
    }
    
    private var isTwoPage: Bool {
        themeManager.readingLayout.isTwoPage
    }
    
    private var spreadCount: Int {
        isTwoPage ? max((pageCount + 1) / 2, 1) : max(pageCount, 1)
    }
    
    public init(
        sentences: [SentenceItem],
        currentPageIndex: Binding<Int>,
        pageCount: Int,
        documentTitle: String,
        isChromeVisible: Bool = false,
        chapterTitleForPage: ((Int) -> String?)? = nil,
        onToggleChrome: @escaping () -> Void = {}
    ) {
        self.sentences = sentences
        self._currentPageIndex = currentPageIndex
        self.pageCount = max(pageCount, 1)
        self.documentTitle = documentTitle
        self.isChromeVisible = isChromeVisible
        self.chapterTitleForPage = chapterTitleForPage
        self.onToggleChrome = onToggleChrome
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color conforming to active Apple Books palette
                themeManager.currentReaderTheme.backgroundColor
                    .ignoresSafeArea()
                
                if isTwoPage {
                    twoPageSpreadView(in: geometry.size)
                } else {
                    singlePageTabView(in: geometry.size)
                }
            }
        }
        // Bidirectional TTS Audio Sync: As spoken audio progresses to next page/spread, auto-flip!
        .onChange(of: ttsController.currentSentenceIndex) { _, newSentenceIndex in
            guard accessibilityManager.isAutoScrollEnabled else { return }
            if let activeSentence = sentences.first(where: { $0.sentenceIndex == newSentenceIndex }) {
                if isTwoPage {
                    let activeSpread = activeSentence.pageIndex / 2
                    let currentSpread = currentPageIndex / 2
                    if activeSpread != currentSpread {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPageIndex = activeSpread * 2
                        }
                    }
                } else {
                    if activeSentence.pageIndex != currentPageIndex {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPageIndex = activeSentence.pageIndex
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Single Page Tab View
    
    @ViewBuilder
    private func singlePageTabView(in size: CGSize) -> some View {
        TabView(selection: $currentPageIndex) {
            ForEach(0..<pageCount, id: \.self) { pageIndex in
                singlePageColumn(for: pageIndex, in: size)
                    .tag(pageIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    
    // MARK: - Two-Page Spread View
    
    @ViewBuilder
    private func twoPageSpreadView(in size: CGSize) -> some View {
        let spreadBinding = Binding<Int>(
            get: { currentPageIndex / 2 },
            set: { newSpread in
                currentPageIndex = min(newSpread * 2, pageCount - 1)
            }
        )
        
        let spineWidth: CGFloat = 14
        let pageWidth: CGFloat = max((size.width - spineWidth) / 2, 0)
        
        TabView(selection: spreadBinding) {
            ForEach(0..<spreadCount, id: \.self) { spreadIndex in
                let leftPageIndex = spreadIndex * 2
                let rightPageIndex = leftPageIndex + 1
                
                HStack(spacing: 0) {
                    // Left Page
                    singlePageColumn(for: leftPageIndex, in: CGSize(width: pageWidth, height: size.height))
                        .frame(width: pageWidth)
                    
                    // Center Book Spine Divider with subtle realistic depth shading
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.effectiveTextColor.opacity(0.07),
                                        themeManager.effectiveTextColor.opacity(0.01),
                                        themeManager.effectiveTextColor.opacity(0.07)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: spineWidth)
                        Rectangle()
                            .fill(themeManager.effectiveTextColor.opacity(0.12))
                            .frame(width: 1)
                    }
                    .padding(.vertical, 24)
                    
                    // Right Page (if exists)
                    if rightPageIndex < pageCount {
                        singlePageColumn(for: rightPageIndex, in: CGSize(width: pageWidth, height: size.height))
                            .frame(width: pageWidth)
                    } else {
                        // Blank ending page for odd-count documents
                        Color.clear
                            .frame(width: pageWidth)
                    }
                }
                .tag(spreadIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    
    // MARK: - Single Page Column Component
    
    @ViewBuilder
    private func singlePageColumn(for pageIndex: Int, in size: CGSize) -> some View {
        let pageSentences = pageMap[pageIndex] ?? []
        let currentChapter = chapterTitleForPage?(pageIndex) ?? documentTitle
        let isLeftPage = (pageIndex % 2 == 0)
        let effectiveFontSize = isTwoPage ? max(fontManager.fontSize * 0.80, 13) : fontManager.fontSize
        let effectiveFont = fontManager.resolveFont(size: effectiveFontSize)
        let effectiveLineSpacing: CGFloat = isTwoPage ? 3 : 6
        let sentenceSpacing: CGFloat = isTwoPage ? 3 : fontManager.fontSize * (fontManager.lineSpacingMultiplier - 1.0) * 1.5
        
        VStack(spacing: 0) {
            // Running Top Header (Apple Books style)
            HStack {
                Spacer()
                Text(currentChapter)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(themeManager.effectiveTextColor.opacity(0.40))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, isTwoPage ? (isLeftPage ? 20 : 12) : 28)
            .padding(.top, 4)
            
            // Page Text Body
            ZStack {
                // Tap gesture detector: Tap edges to turn pages/spreads, tap center to toggle chrome
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Left Edge: Previous
                        Color.clear
                            .frame(width: geo.size.width * 0.20)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                flipBackward()
                            }
                        
                        // Center: Toggle Chrome
                        Color.clear
                            .frame(width: geo.size.width * 0.60)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onToggleChrome()
                            }
                        
                        // Right Edge: Next
                        Color.clear
                            .frame(width: geo.size.width * 0.20)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                flipForward()
                            }
                    }
                }
                
                // Formatted Sentences Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(
                        alignment: .leading,
                        spacing: sentenceSpacing
                    ) {
                        if pageSentences.isEmpty {
                            VStack(spacing: 8) {
                                Spacer().frame(height: 60)
                                Image(systemName: "text.book.closed")
                                    .font(.system(size: 28))
                                    .foregroundColor(themeManager.effectiveTextColor.opacity(0.3))
                                Text("No text on this page")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(themeManager.effectiveTextColor.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(pageSentences) { sentence in
                                let isCurrentSentence = (ttsController.currentSentenceIndex == sentence.sentenceIndex && ttsController.isPlaying)
                                
                                SentenceFlowView(
                                    sentence: sentence,
                                    isCurrentSentence: isCurrentSentence,
                                    currentWord: isCurrentSentence ? ttsController.currentWord : nil,
                                    font: effectiveFont,
                                    textColor: themeManager.effectiveTextColor,
                                    highlightChoice: accessibilityManager.colorChoice,
                                    highlightMode: accessibilityManager.highlightMode,
                                    lineSpacing: effectiveLineSpacing
                                )
                                .id(sentence.sentenceIndex)
                                .padding(.vertical, isTwoPage ? 1 : 3)
                                .padding(.horizontal, 2)
                                .background(
                                    (isCurrentSentence && (accessibilityManager.highlightMode == .both || accessibilityManager.highlightMode == .sentenceOnly))
                                        ? accessibilityManager.colorChoice.sentenceColor
                                        : Color.clear
                                )
                                .cornerRadius(6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    ttsController.jumpTo(sentenceID: sentence.sentenceIndex)
                                    if !ttsController.isPlaying {
                                        ttsController.play()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.leading, isTwoPage ? (isLeftPage ? 20 : 12) : 28)
                    .padding(.trailing, isTwoPage ? (isLeftPage ? 12 : 20) : 28)
                    .padding(.top, isTwoPage ? 8 : 14)
                    .padding(.bottom, isChromeVisible ? 80 : (isTwoPage ? 12 : 14))
                    .frame(maxWidth: isTwoPage ? 540 : 720)
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Bottom Footer (Page indicator in Apple Books typography)
            HStack {
                Spacer()
                Text("\(pageIndex + 1) of \(pageCount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.effectiveTextColor.opacity(0.45))
                Spacer()
            }
            .frame(height: 28)
            .padding(.bottom, isChromeVisible ? 70 : 6)
        }
    }
    
    // MARK: - Navigation Helpers
    
    private func flipBackward() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if isTwoPage {
                let currentSpread = currentPageIndex / 2
                currentPageIndex = max((currentSpread - 1) * 2, 0)
            } else {
                currentPageIndex = max(currentPageIndex - 1, 0)
            }
        }
    }
    
    private func flipForward() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if isTwoPage {
                let currentSpread = currentPageIndex / 2
                let nextSpread = currentSpread + 1
                if nextSpread * 2 < pageCount {
                    currentPageIndex = nextSpread * 2
                }
            } else {
                currentPageIndex = min(currentPageIndex + 1, pageCount - 1)
            }
        }
    }
}
