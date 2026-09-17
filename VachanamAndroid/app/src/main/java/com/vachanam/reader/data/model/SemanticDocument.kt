package com.vachanam.reader.data.model

import java.util.UUID
import kotlin.math.hypot

class SemanticDocument(
    val documentID: String = UUID.randomUUID().toString(),
    val title: String,
    val pageCount: Int,
    val blocks: List<SemanticBlock> = emptyList(),
    val paragraphs: List<SemanticParagraph>,
    val sentences: List<SemanticSentence>,
    val words: List<SemanticWord>,
    val chunks: List<TTSChunk>
) {
    // Fast lookup maps
    private val wordsByID: Map<Int, SemanticWord> = words.associateBy { it.globalWordID }
    private val sentencesByID: Map<Int, SemanticSentence> = sentences.associateBy { it.sentenceID }
    private val blocksByID: Map<Int, SemanticBlock> = blocks.associateBy { it.blockID }
    private val chunksByID: Map<Int, TTSChunk> = chunks.associateBy { it.chunkID }

    private val sentenceToChunkMap: Map<Int, Int> = buildMap {
        for (c in chunks) {
            for (sID in c.sentenceIDs) {
                put(sID, c.chunkID)
            }
        }
    }

    private val wordToChunkMap: Map<Int, Int> = buildMap {
        for (c in chunks) {
            for (wID in c.wordIDs) {
                put(wID, c.chunkID)
            }
        }
    }

    private val wordsByPage: Map<Int, List<SemanticWord>> = words.groupBy { it.pageIndex }
    private val blocksByPage: Map<Int, List<SemanticBlock>> = blocks.groupBy { it.pageIndex }
    private val sentencesByPage: Map<Int, List<SemanticSentence>> = buildMap {
        for (s in sentences) {
            for (p in s.pageSpans) {
                getOrPut(p) { mutableListOf() }.add(s)
            }
        }
    }

    // MARK: - Lookups
    fun block(id: Int): SemanticBlock? = blocksByID[id]
    fun blocksForPage(pageIndex: Int): List<SemanticBlock> = blocksByPage[pageIndex] ?: emptyList()

    fun word(id: Int): SemanticWord? = wordsByID[id]
    fun wordsForPage(pageIndex: Int): List<SemanticWord> = wordsByPage[pageIndex] ?: emptyList()
    fun firstWordOnPage(pageIndex: Int): SemanticWord? = wordsByPage[pageIndex]?.firstOrNull()
    fun lastWordOnPage(pageIndex: Int): SemanticWord? = wordsByPage[pageIndex]?.lastOrNull()

    fun sentence(id: Int): SemanticSentence? = sentencesByID[id]
    fun sentencesForPage(pageIndex: Int): List<SemanticSentence> = sentencesByPage[pageIndex] ?: emptyList()

    fun chunk(id: Int): TTSChunk? = chunksByID[id]
    fun chunkForSentence(sentenceID: Int): TTSChunk? {
        val cId = sentenceToChunkMap[sentenceID] ?: return null
        return chunksByID[cId]
    }
    fun chunkForWord(wordID: Int): TTSChunk? {
        val cId = wordToChunkMap[wordID] ?: return null
        return chunksByID[cId]
    }
    fun chunksForPage(pageIndex: Int): List<TTSChunk> = chunks.filter { it.pageSpans.contains(pageIndex) }

    /**
     * Spatial hit-testing: finds the word at a given (x, y) point on a specific page.
     */
    fun findWord(
        x: Float,
        y: Float,
        pageIndex: Int,
        hitPadding: Float = 16f,
        maxSearchRadius: Float = 40f
    ): SemanticWord? {
        val pageWords = wordsByPage[pageIndex] ?: return null
        if (pageWords.isEmpty()) return null

        // 1. Exact bounds match
        for (w in pageWords) {
            if (w.bounds.contains(x, y) || w.lineBounds.any { it.contains(x, y) }) {
                return w
            }
        }

        // 2. Inset padding match
        var closestWord: SemanticWord? = null
        var minDistance = Float.MAX_VALUE

        for (w in pageWords) {
            val padded = w.bounds.inset(-hitPadding, -hitPadding)
            if (padded.contains(x, y) || w.lineBounds.any { it.inset(-hitPadding, -hitPadding).contains(x, y) }) {
                val dist = hypot((x - w.bounds.midX).toDouble(), (y - w.bounds.midY).toDouble()).toFloat()
                if (dist < minDistance) {
                    minDistance = dist
                    closestWord = w
                }
            }
        }

        if (closestWord != null) return closestWord

        // 3. Fallback search radius
        for (w in pageWords) {
            val dist = hypot((x - w.bounds.midX).toDouble(), (y - w.bounds.midY).toDouble()).toFloat()
            if (dist < maxSearchRadius && dist < minDistance) {
                minDistance = dist
                closestWord = w
            }
        }

        return closestWord
    }
}
