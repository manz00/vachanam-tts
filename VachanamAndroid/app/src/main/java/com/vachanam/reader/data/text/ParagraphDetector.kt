package com.vachanam.reader.data.text

import com.vachanam.reader.data.model.BlockType
import java.util.regex.Pattern

data class DetectedBlock(
    val type: BlockType,
    val level: Int = 1,
    val marker: String? = null,
    val text: String
)

class ParagraphDetector {

    private val bulletRegex = Pattern.compile("^[\\s]*([•\\-*▪▫◦▸]|\\d+[.)]|\\([a-zA-Z0-9]+\\))\\s+(.*)$")
    private val headingPrefixRegex = Pattern.compile("^(#{1,6})\\s+(.*)$")

    fun classifyBlock(text: String, isBold: Boolean = false, fontScale: Float = 1.0f): DetectedBlock {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) {
            return DetectedBlock(BlockType.PARAGRAPH, text = "")
        }

        // 1. Markdown heading prefix (# H1, ## H2)
        val hMatcher = headingPrefixRegex.matcher(trimmed)
        if (hMatcher.matches()) {
            val hashes = hMatcher.group(1) ?: "#"
            val content = hMatcher.group(2) ?: ""
            return DetectedBlock(
                type = BlockType.HEADING,
                level = hashes.length,
                text = content
            )
        }

        // 2. Font scale or Bold heading heuristic
        if ((fontScale >= 1.25f || isBold) && trimmed.length < 120 && !trimmed.endsWith(".")) {
            val level = when {
                fontScale >= 1.6f -> 1
                fontScale >= 1.35f -> 2
                else -> 3
            }
            return DetectedBlock(
                type = BlockType.HEADING,
                level = level,
                text = trimmed
            )
        }

        // 3. Bullet or Numbered List Item
        val bMatcher = bulletRegex.matcher(trimmed)
        if (bMatcher.matches()) {
            val marker = bMatcher.group(1)
            val content = bMatcher.group(2) ?: ""
            return DetectedBlock(
                type = BlockType.LIST_ITEM,
                marker = marker,
                text = content
            )
        }

        // 4. Blockquote heuristic
        if (trimmed.startsWith(">")) {
            return DetectedBlock(
                type = BlockType.QUOTE,
                text = trimmed.removePrefix(">").trim()
            )
        }

        // Default: standard narrative paragraph
        return DetectedBlock(
            type = BlockType.PARAGRAPH,
            text = trimmed
        )
    }

    companion object {
        val shared = ParagraphDetector()
    }
}
