package com.vachanam.reader.data.parser

import com.vachanam.reader.data.model.DocumentFormat
import java.io.File

class DocumentParserResolver {
    private val epubParser = EPUBParser()
    private val markdownParser = MarkdownParser()
    private val plainTextParser = PlainTextParser()
    private val webArticleParser = WebArticleParser()

    fun parserFor(format: DocumentFormat): DocumentParser {
        return when (format) {
            DocumentFormat.EPUB -> epubParser
            DocumentFormat.MARKDOWN -> markdownParser
            DocumentFormat.PLAIN_TEXT -> plainTextParser
            DocumentFormat.WEB_ARTICLE -> webArticleParser
            DocumentFormat.PDF -> plainTextParser // PDF handles its own extraction via PdfTextExtractor
        }
    }

    suspend fun parseFile(file: File): ParsedDocument {
        val format = DocumentFormat.detect(file)
        val parser = parserFor(format)
        return parser.parse(DocumentSource.LocalFile(file))
    }

    suspend fun parseUrl(url: String): ParsedDocument {
        val format = DocumentFormat.detectFromUrl(url)
        val parser = parserFor(format)
        return parser.parse(DocumentSource.WebUrl(url))
    }

    companion object {
        val shared = DocumentParserResolver()
    }
}
