package com.vachanam.reader.data.parser

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.DocumentFormat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.FileNotFoundException
import java.util.regex.Pattern

class MarkdownParser : DocumentParser {

    private val atxRegex = Pattern.compile("^(#{1,6})\\s+(.+)$")
    private val bulletRegex = Pattern.compile("^[\\s]*([•\\-*▪▫◦▸]|\\d+[.)])\\s+(.+)$")
    private val quoteRegex = Pattern.compile("^[\\s]*>\\s*(.+)$")
    private val imageRegex = Pattern.compile("^!\\[(.*?)\\]\\((.*?)\\)$")

    override suspend fun parse(source: DocumentSource): ParsedDocument = withContext(Dispatchers.IO) {
        val (text, defaultTitle) = when (source) {
            is DocumentSource.LocalFile -> {
                if (!source.file.exists()) throw FileNotFoundException("File not found: ${source.file.absolutePath}")
                Pair(PlainTextParser.decodeBytes(source.file.readBytes()), source.file.nameWithoutExtension)
            }
            is DocumentSource.RawText -> Pair(source.text, source.title)
            is DocumentSource.WebUrl -> throw IllegalArgumentException("MarkdownParser cannot parse WebUrl directly")
        }

        val normalized = text.replace("\r\n", "\n").replace("\r", "\n")
        val lines = normalized.split("\n")
        val blocks = mutableListOf<ParsedBlock>()

        var inCodeBlock = false
        var codeAccumulator = StringBuilder()
        var paragraphAccumulator = StringBuilder()
        var title = defaultTitle

        fun flushParagraph() {
            if (paragraphAccumulator.isNotEmpty()) {
                val clean = cleanMarkdownFormatting(paragraphAccumulator.toString().trim())
                if (clean.isNotEmpty()) {
                    blocks.add(ParsedBlock(type = BlockType.PARAGRAPH, text = clean))
                }
                paragraphAccumulator.clear()
            }
        }

        var i = 0
        while (i < lines.size) {
            val line = lines[i]
            val trimmed = line.trim()

            // Fenced code block toggle
            if (trimmed.startsWith("```")) {
                if (inCodeBlock) {
                    val codeContent = codeAccumulator.toString().trim()
                    if (codeContent.isNotEmpty()) {
                        blocks.add(ParsedBlock(type = BlockType.PARAGRAPH, text = "Code snippet: $codeContent"))
                    }
                    codeAccumulator.clear()
                    inCodeBlock = false
                } else {
                    flushParagraph()
                    inCodeBlock = true
                }
                i++
                continue
            }

            if (inCodeBlock) {
                codeAccumulator.appendLine(line)
                i++
                continue
            }

            // Empty line breaks paragraphs
            if (trimmed.isEmpty()) {
                flushParagraph()
                i++
                continue
            }

            // Setext Heading (Next line is === or ---)
            if (i + 1 < lines.size) {
                val nextTrimmed = lines[i + 1].trim()
                if (nextTrimmed.isNotEmpty() && nextTrimmed.all { it == '=' } && nextTrimmed.length >= 3) {
                    flushParagraph()
                    val headingText = cleanMarkdownFormatting(trimmed)
                    blocks.add(ParsedBlock(type = BlockType.HEADING, text = headingText, level = 1))
                    if (title == defaultTitle) title = headingText
                    i += 2
                    continue
                }
                if (nextTrimmed.isNotEmpty() && nextTrimmed.all { it == '-' } && nextTrimmed.length >= 3) {
                    flushParagraph()
                    val headingText = cleanMarkdownFormatting(trimmed)
                    blocks.add(ParsedBlock(type = BlockType.HEADING, text = headingText, level = 2))
                    i += 2
                    continue
                }
            }

            // ATX Heading (# Heading)
            val atxMatcher = atxRegex.matcher(trimmed)
            if (atxMatcher.matches()) {
                flushParagraph()
                val hashes = atxMatcher.group(1) ?: "#"
                val hText = cleanMarkdownFormatting(atxMatcher.group(2) ?: "")
                blocks.add(ParsedBlock(type = BlockType.HEADING, text = hText, level = hashes.length))
                if (hashes.length == 1 && title == defaultTitle) {
                    title = hText
                }
                i++
                continue
            }

            // Blockquote (> Quote)
            val quoteMatcher = quoteRegex.matcher(trimmed)
            if (quoteMatcher.matches()) {
                flushParagraph()
                val qText = cleanMarkdownFormatting(quoteMatcher.group(1) ?: "")
                blocks.add(ParsedBlock(type = BlockType.QUOTE, text = qText))
                i++
                continue
            }

            // Bullet or List Item
            val bulletMatcher = bulletRegex.matcher(trimmed)
            if (bulletMatcher.matches()) {
                flushParagraph()
                val marker = bulletMatcher.group(1)
                val itemText = cleanMarkdownFormatting(bulletMatcher.group(2) ?: "")
                blocks.add(ParsedBlock(type = BlockType.LIST_ITEM, text = itemText, marker = marker))
                i++
                continue
            }

            // Image (![Alt](url))
            val imgMatcher = imageRegex.matcher(trimmed)
            if (imgMatcher.matches()) {
                flushParagraph()
                val altText = imgMatcher.group(1)?.trim() ?: ""
                val imgUrl = imgMatcher.group(2)?.trim() ?: ""
                blocks.add(ParsedBlock(type = BlockType.IMAGE, text = altText, imageUrl = imgUrl))
                i++
                continue
            }

            // Regular paragraph line
            if (paragraphAccumulator.isNotEmpty()) {
                paragraphAccumulator.append(" ")
            }
            paragraphAccumulator.append(trimmed)
            i++
        }

        flushParagraph()

        val chapter = ParsedChapter(title = title, blocks = blocks)
        ParsedDocument(
            title = title,
            author = null,
            format = DocumentFormat.MARKDOWN,
            chapters = listOf(chapter)
        )
    }

    private fun cleanMarkdownFormatting(text: String): String {
        return text
            .replace(Regex("\\*\\*(.*?)\\*\\*"), "$1") // Bold **
            .replace(Regex("__(.*?)__"), "$1")         // Bold __
            .replace(Regex("\\*(.*?)\\*"), "$1")       // Italic *
            .replace(Regex("_(.*?)_"), "$1")           // Italic _
            .replace(Regex("`{1,3}(.*?)`{1,3}"), "$1") // Inline code
            .replace(Regex("\\[(.*?)\\]\\((.*?)\\)"), "$1") // Links [text](url)
            .replace(Regex("!\\[(.*?)\\]\\((.*?)\\)"), "") // Images
            .trim()
    }
}
