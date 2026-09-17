package com.vachanam.reader.data.model

data class SemanticBlock(
    val id: Int, // Same as blockID
    val blockID: Int,
    val type: BlockType,
    val level: Int = 1,
    val marker: String? = null,
    val pageIndex: Int,
    val sentenceIDs: List<Int>,
    val bounds: BoundingBox = BoundingBox.ZERO
)

data class TextRange(
    val start: Int,
    val end: Int
) {
    val length: Int get() = (end - start).coerceAtLeast(0)
}

data class SemanticWord(
    val id: Int, // Same as globalWordID
    val globalWordID: Int,
    val text: String,
    val originalText: String = text,
    var spokenText: String? = null,
    val pageIndex: Int,
    val sentenceID: Int,
    val wordIndexInSentence: Int,
    val bounds: BoundingBox,
    val lineBounds: List<BoundingBox> = if (bounds.isEmpty) emptyList() else listOf(bounds),
    val sentenceRange: TextRange = TextRange(0, 0),
    var chunkRange: TextRange = TextRange(0, 0),
    val isHyphenatedBreak: Boolean = false
)

data class SemanticSentence(
    val id: Int, // Same as sentenceID
    val sentenceID: Int,
    val paragraphID: Int,
    val blockID: Int = paragraphID,
    val blockType: BlockType = BlockType.PARAGRAPH,
    val primaryPageIndex: Int,
    val pageSpans: Set<Int>,
    val text: String,
    val words: List<SemanticWord>,
    val lineBoundsByPage: Map<Int, List<BoundingBox>> = emptyMap(),
    val boundsByPage: Map<Int, BoundingBox> = emptyMap()
) {
    fun lineBounds(pageIndex: Int): List<BoundingBox> = lineBoundsByPage[pageIndex] ?: emptyList()
    fun bounds(pageIndex: Int): BoundingBox = boundsByPage[pageIndex] ?: BoundingBox.ZERO
}

data class SemanticParagraph(
    val id: Int, // Same as paragraphID
    val paragraphID: Int,
    val pageIndex: Int,
    val sentenceIDs: List<Int>
)

data class TTSChunk(
    val id: Int, // Same as chunkID
    val chunkID: Int,
    val sentenceIDs: List<Int>,
    val wordIDs: List<Int>,
    val primaryPageIndex: Int = 0,
    val pageSpans: Set<Int> = setOf(primaryPageIndex),
    val text: String,
    val wordCount: Int,
    val estimatedDuration: Double,
    val blockID: Int? = null,
    val blockType: BlockType = BlockType.PARAGRAPH,
    val pauseDurationAfter: Double = 0.0
)
