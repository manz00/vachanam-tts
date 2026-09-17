package com.vachanam.reader.data.parser

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.DocumentFormat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileNotFoundException
import java.util.regex.Pattern
import java.util.zip.ZipFile

class EPUBParser : DocumentParser {

    private val itemTagRegex = Pattern.compile("<item\\s+([^>]+)>", Pattern.CASE_INSENSITIVE)
    private val itemRefTagRegex = Pattern.compile("<itemref\\s+([^>]+)>", Pattern.CASE_INSENSITIVE)
    private val titleRegex = Pattern.compile("<dc:title[^>]*>(.*?)</dc:title>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)
    private val creatorRegex = Pattern.compile("<dc:creator[^>]*>(.*?)</dc:creator>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)
    private val rootfileRegex = Pattern.compile("<rootfile\\s+[^>]*full-path=[\"']([^\"']+)[\"']", Pattern.CASE_INSENSITIVE)

    override suspend fun parse(source: DocumentSource): ParsedDocument = withContext(Dispatchers.IO) {
        val file = when (source) {
            is DocumentSource.LocalFile -> source.file
            else -> throw IllegalArgumentException("EPUBParser requires a local file source")
        }

        if (!file.exists()) throw FileNotFoundException("EPUB file not found: ${file.absolutePath}")

        val zip = ZipFile(file)
        try {
            // 1. Locate container.xml
            val containerEntry = zip.getEntry("META-INF/container.xml")
                ?: throw IllegalStateException("Invalid EPUB: META-INF/container.xml missing")
            val containerXml = zip.getInputStream(containerEntry).bufferedReader().use { it.readText() }

            val rootMatcher = rootfileRegex.matcher(containerXml)
            if (!rootMatcher.find()) {
                throw IllegalStateException("Invalid EPUB: full-path not found in container.xml")
            }
            val opfPath = rootMatcher.group(1) ?: "content.opf"
            val opfEntry = zip.getEntry(opfPath)
                ?: throw IllegalStateException("Invalid EPUB: OPF package not found at $opfPath")
            val opfXml = zip.getInputStream(opfEntry).bufferedReader().use { it.readText() }

            // 2. Parse OPF Metadata
            val titleMatch = titleRegex.matcher(opfXml)
            val bookTitle = if (titleMatch.find()) cleanHtml(titleMatch.group(1) ?: "") else file.nameWithoutExtension
            val creatorMatch = creatorRegex.matcher(opfXml)
            val author = if (creatorMatch.find()) cleanHtml(creatorMatch.group(1) ?: "") else null

            // 3. Parse OPF Manifest
            val opfDir = File(opfPath).parent?.replace("\\", "/") ?: ""
            val manifest = mutableMapOf<String, String>() // id -> relative path
            val itemMatcher = itemTagRegex.matcher(opfXml)
            while (itemMatcher.find()) {
                val attrs = itemMatcher.group(1) ?: ""
                val id = getAttribute(attrs, "id")
                val href = getAttribute(attrs, "href")
                if (id != null && href != null) {
                    val fullHref = if (opfDir.isNotEmpty()) "$opfDir/$href" else href
                    manifest[id] = normalizePath(fullHref)
                }
            }

            // 4. Parse Spine
            val spineIds = mutableListOf<String>()
            val itemRefMatcher = itemRefTagRegex.matcher(opfXml)
            while (itemRefMatcher.find()) {
                val attrs = itemRefMatcher.group(1) ?: ""
                val idref = getAttribute(attrs, "idref")
                if (idref != null) {
                    spineIds.add(idref)
                }
            }

            // 5. Read chapters in spine order
            val chapters = mutableListOf<ParsedChapter>()
            var chapterIndex = 1

            val targetHrefs = if (spineIds.isNotEmpty()) {
                spineIds.mapNotNull { manifest[it] }
            } else {
                manifest.values.filter { it.endsWith(".xhtml") || it.endsWith(".html") }
            }

            for (href in targetHrefs) {
                val entry = zip.getEntry(href) ?: zip.getEntry(href.removePrefix("/"))
                if (entry != null) {
                    val htmlContent = zip.getInputStream(entry).bufferedReader().use { it.readText() }
                    val parsedBlocks = parseHtmlBlocks(htmlContent)
                    if (parsedBlocks.isNotEmpty()) {
                        val chapterTitle = parsedBlocks.firstOrNull { it.type == BlockType.HEADING }?.text
                            ?: "Chapter $chapterIndex"
                        chapters.add(ParsedChapter(title = chapterTitle, blocks = parsedBlocks))
                        chapterIndex++
                    }
                }
            }

            if (chapters.isEmpty()) {
                throw IllegalStateException("No readable content could be extracted from EPUB")
            }

            ParsedDocument(
                title = bookTitle,
                author = author,
                format = DocumentFormat.EPUB,
                chapters = chapters
            )
        } finally {
            zip.close()
        }
    }

    private fun parseHtmlBlocks(html: String): List<ParsedBlock> {
        val blocks = mutableListOf<ParsedBlock>()

        // Replace block tags with boundary markers to avoid word-gluing
        var processed = html
            .replace(Regex("(?i)<script[\\s\\S]*?</script>"), " ")
            .replace(Regex("(?i)<style[\\s\\S]*?</style>"), " ")
            .replace(Regex("(?i)<br\\s*/?>"), "\n")
            .replace(Regex("(?i)</?(?:p|div|section|article|blockquote|li)[^>]*>"), "\n\n")

        // Heading tags
        val hPattern = Pattern.compile("<(h[1-6])[^>]*>(.*?)</\\1>", Pattern.CASE_INSENSITIVE or Pattern.DOTALL)
        val hMatcher = hPattern.matcher(html)
        while (hMatcher.find()) {
            val tag = hMatcher.group(1) ?: "h1"
            val text = cleanHtml(hMatcher.group(2) ?: "")
            if (text.isNotEmpty()) {
                val level = tag.substring(1).toIntOrNull() ?: 1
                blocks.add(ParsedBlock(type = BlockType.HEADING, text = text, level = level))
            }
        }

        val rawParagraphs = processed.split("\n\n")
            .map { cleanHtml(it) }
            .filter { it.isNotEmpty() }

        for (p in rawParagraphs) {
            // Avoid duplicate headings already captured
            if (blocks.none { it.text == p }) {
                blocks.add(ParsedBlock(type = BlockType.PARAGRAPH, text = p))
            }
        }

        return blocks
    }

    private fun cleanHtml(html: String): String {
        return html
            .replace(Regex("<[^>]+>"), " ")
            .replace("&nbsp;", " ")
            .replace("&mdash;", "—")
            .replace("&ndash;", "–")
            .replace("&ldquo;", "\"")
            .replace("&rdquo;", "\"")
            .replace("&lsquo;", "'")
            .replace("&rsquo;", "'")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")
            .replace(Regex("&#(\\d+);")) { match ->
                val code = match.groupValues[1].toIntOrNull()
                if (code != null) Character.toChars(code).joinToString("") else ""
            }
            .replace(Regex("&#x([0-9a-fA-F]+);")) { match ->
                val code = match.groupValues[1].toIntOrNull(16)
                if (code != null) Character.toChars(code).joinToString("") else ""
            }
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun getAttribute(tagAttrs: String, attrName: String): String? {
        val pattern = Pattern.compile("$attrName=[\"']([^\"']+)[\"']", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(tagAttrs)
        return if (matcher.find()) matcher.group(1) else null
    }

    private fun normalizePath(path: String): String {
        val parts = path.replace("\\", "/").split("/")
        val stack = mutableListOf<String>()
        for (part in parts) {
            if (part == "." || part.isEmpty()) continue
            if (part == "..") {
                if (stack.isNotEmpty()) stack.removeAt(stack.size - 1)
            } else {
                stack.add(part)
            }
        }
        return stack.joinToString("/")
    }
}
