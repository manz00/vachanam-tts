package com.vachanam.reader.pdf

import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import com.vachanam.reader.data.model.*
import com.vachanam.reader.data.text.PageFurnitureDetector
import com.vachanam.reader.data.text.ParagraphDetector
import com.vachanam.reader.data.text.SentenceSegmenter
import com.vachanam.reader.data.text.TTSChunker
import com.vachanam.reader.data.text.WordReconstructor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.OutputStreamWriter
import java.util.UUID

class PdfTextExtractor(
    private val segmenter: SentenceSegmenter = SentenceSegmenter.shared,
    private val chunker: TTSChunker = TTSChunker.shared,
    private val furnitureDetector: PageFurnitureDetector = PageFurnitureDetector.shared
) {
    private class PositionAwareStripper : PDFTextStripper() {
        val extractedWords = mutableListOf<ExtractedWord>()
        private val currentWordChars = mutableListOf<TextPosition>()

        data class ExtractedWord(
            val text: String,
            val bounds: BoundingBox,
            val pageIndex: Int,
            val isHyphenated: Boolean
        )

        override fun processTextPosition(text: TextPosition) {
            val char = text.unicode
            if (char.isBlank()) {
                flushWord()
            } else {
                currentWordChars.add(text)
            }
            super.processTextPosition(text)
        }

        fun flushWord() {
            if (currentWordChars.isEmpty()) return

            val wordText = currentWordChars.joinToString("") { it.unicode }.trim()
            if (wordText.isNotEmpty()) {
                var minX = Float.MAX_VALUE
                var minY = Float.MAX_VALUE
                var maxX = Float.MIN_VALUE
                var maxY = Float.MIN_VALUE

                for (tp in currentWordChars) {
                    val x = tp.xDirAdj
                    val y = tp.yDirAdj
                    val w = tp.widthDirAdj
                    val h = tp.heightDir

                    if (x < minX) minX = x
                    if (y < minY) minY = y
                    if (x + w > maxX) maxX = x + w
                    if (y + h > maxY) maxY = y + h
                }

                val pageIdx = currentPageNo - 1
                val isHyphen = wordText.endsWith("-") || wordText.endsWith("\u2010")

                extractedWords.add(
                    ExtractedWord(
                        text = wordText,
                        bounds = BoundingBox(minX, minY, maxX, maxY),
                        pageIndex = pageIdx,
                        isHyphenated = isHyphen
                    )
                )
            }
            currentWordChars.clear()
        }
    }

    suspend fun extractSemanticDocument(
        file: File,
        documentID: String = UUID.randomUUID().toString()
    ): SemanticDocument = withContext(Dispatchers.IO) {
        val pdDoc = PDDocument.load(file)
        try {
            val pageCount = pdDoc.numberOfPages
            val stripper = PositionAwareStripper().apply {
                sortByPosition = true
                startPage = 1
                endPage = pageCount
            }

            val dummyOut = ByteArrayOutputStream()
            stripper.writeText(pdDoc, OutputStreamWriter(dummyOut))
            stripper.flushWord()

            val rawWords = stripper.extractedWords

            val allWords = mutableListOf<SemanticWord>()
            val allSentences = mutableListOf<SemanticSentence>()
            val allParagraphs = mutableListOf<SemanticParagraph>()
            val allBlocks = mutableListOf<SemanticBlock>()

            var nextGlobalWordID = 0
            var nextSentenceID = 0
            var nextParagraphID = 0
            var nextBlockID = 0

            // Group extracted words by page
            val wordsByPage = rawWords.groupBy { it.pageIndex }

            for (pIndex in 0 until pageCount) {
                val pageWords = wordsByPage[pIndex] ?: emptyList()
                if (pageWords.isEmpty()) continue

                // Group words into lines based on Y-coordinate proximity
                val lines = mutableListOf<MutableList<PositionAwareStripper.ExtractedWord>>()
                var currentLine = mutableListOf<PositionAwareStripper.ExtractedWord>()
                var currentLineY = -1f

                for (w in pageWords) {
                    if (currentLine.isEmpty()) {
                        currentLine.add(w)
                        currentLineY = w.bounds.midY
                    } else {
                        if (Math.abs(w.bounds.midY - currentLineY) < (w.bounds.height * 0.7f).coerceAtLeast(8f)) {
                            currentLine.add(w)
                        } else {
                            lines.add(currentLine)
                            currentLine = mutableListOf(w)
                            currentLineY = w.bounds.midY
                        }
                    }
                }
                if (currentLine.isNotEmpty()) {
                    lines.add(currentLine)
                }

                // Filter out running headers and footers using PageFurnitureDetector
                val page = pdDoc.getPage(pIndex)
                val pageH = page.mediaBox.height

                val bodyLines = lines.filter { line ->
                    val lineText = line.joinToString(" ") { it.text }
                    val lineBox = BoundingBox(
                        left = line.minOf { it.bounds.left },
                        top = line.minOf { it.bounds.top },
                        right = line.maxOf { it.bounds.right },
                        bottom = line.maxOf { it.bounds.bottom }
                    )
                    furnitureDetector.classifyFurniture(lineText, lineBox, pageH) == null
                }

                // Reconstruct words across line breaks (hyphenation joining)
                val pageSentencesText = StringBuilder()
                val pageWordBoundingMap = mutableListOf<Pair<String, BoundingBox>>()

                for (lineIdx in bodyLines.indices) {
                    val line = bodyLines[lineIdx]
                    for (wordIdx in line.indices) {
                        val word = line[wordIdx]

                        if (word.isHyphenated && wordIdx == line.size - 1 && lineIdx < bodyLines.size - 1) {
                            val nextLineFirst = bodyLines[lineIdx + 1].firstOrNull()
                            if (nextLineFirst != null) {
                                val resolved = WordReconstructor.shared.resolveHyphenation(word.text, nextLineFirst.text)
                                pageSentencesText.append(resolved.reconstructedWord).append(" ")
                                pageWordBoundingMap.add(Pair(resolved.reconstructedWord, word.bounds))
                                continue
                            }
                        }

                        pageSentencesText.append(word.text).append(" ")
                        pageWordBoundingMap.add(Pair(word.text, word.bounds))
                    }
                    pageSentencesText.append("\n")
                }

                val fullPageText = pageSentencesText.toString().trim()
                if (fullPageText.isEmpty()) continue

                val currentBlockID = nextBlockID++
                val currentParagraphID = nextParagraphID++

                val (segmentedSentences, updatedWordID) = segmenter.segmentParagraph(
                    text = fullPageText,
                    paragraphID = currentParagraphID,
                    pageIndex = pIndex,
                    blockType = BlockType.PARAGRAPH,
                    startSentenceID = nextSentenceID,
                    startGlobalWordID = nextGlobalWordID,
                    defaultBounds = BoundingBox(36f, 36f, page.mediaBox.width - 36f, page.mediaBox.height - 36f)
                )

                nextSentenceID += segmentedSentences.size
                nextGlobalWordID = updatedWordID

                // Align extracted spatial bounding boxes to words
                var mapIndex = 0
                val adjustedSentences = segmentedSentences.map { sentence ->
                    val adjustedWords = sentence.words.map { semWord ->
                        val matchedBox = if (mapIndex < pageWordBoundingMap.size) {
                            pageWordBoundingMap[mapIndex++].second
                        } else {
                            semWord.bounds
                        }
                        semWord.copy(
                            bounds = matchedBox,
                            lineBounds = listOf(matchedBox)
                        )
                    }
                    val sentBox = BoundingBox(
                        left = adjustedWords.minOfOrNull { it.bounds.left } ?: 0f,
                        top = adjustedWords.minOfOrNull { it.bounds.top } ?: 0f,
                        right = adjustedWords.maxOfOrNull { it.bounds.right } ?: 0f,
                        bottom = adjustedWords.maxOfOrNull { it.bounds.bottom } ?: 0f
                    )
                    sentence.copy(
                        words = adjustedWords,
                        boundsByPage = mapOf(pIndex to sentBox),
                        lineBoundsByPage = mapOf(pIndex to listOf(sentBox))
                    )
                }

                val sentenceIDs = adjustedSentences.map { it.sentenceID }
                allSentences.addAll(adjustedSentences)
                for (s in adjustedSentences) {
                    allWords.addAll(s.words)
                }

                allBlocks.add(
                    SemanticBlock(
                        id = currentBlockID,
                        blockID = currentBlockID,
                        type = BlockType.PARAGRAPH,
                        pageIndex = pIndex,
                        sentenceIDs = sentenceIDs
                    )
                )

                allParagraphs.add(
                    SemanticParagraph(
                        id = currentParagraphID,
                        paragraphID = currentParagraphID,
                        pageIndex = pIndex,
                        sentenceIDs = sentenceIDs
                    )
                )
            }

            val chunks = chunker.chunkSentences(allSentences)

            SemanticDocument(
                documentID = documentID,
                title = file.nameWithoutExtension,
                pageCount = maxOf(1, pageCount),
                blocks = allBlocks,
                paragraphs = allParagraphs,
                sentences = allSentences,
                words = allWords,
                chunks = chunks
            )
        } finally {
            pdDoc.close()
        }
    }

    companion object {
        val shared = PdfTextExtractor()
    }
}
