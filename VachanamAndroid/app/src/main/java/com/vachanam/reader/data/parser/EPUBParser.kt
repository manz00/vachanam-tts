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
    private val imgTagRegex = Pattern.compile("<(?:img|image)[^>]*>", Pattern.CASE_INSENSITIVE)
    private val srcAttrRegex = Pattern.compile("(?:src|xlink:href)=[\"']([^\"']+)[\"']", Pattern.CASE_INSENSITIVE)
    private val altAttrRegex = Pattern.compile("alt=[\"']([^\"']+)[\"']", Pattern.CASE_INSENSITIVE)

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
                    val parsedBlocks = parseHtmlBlocks(htmlContent, href, zip, manifest)
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

    private fun resolveImageData(
        src: String,
        chapterHref: String,
        zip: ZipFile,
        manifest: Map<String, String>
    ): ByteArray? {
        val cleanSrc = src.trim()
        if (cleanSrc.isEmpty()) return null

        val chapterDir = File(chapterHref).parent?.replace("\\", "/") ?: ""
        val combined = if (chapterDir.isNotEmpty()) "$chapterDir/$cleanSrc" else cleanSrc
        val normalized = normalizePath(combined)

        // 1. Direct entry lookup
        val direct = zip.getEntry(normalized) ?: zip.getEntry(normalized.removePrefix("/"))
        if (direct != null) {
            return zip.getInputStream(direct).use { it.readBytes() }
        }

        // 2. Decode percent-encoded paths
        val decoded = try { java.net.URLDecoder.decode(normalized, "UTF-8") } catch (_: Exception) { normalized }
        val decodedEntry = zip.getEntry(decoded) ?: zip.getEntry(decoded.removePrefix("/"))
        if (decodedEntry != null) {
            return zip.getInputStream(decodedEntry).use { it.readBytes() }
        }

        // 3. Fallback: match by filename against manifest
        val filename = File(normalized).name
        for ((_, manifestPath) in manifest) {
            if (manifestPath.endsWith(filename)) {
                val mEntry = zip.getEntry(manifestPath) ?: zip.getEntry(manifestPath.removePrefix("/"))
                if (mEntry != null) {
                    return zip.getInputStream(mEntry).use { it.readBytes() }
                }
            }
        }
        return null
    }

    private fun parseHtmlBlocks(
        html: String,
        chapterHref: String,
        zip: ZipFile,
        manifest: Map<String, String>
    ): List<ParsedBlock> {
        val blocks = mutableListOf<ParsedBlock>()

        // Replace image tags with custom delimiter to preserve in-flow position
        val imageTokens = mutableListOf<ParsedBlock>()
        var tokenCounter = 0
        val imgMatcher = imgTagRegex.matcher(html)
        val sb = StringBuffer()
        while (imgMatcher.find()) {
            val tag = imgMatcher.group()
            val srcMatch = srcAttrRegex.matcher(tag)
            val altMatch = altAttrRegex.matcher(tag)
            val src = if (srcMatch.find()) srcMatch.group(1) else null
            val alt = if (altMatch.find()) altMatch.group(1) else "Image"

            val tokenKey = "___VACHANAM_IMG_${tokenCounter}___"
            tokenCounter++

            val imgData = src?.let { resolveImageData(it, chapterHref, zip, manifest) }
            val imgBlock = ParsedBlock(
                type = BlockType.IMAGE,
                text = alt ?: "Image",
                imageData = imgData,
                imageUrl = src
            )
            imageTokens.add(imgBlock)
            imgMatcher.appendReplacement(sb, "\n\n$tokenKey\n\n")
        }
        imgMatcher.appendTail(sb)
        val htmlWithTokens = sb.toString()

        // Replace block tags with boundary markers to avoid word-gluing
        val processed = htmlWithTokens
            .replace(Regex("(?i)<script[\\s\\S]*?</script>"), " ")
            .replace(Regex("(?i)<style[\\s\\S]*?</style>"), " ")
            .replace(Regex("(?i)<br\\s*/?>"), "\n")
            .replace(Regex("(?i)</?(?:p|div|section|article|blockquote|li)[^>]*>"), "\n\n")

        val rawChunks = processed.split("\n\n")
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        var tokenIndex = 0
        for (chunk in rawChunks) {
            if (chunk.startsWith("___VACHANAM_IMG_") && chunk.endsWith("___")) {
                if (tokenIndex < imageTokens.size) {
                    blocks.add(imageTokens[tokenIndex++])
                }
                continue
            }

            // Check if chunk is a heading
            val hMatcher = Pattern.compile("^<h([1-6])[^>]*>(.*?)</h\\1>$", Pattern.CASE_INSENSITIVE or Pattern.DOTALL).matcher(chunk)
            if (hMatcher.find()) {
                val level = hMatcher.group(1).toIntOrNull() ?: 1
                val hText = cleanHtml(hMatcher.group(2) ?: "")
                if (hText.isNotEmpty()) {
                    blocks.add(ParsedBlock(type = BlockType.HEADING, text = hText, level = level))
                    continue
                }
            }

            val cleaned = cleanHtml(chunk)
            if (cleaned.isNotEmpty()) {
                blocks.add(ParsedBlock(type = BlockType.PARAGRAPH, text = cleaned))
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
