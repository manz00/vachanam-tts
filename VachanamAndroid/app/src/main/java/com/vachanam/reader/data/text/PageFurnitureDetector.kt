package com.vachanam.reader.data.text

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.BoundingBox

class PageFurnitureDetector {

    private val academicPublishers = listOf(
        "arxiv", "cambridge university press", "oxford university press",
        "ieee", "springer", "elsevier", "acm", "nature publishing group",
        "copyright", "all rights reserved", "downloaded from", "proceedings of"
    )

    fun isHeaderBand(box: BoundingBox, pageHeight: Float): Boolean {
        if (pageHeight <= 0f) return false
        return (box.bottom / pageHeight) <= 0.12f
    }

    fun isFooterBand(box: BoundingBox, pageHeight: Float): Boolean {
        if (pageHeight <= 0f) return false
        return (box.top / pageHeight) >= 0.88f
    }

    fun isAcademicDisclaimer(text: String): Boolean {
        val lower = text.lowercase()
        return academicPublishers.any { lower.contains(it) }
    }

    fun isPageNumber(text: String): Boolean {
        val trimmed = text.trim()
        return trimmed.matches(Regex("^(?:Page\\s+)?\\d{1,4}(?:\\s+of\\s+\\d{1,4})?$")) ||
                trimmed.matches(Regex("^[ivxlcdm]+$", RegexOption.IGNORE_CASE))
    }

    fun classifyFurniture(
        text: String,
        box: BoundingBox,
        pageHeight: Float,
        startsLowercase: Boolean = false
    ): BlockType? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null

        if (isPageNumber(trimmed)) {
            return BlockType.PAGE_NUMBER
        }

        if (isHeaderBand(box, pageHeight)) {
            return BlockType.PAGE_HEADER
        }

        if (isFooterBand(box, pageHeight)) {
            if (isAcademicDisclaimer(trimmed)) {
                return BlockType.PAGE_FOOTER
            }
            // If the line starts with lowercase and is narrative, protect from accidental footer classification
            if (startsLowercase && trimmed.length > 30) {
                return null
            }
            return BlockType.PAGE_FOOTER
        }

        return null
    }

    companion object {
        val shared = PageFurnitureDetector()
    }
}
