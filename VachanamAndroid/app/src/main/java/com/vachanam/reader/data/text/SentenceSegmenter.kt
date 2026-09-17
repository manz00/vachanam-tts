package com.vachanam.reader.data.text

import com.vachanam.reader.data.model.*
import java.text.BreakIterator
import java.util.Locale

class SentenceSegmenter(
    private val normalizer: TextNormalizer = TextNormalizer.shared
) {
    fun segmentParagraph(
        text: String,
        paragraphID: Int,
        pageIndex: Int,
        blockType: BlockType,
        startSentenceID: Int,
        startGlobalWordID: Int,
        defaultBounds: BoundingBox = BoundingBox.ZERO
    ): Pair<List<SemanticSentence>, Int> {
        val sentences = mutableListOf<SemanticSentence>()
        var currentSentenceID = startSentenceID
        var currentWordID = startGlobalWordID

        val sentenceIterator = BreakIterator.getSentenceInstance(Locale.US)
        sentenceIterator.setText(text)

        var sentStart = sentenceIterator.first()
        var sentEnd = sentenceIterator.next()

        while (sentEnd != BreakIterator.DONE) {
            val rawSentence = text.substring(sentStart, sentEnd).trim()
            if (rawSentence.isNotEmpty()) {
                val words = mutableListOf<SemanticWord>()
                val wordIterator = BreakIterator.getWordInstance(Locale.US)
                wordIterator.setText(rawSentence)

                var wStart = wordIterator.first()
                var wEnd = wordIterator.next()
                var wordIdx = 0

                while (wEnd != BreakIterator.DONE) {
                    val rawWord = rawSentence.substring(wStart, wEnd)
                    val trimmedWord = rawWord.trim()

                    // Only index actual words/tokens, skip pure whitespace or standalone punctuation
                    if (trimmedWord.isNotEmpty() && trimmedWord.any { it.isLetterOrDigit() }) {
                        val normalizedSpoken = normalizer.normalizeForTTS(trimmedWord)
                        val word = SemanticWord(
                            id = currentWordID,
                            globalWordID = currentWordID,
                            text = trimmedWord,
                            originalText = trimmedWord,
                            spokenText = normalizedSpoken,
                            pageIndex = pageIndex,
                            sentenceID = currentSentenceID,
                            wordIndexInSentence = wordIdx++,
                            bounds = defaultBounds,
                            lineBounds = if (defaultBounds.isEmpty) emptyList() else listOf(defaultBounds),
                            sentenceRange = TextRange(wStart, wEnd),
                            chunkRange = TextRange(0, 0),
                            isHyphenatedBreak = false
                        )
                        words.add(word)
                        currentWordID++
                    }
                    wStart = wEnd
                    wEnd = wordIterator.next()
                }

                if (words.isNotEmpty()) {
                    sentences.add(
                        SemanticSentence(
                            id = currentSentenceID,
                            sentenceID = currentSentenceID,
                            paragraphID = paragraphID,
                            blockID = paragraphID,
                            blockType = blockType,
                            primaryPageIndex = pageIndex,
                            pageSpans = setOf(pageIndex),
                            text = rawSentence,
                            words = words,
                            lineBoundsByPage = mapOf(pageIndex to listOf(defaultBounds)),
                            boundsByPage = mapOf(pageIndex to defaultBounds)
                        )
                    )
                    currentSentenceID++
                }
            }
            sentStart = sentEnd
            sentEnd = sentenceIterator.next()
        }

        return Pair(sentences, currentWordID)
    }

    companion object {
        val shared = SentenceSegmenter()
    }
}
