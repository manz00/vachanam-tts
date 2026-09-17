package com.vachanam.reader.data.parser

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.DocumentFormat
import java.io.File
import java.util.UUID

sealed class DocumentSource {
    data class LocalFile(val file: File) : DocumentSource()
    data class WebUrl(val url: String) : DocumentSource()
    data class RawText(val text: String, val title: String) : DocumentSource()
}

data class ParsedBlock(
    val id: String = UUID.randomUUID().toString(),
    val type: BlockType,
    val text: String,
    val level: Int = 1,
    val marker: String? = null
)

data class ParsedChapter(
    val id: String = UUID.randomUUID().toString(),
    val title: String? = null,
    val blocks: List<ParsedBlock>
)

data class ParsedDocument(
    val title: String,
    val author: String? = null,
    val format: DocumentFormat,
    val chapters: List<ParsedChapter>
) {
    val allBlocks: List<ParsedBlock> get() = chapters.flatMap { it.blocks }
}

interface DocumentParser {
    suspend fun parse(source: DocumentSource): ParsedDocument
}
