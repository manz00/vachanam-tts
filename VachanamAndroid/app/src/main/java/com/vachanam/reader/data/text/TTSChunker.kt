package com.vachanam.reader.data.text

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.SemanticSentence
import com.vachanam.reader.data.model.TTSChunk

class TTSChunker(
    val minWordsPerChunk: Int = 8,
    val maxWordsPerChunk: Int = 25
) {
    fun chunkSentences(
        sentences: List<SemanticSentence>,
        startChunkID: Int = 0
    ): List<TTSChunk> {
        val chunks = mutableListOf<TTSChunk>()
        var currentChunkID = startChunkID

        var currentSentenceIDs = mutableListOf<Int>()
        var currentWordIDs = mutableListOf<Int>()
        var currentWords = mutableListOf<String>()
        var currentPageSpans = mutableSetOf<Int>()
        var primaryPage = 0
        var currentBlockType = BlockType.PARAGRAPH
        var currentBlockID: Int? = null

        fun flushChunk() {
            if (currentWordIDs.isEmpty()) return

            val chunkText = currentWords.joinToString(" ")
            val estimatedDuration = (currentWordIDs.size / 2.8).coerceAtLeast(0.5) // ~168 WPM
            val pauseDuration = when (currentBlockType) {
                BlockType.HEADING -> 0.6
                BlockType.LIST_ITEM -> 0.4
                BlockType.QUOTE -> 0.5
                else -> 0.35
            }

            val cId = currentChunkID++
            chunks.add(
                TTSChunk(
                    chunkID = cId,
                    id = cId,
                    sentenceIDs = currentSentenceIDs.toList(),
                    wordIDs = currentWordIDs.toList(),
                    primaryPageIndex = primaryPage,
                    pageSpans = currentPageSpans.toSet(),
                    text = chunkText,
                    wordCount = currentWordIDs.size,
                    estimatedDuration = estimatedDuration,
                    blockID = currentBlockID,
                    blockType = currentBlockType,
                    pauseDurationAfter = pauseDuration
                )
            )

            currentSentenceIDs.clear()
            currentWordIDs.clear()
            currentWords.clear()
            currentPageSpans.clear()
        }

        for (sentence in sentences) {
            // Heading blocks should be isolated as standalone chunks
            if (sentence.blockType == BlockType.HEADING) {
                flushChunk()
                currentSentenceIDs.add(sentence.sentenceID)
                currentWordIDs.addAll(sentence.words.map { it.globalWordID })
                currentWords.addAll(sentence.words.map { it.spokenText ?: it.text })
                currentPageSpans.addAll(sentence.pageSpans)
                primaryPage = sentence.primaryPageIndex
                currentBlockType = BlockType.HEADING
                currentBlockID = sentence.blockID
                flushChunk()
                continue
            }

            // If this sentence itself is larger than maxWordsPerChunk, split its words across chunks
            if (sentence.words.size > maxWordsPerChunk) {
                flushChunk()
                val slices = sentence.words.chunked(maxWordsPerChunk)
                for (slice in slices) {
                    primaryPage = sentence.primaryPageIndex
                    currentBlockType = sentence.blockType
                    currentBlockID = sentence.blockID
                    currentSentenceIDs.add(sentence.sentenceID)
                    currentWordIDs.addAll(slice.map { it.globalWordID })
                    currentWords.addAll(slice.map { it.spokenText ?: it.text })
                    currentPageSpans.addAll(slice.map { it.pageIndex })

                    if (currentWordIDs.size >= maxWordsPerChunk) {
                        flushChunk()
                    }
                }
                continue
            }

            // If adding this sentence exceeds max words and we already have minimum words, flush first
            if (currentWordIDs.size + sentence.words.size > maxWordsPerChunk && currentWordIDs.size >= minWordsPerChunk) {
                flushChunk()
            }

            if (currentWordIDs.isEmpty()) {
                primaryPage = sentence.primaryPageIndex
                currentBlockType = sentence.blockType
                currentBlockID = sentence.blockID
            }

            currentSentenceIDs.add(sentence.sentenceID)
            currentWordIDs.addAll(sentence.words.map { it.globalWordID })
            currentWords.addAll(sentence.words.map { it.spokenText ?: it.text })
            currentPageSpans.addAll(sentence.pageSpans)

            // If we have reached a good chunk size, flush
            if (currentWordIDs.size >= maxWordsPerChunk) {
                flushChunk()
            }
        }

        flushChunk()
        return chunks
    }

    companion object {
        val shared = TTSChunker()
    }
}
