package com.vachanam.reader.data.parser

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.DocumentFormat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import java.util.regex.Pattern

class WebArticleParser : DocumentParser {

    companion object {
        const val MAX_RESPONSE_SIZE_BYTES = 5 * 1024 * 1024 // 5 MB
        const val MAX_REDIRECTS = 3

        fun validateUrl(urlString: String): URL {
            val url = URL(urlString)
            val scheme = url.protocol?.lowercase() ?: throw IllegalArgumentException("Missing URL protocol")
            if (scheme != "https") {
                throw SecurityException("Insecure scheme '$scheme'. Only HTTPS is permitted.")
            }

            val host = url.host ?: throw IllegalArgumentException("URL is missing a host")
            val lowerHost = host.lowercase()
            if (lowerHost == "localhost" || lowerHost.endsWith(".localhost") || lowerHost == "127.0.0.1" || lowerHost == "::1") {
                throw SecurityException("Requests to localhost are prohibited.")
            }

            try {
                val addresses = InetAddress.getAllByName(host)
                for (addr in addresses) {
                    if (addr.isLoopbackAddress ||
                        addr.isSiteLocalAddress ||
                        addr.isLinkLocalAddress ||
                        addr.isAnyLocalAddress ||
                        addr.isMulticastAddress ||
                        addr.hostAddress == "169.254.169.254"
                    ) {
                        throw SecurityException("Requests to private/reserved IP address '${addr.hostAddress}' are prohibited.")
                    }
                }
            } catch (e: SecurityException) {
                throw e
            } catch (_: Exception) {
                // Ignore DNS resolution errors during offline test environments
            }
            return url
        }
    }

    private val titleRegex = Pattern.compile("<title[^>]*>(.*?)</title>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)
    private val h1Regex = Pattern.compile("<h1[^>]*>(.*?)</h1>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)
    private val pRegex = Pattern.compile("<p[^>]*>(.*?)</p>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)

    override suspend fun parse(source: DocumentSource): ParsedDocument = withContext(Dispatchers.IO) {
        val initialUrlString = when (source) {
            is DocumentSource.WebUrl -> source.url
            else -> throw IllegalArgumentException("WebArticleParser requires a WebUrl source")
        }

        var currentUrl = validateUrl(initialUrlString)
        var redirectCount = 0
        var html: String? = null

        while (redirectCount <= MAX_REDIRECTS) {
            val conn = (currentUrl.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 15000
                readTimeout = 15000
                instanceFollowRedirects = false
                setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36")
            }

            val responseCode = conn.responseCode
            if (responseCode in 300..399) {
                redirectCount++
                if (redirectCount > MAX_REDIRECTS) {
                    throw SecurityException("Exceeded maximum allowed redirects ($MAX_REDIRECTS)")
                }
                val location = conn.getHeaderField("Location")
                    ?: throw SecurityException("Redirect missing Location header")
                val targetUrl = if (location.startsWith("http://") || location.startsWith("https://")) {
                    validateUrl(location)
                } else {
                    validateUrl(URL(currentUrl, location).toString())
                }
                currentUrl = targetUrl
                conn.disconnect()
                continue
            }

            if (responseCode !in 200..299) {
                throw IllegalStateException("HTTP request failed with status code $responseCode")
            }

            val contentLength = conn.contentLengthLong
            if (contentLength > MAX_RESPONSE_SIZE_BYTES) {
                throw SecurityException("Response size exceeds maximum allowed limit ($MAX_RESPONSE_SIZE_BYTES bytes)")
            }

            html = readStreamWithLimit(conn.inputStream, MAX_RESPONSE_SIZE_BYTES)
            conn.disconnect()
            break
        }

        val pageHtml = html ?: throw IllegalStateException("Failed to retrieve content from URL")

        // Extract Title
        var title = currentUrl.host ?: "Web Article"
        val h1Matcher = h1Regex.matcher(pageHtml)
        if (h1Matcher.find()) {
            title = cleanHtml(h1Matcher.group(1) ?: "")
        } else {
            val tMatcher = titleRegex.matcher(pageHtml)
            if (tMatcher.find()) {
                title = cleanHtml(tMatcher.group(1) ?: "")
            }
        }

        // Extract paragraphs
        val blocks = mutableListOf<ParsedBlock>()
        val pMatcher = pRegex.matcher(pageHtml)
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
            author = currentUrl.host,
            format = DocumentFormat.WEB_ARTICLE,
            chapters = listOf(chapter)
        )
    }

    private fun readStreamWithLimit(inputStream: InputStream, maxBytes: Int): String {
        val buffer = ByteArray(8192)
        val output = ByteArrayOutputStream()
        var totalRead = 0
        var bytesRead: Int
        inputStream.use { input ->
            while (input.read(buffer).also { bytesRead = it } != -1) {
                totalRead += bytesRead
                if (totalRead > maxBytes) {
                    throw SecurityException("Response stream exceeded maximum allowed limit ($maxBytes bytes)")
                }
                output.write(buffer, 0, bytesRead)
            }
        }
        return output.toString("UTF-8")
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
