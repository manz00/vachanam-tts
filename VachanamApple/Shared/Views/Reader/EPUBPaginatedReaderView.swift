//
//  EPUBPaginatedReaderView.swift
//  Vachanam
//
//  Apple Books-inspired paginated reading view with realistic horizontal page turns,
//  top running chapter headers, bottom page indicators, and real-time TTS voice sync.
//

import SwiftUI

public struct EPUBPaginatedReaderView: View {
    public let sentences: [SentenceItem]
    @Binding public var currentPageIndex: Int
    public let pageCount: Int
    public let documentTitle: String
    public let chapterTitleForPage: ((Int) -> String?)?
    public let onToggleChrome: () -> Void
    
    @ObservedObject var ttsController = TTSController.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var fontManager = FontManager.shared
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    
    // Group sentences by pageIndex for quick O(1) page lookup
    private var pageMap: [Int: [SentenceItem]] {
        Dictionary(grouping: sentences, by: { $0.pageIndex })
    }
    
    public init(
        sentences: [SentenceItem],
        currentPageIndex: Binding<Int>,
        pageCount: Int,
        documentTitle: String,
        chapterTitleForPage: ((Int) -> String?)? = nil,
        onToggleChrome: @escaping () -> Void = {}
    ) {
        self.sentences = sentences
        self._currentPageIndex = currentPageIndex
        self.pageCount = max(pageCount, 1)
        self.documentTitle = documentTitle
        self.chapterTitleForPage = chapterTitleForPage
        self.onToggleChrome = onToggleChrome
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color conforming to active Apple Books palette
                themeManager.currentReaderTheme.backgroundColor
                    .ignoresSafeArea()
                
                TabView(selection: $currentPageIndex) {
                    ForEach(0..<pageCount, id: \.self) { pageIndex in
                        singlePageView(for: pageIndex, in: geometry.size)
                            .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        // Bidirectional TTS Audio Sync: As spoken audio progresses to next page, auto-flip!
        .onChange(of: ttsController.currentSentenceIndex) { _, newSentenceIndex in
            guard accessibilityManager.isAutoScrollEnabled else { return }
            if let activeSentence = sentences.first(where: { $0.sentenceIndex == newSentenceIndex }) {
                if activeSentence.pageIndex != currentPageIndex {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentPageIndex = activeSentence.pageIndex
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func singlePageView(for pageIndex: Int, in size: CGSize) -> some View {
        let pageSentences = pageMap[pageIndex] ?? []
        let currentChapter = chapterTitleForPage?(pageIndex) ?? documentTitle
        
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
            .padding(.horizontal, 24)
            .padding(.top, 4)
            
            // Page Text Body
            ZStack {
                // Tap gesture detector: Tap edges to turn pages, tap center to toggle chrome
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Left 18%: Tap to previous page
                        Color.clear
                            .frame(width: max(geo.size.width * 0.18, 44))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if currentPageIndex > 0 {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        currentPageIndex -= 1
                                    }
                                }
                            }
                        
                        // Center 64%: Tap to toggle chrome
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onToggleChrome()
                            }
                        
                        // Right 18%: Tap to next page
                        Color.clear
                            .frame(width: max(geo.size.width * 0.18, 44))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if currentPageIndex < pageCount - 1 {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        currentPageIndex += 1
                                    }
                                }
                            }
                    }
                }
                
                // Actual text content
                VStack(alignment: .leading, spacing: fontManager.fontSize * (fontManager.lineSpacingMultiplier - 1.0) * 1.5) {
                    if pageSentences.isEmpty {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Page \(pageIndex + 1)")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(themeManager.effectiveTextColor.opacity(0.35))
                            Spacer()
                        }
                        Spacer()
                    } else {
                        ForEach(pageSentences) { sentence in
                            let isCurrentSentence = (ttsController.currentSentenceIndex == sentence.sentenceIndex && ttsController.isPlaying)
                            
                            PaginatedSentenceFlowView(
                                sentence: sentence,
                                isCurrentSentence: isCurrentSentence,
                                currentWord: isCurrentSentence ? ttsController.currentWord : nil,
                                font: fontManager.resolveFont(),
                                textColor: themeManager.effectiveTextColor,
                                highlightChoice: accessibilityManager.colorChoice,
                                highlightMode: accessibilityManager.highlightMode
                            )
                            .id(sentence.sentenceIndex)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
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
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, max(28, (size.width - 680) / 2 > 0 ? (size.width - 680) / 2 : 28))
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Running Bottom Footer (Apple Books style)
            HStack {
                Spacer()
                Text("\(pageIndex + 1) of \(pageCount)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(themeManager.effectiveTextColor.opacity(0.40))
                Spacer()
            }
            .frame(height: 28)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentReaderTheme.backgroundColor)
    }
}

private struct PaginatedSentenceFlowView: View {
    let sentence: SentenceItem
    let isCurrentSentence: Bool
    let currentWord: WordRect?
    let font: Font
    let textColor: Color
    let highlightChoice: HighlightColorChoice
    let highlightMode: HighlightMode
    
    var body: some View {
        if isCurrentSentence && (highlightMode == .both || highlightMode == .wordOnly), currentWord != nil {
            Text(buildAttributedString())
                .font(font)
                .lineSpacing(6)
        } else {
            Text(sentence.text)
                .font(font)
                .foregroundColor(textColor)
                .lineSpacing(6)
        }
    }
    
    private func buildAttributedString() -> AttributedString {
        var attributed = AttributedString(sentence.text)
        attributed.foregroundColor = textColor
        
        if isCurrentSentence && (highlightMode == .both || highlightMode == .wordOnly),
           let activeWord = currentWord {
            if let swiftRange = Range(activeWord.sentenceRange, in: sentence.text),
               let attrRange = Range(swiftRange, in: attributed) {
                attributed[attrRange].backgroundColor = highlightChoice.wordColor
                attributed[attrRange].foregroundColor = Color.black
                attributed[attrRange].font = font.bold()
            } else if let fallbackRange = attributed.range(of: activeWord.text) {
                attributed[fallbackRange].backgroundColor = highlightChoice.wordColor
                attributed[fallbackRange].foregroundColor = Color.black
                attributed[fallbackRange].font = font.bold()
            }
        }
        
        return attributed
    }
}
