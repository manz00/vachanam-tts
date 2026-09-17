//
//  ReaderTextView.swift
//  Vachanam
//
//  Re-rendered typography view with customizable fonts, colors, line spacing, and inline live TTS highlights.
//

import SwiftUI

public struct ReaderTextView: View {
    public let sentences: [SentenceItem]
    @Binding public var currentPageIndex: Int
    public let pageCount: Int
    
    @ObservedObject var ttsController = TTSController.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var fontManager = FontManager.shared
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    
    private let firstSentenceIDsOnPages: Set<Int>
    
    public init(
        sentences: [SentenceItem],
        currentPageIndex: Binding<Int> = .constant(0),
        pageCount: Int = 1
    ) {
        self.sentences = sentences
        self._currentPageIndex = currentPageIndex
        self.pageCount = pageCount
        
        var seenPages = Set<Int>()
        var firstIDs = Set<Int>()
        for s in sentences {
            if !seenPages.contains(s.pageIndex) {
                seenPages.insert(s.pageIndex)
                if s.pageIndex > 0 {
                    firstIDs.insert(s.sentenceIndex)
                }
            }
        }
        self.firstSentenceIDsOnPages = firstIDs
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: fontManager.fontSize * (fontManager.lineSpacingMultiplier - 1.0) * 1.5) {
                    ForEach(sentences) { sentence in
                        VStack(alignment: .leading, spacing: 12) {
                            if firstSentenceIDsOnPages.contains(sentence.sentenceIndex) {
                                HStack(spacing: 12) {
                                    Rectangle()
                                        .fill(themeManager.effectiveTextColor.opacity(0.12))
                                        .frame(height: 1)
                                    Text("Page \(sentence.pageIndex + 1)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(themeManager.effectiveTextColor.opacity(0.45))
                                    Rectangle()
                                        .fill(themeManager.effectiveTextColor.opacity(0.12))
                                        .frame(height: 1)
                                }
                                .padding(.vertical, 16)
                            }
                            
                            let isCurrentSentence = (ttsController.currentSentenceIndex == sentence.sentenceIndex && ttsController.isPlaying)
                            
                            SentenceFlowView(
                                sentence: sentence,
                                isCurrentSentence: isCurrentSentence,
                                currentWord: isCurrentSentence ? ttsController.currentWord : nil,
                                font: fontManager.resolveFont(),
                                textColor: themeManager.effectiveTextColor,
                                highlightChoice: accessibilityManager.colorChoice,
                                highlightMode: accessibilityManager.highlightMode
                            )
                            .id(sentence.sentenceIndex)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
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
                            .onAppear {
                                if !ttsController.isPlaying && currentPageIndex != sentence.pageIndex {
                                    currentPageIndex = sentence.pageIndex
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(themeManager.currentReaderTheme.backgroundColor)
            .onChange(of: ttsController.currentSentenceIndex) { _, newIndex in
                if let active = sentences.first(where: { $0.sentenceIndex == newIndex }) {
                    if active.pageIndex != currentPageIndex {
                        currentPageIndex = active.pageIndex
                    }
                }
                
                if accessibilityManager.isAutoScrollEnabled {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .onChange(of: currentPageIndex) { _, newPage in
                // When scrubber or TOC updates page index, jump to the first sentence of that page
                if let targetSentence = sentences.first(where: { $0.pageIndex == newPage }) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(targetSentence.sentenceIndex, anchor: .top)
                    }
                }
            }
        }
    }
}

private struct SentenceFlowView: View {
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
                .lineSpacing(8)
        } else {
            Text(sentence.text)
                .font(font)
                .foregroundColor(textColor)
                .lineSpacing(8)
        }
    }
    
    private func buildAttributedString() -> AttributedString {
        var attributed = AttributedString(sentence.text)
        attributed.foregroundColor = textColor
        
        if isCurrentSentence && (highlightMode == .both || highlightMode == .wordOnly),
           let activeWord = currentWord {
            // Highlight exact instance of active word using 0-based sentenceRange
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
