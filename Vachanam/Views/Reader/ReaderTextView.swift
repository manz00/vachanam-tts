//
//  ReaderTextView.swift
//  Vachanam
//
//  Re-rendered typography view with customizable fonts, colors, line spacing, and inline live TTS highlights.
//

import SwiftUI

public struct ReaderTextView: View {
    public let sentences: [SentenceItem]
    @ObservedObject var ttsController = TTSController.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var fontManager = FontManager.shared
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    
    public init(sentences: [SentenceItem]) {
        self.sentences = sentences
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: fontManager.fontSize * (fontManager.lineSpacingMultiplier - 1.0) * 1.5) {
                    ForEach(0..<sentences.count, id: \.self) { sIndex in
                        let sentence = sentences[sIndex]
                        let isCurrentSentence = (ttsController.currentSentenceIndex == sIndex && ttsController.isPlaying)
                        
                        SentenceFlowView(
                            sentence: sentence,
                            isCurrentSentence: isCurrentSentence,
                            currentWord: ttsController.currentWord,
                            font: fontManager.resolveFont(),
                            textColor: themeManager.effectiveTextColor,
                            highlightChoice: accessibilityManager.colorChoice,
                            highlightMode: accessibilityManager.highlightMode
                        )
                        .id(sIndex)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            (isCurrentSentence && (accessibilityManager.highlightMode == .both || accessibilityManager.highlightMode == .sentenceOnly))
                                ? accessibilityManager.colorChoice.sentenceColor
                                : Color.clear
                        )
                        .cornerRadius(6)
                    }
                }
                .padding(28)
                .frame(maxWidth: 820)
            }
            .background(themeManager.currentReaderTheme.backgroundColor)
            .onChange(of: ttsController.currentSentenceIndex) { _, newIndex in
                if accessibilityManager.isAutoScrollEnabled {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
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
        // Flowing text rendering with individual word highlighting
        Text(buildAttributedString())
            .font(font)
            .lineSpacing(8)
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
