package com.vachanam.reader.ui.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.accessibility.AccessibilityManager
import com.vachanam.reader.accessibility.FontManager
import com.vachanam.reader.accessibility.ThemeManager
import com.vachanam.reader.data.model.SemanticDocument
import com.vachanam.reader.data.model.SemanticSentence
import com.vachanam.reader.tts.PlaybackCoordinator
import com.vachanam.reader.ui.theme.HighlightYellow
import com.vachanam.reader.ui.theme.SpokenWordRed

@Composable
fun ReaderTextView(
    document: SemanticDocument,
    pageIndex: Int,
    coordinator: PlaybackCoordinator,
    themeManager: ThemeManager,
    fontManager: FontManager,
    accessibilityManager: AccessibilityManager,
    modifier: Modifier = Modifier
) {
    val theme by themeManager.currentReaderTheme.collectAsState()
    val font by fontManager.selectedFont.collectAsState()
    val fontSize by fontManager.fontSize.collectAsState()
    val lineSpacing by fontManager.lineSpacingMultiplier.collectAsState()
    val charSpacing by fontManager.characterSpacing.collectAsState()
    val isBold by fontManager.isBoldTextEnabled.collectAsState()
    val isBionic by accessibilityManager.isBionicReadingEnabled.collectAsState()

    val currentWordID by coordinator.currentWordID.collectAsState()
    val currentSentenceID by coordinator.currentSentenceID.collectAsState()

    val sentences = remember(document, pageIndex) {
        document.sentencesForPage(pageIndex)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(theme.backgroundColor)
            .padding(horizontal = 24.dp, vertical = 16.dp)
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy((fontSize * (lineSpacing - 1.0f)).coerceAtLeast(8f).dp)
        ) {
            items(sentences, key = { it.sentenceID }) { sentence ->
                val isSpeakingSentence = sentence.sentenceID == currentSentenceID

                val annotatedText = remember(sentence, isSpeakingSentence, currentWordID, isBionic, isBold, theme) {
                    buildSentenceAnnotatedString(
                        sentence = sentence,
                        isSpeakingSentence = isSpeakingSentence,
                        currentWordID = currentWordID,
                        isBionic = isBionic,
                        isBold = isBold,
                        textColor = theme.textColor
                    )
                }

                Text(
                    text = annotatedText,
                    fontFamily = font.toFontFamily(),
                    fontSize = fontSize.sp,
                    lineHeight = (fontSize * lineSpacing).sp,
                    letterSpacing = charSpacing.sp,
                    color = theme.textColor,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            val firstWord = sentence.words.firstOrNull()
                            if (firstWord != null) {
                                coordinator.seekToWord(firstWord.globalWordID)
                            }
                        }
                )
            }
        }
    }
}

private fun buildSentenceAnnotatedString(
    sentence: SemanticSentence,
    isSpeakingSentence: Boolean,
    currentWordID: Int?,
    isBionic: Boolean,
    isBold: Boolean,
    textColor: androidx.compose.ui.graphics.Color
): AnnotatedString {
    return buildAnnotatedString {
        // If speaking sentence, apply soft yellow background band
        if (isSpeakingSentence) {
            pushStyle(SpanStyle(background = HighlightYellow))
        }

        for ((index, word) in sentence.words.withIndex()) {
            val isSpokenWord = word.globalWordID == currentWordID

            if (isSpokenWord) {
                // Word-level karaoke highlighting: vibrant red word styling
                withStyle(
                    SpanStyle(
                        color = SpokenWordRed,
                        fontWeight = FontWeight.ExtraBold,
                        background = SpokenWordRed.copy(alpha = 0.20f)
                    )
                ) {
                    append(word.text)
                }
            } else if (isBionic) {
                // Bionic Reading Mode: bold the first 40-50% characters of the word
                val w = word.text
                val boldLen = when {
                    w.length <= 3 -> 1
                    w.length <= 5 -> 2
                    else -> (w.length * 0.45).toInt().coerceAtLeast(2)
                }
                val boldPart = w.take(boldLen)
                val restPart = w.drop(boldLen)

                withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = textColor)) {
                    append(boldPart)
                }
                withStyle(SpanStyle(fontWeight = if (isBold) FontWeight.SemiBold else FontWeight.Normal, color = textColor)) {
                    append(restPart)
                }
            } else {
                // Normal word rendering
                withStyle(SpanStyle(fontWeight = if (isBold) FontWeight.Bold else FontWeight.Normal, color = textColor)) {
                    append(word.text)
                }
            }

            if (index < sentence.words.size - 1) {
                append(" ")
            }
        }

        if (isSpeakingSentence) {
            pop()
        }
    }
}
