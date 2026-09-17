package com.vachanam.reader.data.parser

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.DocumentFormat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.regex.Pattern

class WebArticleParser : DocumentParser {

    private val titleRegex = Pattern.compile("<title[^>]*>(.*?)</title>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)
    private val h1Regex = Pattern.compile("<h1[^>]*>(.*?)</h1>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)
    private val pRegex = Pattern.compile("<p[^>]*>(.*?)</p>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)

    override suspend fun parse(source: DocumentSource): ParsedDocument = withContext(Dispatchers.IO) {
        val urlString = when (source) {
            is DocumentSource.WebUrl -> source.url
            else -> throw IllegalArgumentException("WebArticleParser requires a WebUrl source")
        }

        val url = URL(urlString)
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 15000
            readTimeout = 15000
            setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36")
        }

        val html = BufferedReader(InputStreamReader(conn.inputStream)).use { it.readText() }

        // Extract Title
        var title = url.host ?: "Web Article"
        val h1Matcher = h1Regex.matcher(html)
        if (h1Matcher.find()) {
            title = cleanHtml(h1Matcher.group(1) ?: "")
        } else {
            val tMatcher = titleRegex.matcher(html)
            if (tMatcher.find()) {
                title = cleanHtml(tMatcher.group(1) ?: "")
            }
        }

        // Extract paragraphs
        val blocks = mutableListOf<ParsedBlock>()
        val pMatcher = pRegex.matcher(html)
        while (pMatcher.find()) {
            val pText = cleanHtml(pMatcher.group(1) ?: "")
            // Filter out navigation or trivial boilerplate snippets
            if (pText.length >= 35 && !pText.contains("cookie", ignoreCase = true)) {
                blocks.add(ParsedBlock(type = BlockType.PARAGRAPH, text = pText))
            }
        }

        if (blocks.isEmpty()) {
            throw IllegalStateException("Could not extract readable article text from URL")
        }

        val chapter = ParsedChapter(title = title, blocks = blocks)
        ParsedDocument(
            title = title,
            author = url.host,
            format = DocumentFormat.WEB_ARTICLE,
            chapters = listOf(chapter)
        )
    }

    private fun cleanHtml(html: String): String {
        return html
            .replace(Regex("(?i)<script[\\s\\S]*?</script>"), " ")
            .replace(Regex("(?i)<style[\\s\\S]*?</style>"), " ")
            .replace(Regex("<[^>]+>"), " ")
            .replace("&nbsp;", " ")
            .replace("&mdash;", "—")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")
            .replace(Regex("\\s+"), " ")
            .trim()
    }
}
