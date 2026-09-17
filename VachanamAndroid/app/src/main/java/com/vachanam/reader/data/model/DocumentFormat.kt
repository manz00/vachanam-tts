package com.vachanam.reader.data.model

import java.io.File
import java.util.Locale

enum class DocumentFormat(val displayName: String, val extensions: List<String>) {
    PDF("PDF Document", listOf("pdf")),
    EPUB("EPUB Book", listOf("epub")),
    MARKDOWN("Markdown", listOf("md", "markdown")),
    PLAIN_TEXT("Plain Text", listOf("txt", "text")),
    WEB_ARTICLE("Web Article", listOf("html", "htm", "web"));

    companion object {
        fun detect(file: File): DocumentFormat {
            val ext = file.extension.lowercase(Locale.ROOT)
            return detect(ext)
        }

        fun detect(extension: String): DocumentFormat {
            val ext = extension.lowercase(Locale.ROOT).removePrefix(".")
            for (fmt in entries) {
                if (fmt.extensions.contains(ext)) {
                    return fmt
                }
            }
            return PLAIN_TEXT
        }

        fun detectFromUrl(url: String): DocumentFormat {
            val lower = url.lowercase(Locale.ROOT)
            return when {
                lower.endsWith(".pdf") -> PDF
                lower.endsWith(".epub") -> EPUB
                lower.endsWith(".md") || lower.endsWith(".markdown") -> MARKDOWN
                lower.endsWith(".txt") -> PLAIN_TEXT
                lower.startsWith("http://") || lower.startsWith("https://") -> WEB_ARTICLE
                else -> PLAIN_TEXT
            }
        }
    }
}
