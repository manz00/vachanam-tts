package com.vachanam.reader.data.parser

import com.vachanam.reader.data.model.*
import com.vachanam.reader.data.text.SentenceSegmenter
import com.vachanam.reader.data.text.TTSChunker
import java.util.UUID

class SemanticDocumentBuilder(
    private val segmenter: SentenceSegmenter = SentenceSegmenter.shared,
    private val chunker: TTSChunker = TTSChunker.shared
) {
    data class BuildResult(
        val document: SemanticDocument,
        val chapterStartPages: List<Int>
    )

    fun build(
        parsed: ParsedDocument,
        documentID: String = UUID.randomUUID().toString(),
        targetWordsPerVirtualPage: Int = 100
    ): SemanticDocument {
        return buildWithMetadata(parsed, documentID, targetWordsPerVirtualPage).document
    }

    fun buildWithMetadata(
        parsed: ParsedDocument,
        documentID: String = UUID.randomUUID().toString(),
        targetWordsPerVirtualPage: Int = 100
    ): BuildResult {
        val allBlocks = mutableListOf<SemanticBlock>()
        val allParagraphs = mutableListOf<SemanticParagraph>()
        val allSentences = mutableListOf<SemanticSentence>()
        val allWords = mutableListOf<SemanticWord>()

        var nextGlobalWordID = 0
        var nextSentenceID = 0
        var nextParagraphID = 0
        var nextBlockID = 0

        var virtualPageIndex = 0
        var wordsOnCurrentVirtualPage = 0
        val chapterStartPages = mutableListOf<Int>()

        for ((chapterIndex, chapter) in parsed.chapters.withIndex()) {
            if (chapterIndex > 0 && wordsOnCurrentVirtualPage > 0) {
                virtualPageIndex += 1
                wordsOnCurrentVirtualPage = 0
            }
            chapterStartPages.add(virtualPageIndex)

            for (parsedBlock in chapter.blocks) {
                if (parsedBlock.type == BlockType.IMAGE) {
                    val currentBlockID = nextBlockID++
                    val currentParagraphID = nextParagraphID++
                    val currentSentenceID = nextSentenceID++
                    val altText = parsedBlock.text.trim().ifEmpty { "Image" }
                    val imgSentence = SemanticSentence(
                        id = currentSentenceID,
                        sentenceID = currentSentenceID,
                        paragraphID = currentParagraphID,
                        blockID = currentBlockID,
                        blockType = BlockType.IMAGE,
                        primaryPageIndex = virtualPageIndex,
                        pageSpans = setOf(virtualPageIndex),
                        text = altText,
                        words = emptyList(),
                        imageData = parsedBlock.imageData,
                        imageUrl = parsedBlock.imageUrl
                    )
                    allSentences.add(imgSentence)
                    allBlocks.add(
                        SemanticBlock(
                            id = currentBlockID,
                            blockID = currentBlockID,
                            type = BlockType.IMAGE,
                            level = parsedBlock.level,
                            marker = parsedBlock.marker,
                            pageIndex = virtualPageIndex,
                            sentenceIDs = listOf(currentSentenceID)
                        )
                    )
                    allParagraphs.add(
                        SemanticParagraph(
                            id = currentParagraphID,
                            paragraphID = currentParagraphID,
                            pageIndex = virtualPageIndex,
                            sentenceIDs = listOf(currentSentenceID)
                        )
                    )
                    continue
                }

                val blockText = parsedBlock.text.trim()
                if (blockText.isEmpty()) continue

                val currentBlockID = nextBlockID++
                val currentParagraphID = nextParagraphID++

                val (segmentedSentences, updatedWordID) = segmenter.segmentParagraph(
                    text = blockText,
                    paragraphID = currentParagraphID,
                    pageIndex = virtualPageIndex,
                    blockType = parsedBlock.type,
                    startSentenceID = nextSentenceID,
                    startGlobalWordID = nextGlobalWordID
                )

                if (segmentedSentences.isEmpty()) continue

                nextSentenceID += segmentedSentences.size
                nextGlobalWordID = updatedWordID

                val sentenceIDs = segmentedSentences.map { it.sentenceID }
                for (s in segmentedSentences) {
                    allSentences.add(s)
                    allWords.addAll(s.words)
                    wordsOnCurrentVirtualPage += s.words.size

                    if (wordsOnCurrentVirtualPage >= targetWordsPerVirtualPage) {
                        virtualPageIndex += 1
                        wordsOnCurrentVirtualPage = 0
                    }
                }

                allBlocks.add(
                    SemanticBlock(
                        id = currentBlockID,
                        blockID = currentBlockID,
                        type = parsedBlock.type,
                        level = parsedBlock.level,
                        marker = parsedBlock.marker,
                        pageIndex = virtualPageIndex,
                        sentenceIDs = sentenceIDs
                    )
                )

                allParagraphs.add(
                    SemanticParagraph(
                        id = currentParagraphID,
                        paragraphID = currentParagraphID,
                        pageIndex = virtualPageIndex,
                        sentenceIDs = sentenceIDs
                    )
                )
            }
        }

        val chunks = chunker.chunkSentences(allSentences)
        val totalPages = maxOf(1, virtualPageIndex + 1)

        val doc = SemanticDocument(
            documentID = documentID,
            title = parsed.title,
            pageCount = totalPages,
            blocks = allBlocks,
            paragraphs = allParagraphs,
            sentences = allSentences,
            words = allWords,
            chunks = chunks
        )

        return BuildResult(doc, chapterStartPages)
    }

    companion object {
        val shared = SemanticDocumentBuilder()
    }
}
