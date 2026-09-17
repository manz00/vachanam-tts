package com.vachanam.reader.data.parser

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.DocumentFormat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileNotFoundException
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets

class PlainTextParser : DocumentParser {

    companion object {
        fun decodeBytes(bytes: ByteArray): String {
            val encodings = listOf(
                StandardCharsets.UTF_8,
                StandardCharsets.ISO_8859_1,
                Charset.forName("windows-1252"),
                StandardCharsets.UTF_16,
                StandardCharsets.US_ASCII
            )
            for (charset in encodings) {
                try {
                    val decoded = String(bytes, charset)
                    if (decoded.isNotEmpty()) return decoded
                } catch (_: Exception) {}
            }
            return String(bytes, StandardCharsets.UTF_8)
        }
    }

    override suspend fun parse(source: DocumentSource): ParsedDocument = withContext(Dispatchers.IO) {
        val (text, defaultTitle) = when (source) {
            is DocumentSource.LocalFile -> {
                if (!source.file.exists()) throw FileNotFoundException("File not found: ${source.file.absolutePath}")
                val bytes = source.file.readBytes()
                Pair(decodeBytes(bytes), source.file.nameWithoutExtension)
            }
            is DocumentSource.RawText -> {
                Pair(source.text, source.title)
            }
            is DocumentSource.WebUrl -> {
                throw IllegalArgumentException("PlainTextParser cannot parse WebUrl directly")
            }
        }

        val normalized = text.replace("\r\n", "\n").replace("\r", "\n")
        var rawParagraphs = normalized.split("\n\n")
            .map { it.replace("\n", " ").trim() }
            .filter { it.isNotEmpty() }

        if (rawParagraphs.size <= 1 && normalized.contains("\n")) {
            val lines = normalized.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
            if (lines.size > 1) {
                rawParagraphs = lines
            }
        }

        if (rawParagraphs.isEmpty()) {
            val trimmed = normalized.trim()
            if (trimmed.isEmpty()) throw IllegalStateException("Document is empty")
            rawParagraphs = listOf(trimmed)
        }

        var title = defaultTitle
        var startIndex = 0

        // If the first paragraph is short, treat it as the document title
        val first = rawParagraphs.firstOrNull()
        if (first != null && first.length <= 80 && !first.endsWith(".")) {
            title = first
            startIndex = 1
        }

        val contentParagraphs = if (startIndex < rawParagraphs.size) {
            rawParagraphs.subList(startIndex, rawParagraphs.size)
        } else {
            rawParagraphs
        }

        val blocks = contentParagraphs.map {
            ParsedBlock(
                type = BlockType.PARAGRAPH,
                text = it
            )
        }

        val chapter = ParsedChapter(title = title, blocks = blocks)
        ParsedDocument(
            title = title,
            author = null,
            format = DocumentFormat.PLAIN_TEXT,
            chapters = listOf(chapter)
        )
    }
}
