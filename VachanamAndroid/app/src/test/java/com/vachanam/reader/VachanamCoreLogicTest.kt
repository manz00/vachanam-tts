package com.vachanam.reader

import com.vachanam.reader.data.model.BlockType
import com.vachanam.reader.data.model.BoundingBox
import com.vachanam.reader.data.model.SemanticSentence
import com.vachanam.reader.data.model.SemanticWord
import com.vachanam.reader.data.parser.DocumentSource
import com.vachanam.reader.data.parser.MarkdownParser
import com.vachanam.reader.data.parser.PlainTextParser
import com.vachanam.reader.data.text.MathSpeechEngine
import com.vachanam.reader.data.text.MathSpeechStyle
import com.vachanam.reader.data.text.TTSChunker
import com.vachanam.reader.data.text.TextNormalizer
import com.vachanam.reader.data.text.WordReconstructor
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class VachanamCoreLogicTest {

    @Test
    fun testWordReconstruction_joinsBrokenMorpheme() {
        val reconstructor = WordReconstructor.shared
        val result = reconstructor.resolveHyphenation("probabil-", "ity")
        assertEquals("probability", result.reconstructedWord)
        assertTrue(result.wasHyphenJoined)
        assertFalse(result.preservedHyphen)
    }

    @Test
    fun testWordReconstruction_preservesCompoundWord() {
        val reconstructor = WordReconstructor.shared
        val result = reconstructor.resolveHyphenation("well-", "known")
        assertEquals("well-known", result.reconstructedWord)
        assertTrue(result.wasHyphenJoined)
        assertTrue(result.preservedHyphen)
    }

    @Test
    fun testMathSpeechEngine_siUnits() {
        val engine = MathSpeechEngine.shared
        val result = engine.vocalize("The wavelength is 500 nm with a frequency of 2.4 GHz.")
        assertTrue("Expected nanometers, got: $result", result.contains("500 nanometers"))
        assertTrue("Expected gigahertz, got: $result", result.contains("2.4 gigahertz"))
    }

    @Test
    fun testMathSpeechEngine_superscriptsAndExponents() {
        val engine = MathSpeechEngine.shared
        val result = engine.vocalize("The area is x² and Avogadro's constant is 6.022e23.")
        assertTrue("Expected squared, got: $result", result.contains("x squared"))
        assertTrue("Expected power of 23, got: $result", result.contains("six point zero two two times ten to the power of 23") || result.contains("times ten to the power of 23"))
    }

    @Test
    fun testMathSpeechEngine_latexMacros() {
        val engine = MathSpeechEngine.shared
        val conversational = engine.vocalize("\\frac{1}{2}", MathSpeechStyle.CONVERSATIONAL)
        assertEquals("1 over 2", conversational)

        val rigorous = engine.vocalize("\\frac{a}{b}", MathSpeechStyle.MATH_SPEAK_RIGOROUS)
        assertTrue(rigorous.contains("start fraction, a, divided by, b, end fraction"))
    }

    @Test
    fun testTextNormalizer_abbreviations() {
        val normalizer = TextNormalizer.shared
        val text = "e.g., neural TTS is fast, i.e., sub-second latency, et al."
        val normalized = normalizer.normalizeForTTS(text)
        assertTrue("Expected 'for example', got: $normalized", normalized.contains("for example,"))
        assertTrue("Expected 'that is', got: $normalized", normalized.contains("that is,"))
        assertTrue("Expected 'and colleagues', got: $normalized", normalized.contains("and colleagues,"))
    }

    @Test
    fun testPlainTextParser_basicParsing() = runBlocking {
        val parser = PlainTextParser()
        val text = "Chapter 1: The Beginning\n\nThis is the first paragraph.\n\nThis is the second paragraph."
        val doc = parser.parse(DocumentSource.RawText(text, "Test Document"))

        assertEquals("Chapter 1: The Beginning", doc.title)
        assertEquals(1, doc.chapters.size)
        assertEquals(2, doc.chapters[0].blocks.size)
    }

    @Test
    fun testMarkdownParser_headingsAndLists() = runBlocking {
        val parser = MarkdownParser()
        val md = """
            # Document Title
            
            This is regular narrative text.
            
            - First bullet
            - Second bullet
            
            > Important quote
        """.trimIndent()

        val doc = parser.parse(DocumentSource.RawText(md, "Markdown Doc"))
        assertEquals("Document Title", doc.title)
        val blocks = doc.allBlocks
        assertTrue(blocks.any { it.type == BlockType.HEADING })
        assertTrue(blocks.any { it.type == BlockType.LIST_ITEM })
        assertTrue(blocks.any { it.type == BlockType.QUOTE })
    }

    @Test
    fun testTTSChunker_bounds() {
        val chunker = TTSChunker(minWordsPerChunk = 5, maxWordsPerChunk = 15)
        val words = (1..20).map { id ->
            SemanticWord(
                id = id,
                globalWordID = id,
                text = "word$id",
                pageIndex = 0,
                sentenceID = 1,
                wordIndexInSentence = id - 1,
                bounds = BoundingBox.ZERO
            )
        }
        val sentence = SemanticSentence(
            id = 1,
            sentenceID = 1,
            paragraphID = 1,
            primaryPageIndex = 0,
            pageSpans = setOf(0),
            text = words.joinToString(" ") { it.text },
            words = words
        )

        val chunks = chunker.chunkSentences(listOf(sentence))
        assertTrue("Expected multiple chunks for 20 words with max 15, got: ${chunks.size}", chunks.size >= 2)
        assertEquals(20, chunks.sumOf { it.wordCount })
    }

    @Test
    fun testMarkdownParser_imageExtraction() = runBlocking {
        val parser = MarkdownParser()
        val md = """
            # Document With Media

            Here is a system diagram:

            ![Architecture Overview](https://example.com/arch.png)

            And here is narrative text.
        """.trimIndent()

        val doc = parser.parse(DocumentSource.RawText(md, "Media Doc"))
        val imgBlock = doc.allBlocks.firstOrNull { it.type == BlockType.IMAGE }
        assertNotNull(imgBlock)
        assertEquals("Architecture Overview", imgBlock?.text)
        assertEquals("https://example.com/arch.png", imgBlock?.imageUrl)
    }

    @Test
    fun testWebArticleParser_blocksInsecureHttpScheme() {
        try {
            com.vachanam.reader.data.parser.WebArticleParser.validateUrl("http://insecure-news.example.com/article")
            fail("Expected SecurityException for HTTP scheme")
        } catch (e: SecurityException) {
            assertTrue(e.message?.contains("Only HTTPS is permitted") == true)
        }
    }

    @Test
    fun testWebArticleParser_blocksLocalhostAndLoopback() {
        listOf(
            "https://localhost/secret",
            "https://127.0.0.1:8080/admin",
            "https://sub.localhost/internal"
        ).forEach { url ->
            try {
                com.vachanam.reader.data.parser.WebArticleParser.validateUrl(url)
                fail("Expected SecurityException for loopback/localhost: $url")
            } catch (e: SecurityException) {
                // Expected
            }
        }
    }

    @Test
    fun testWebArticleParser_blocksPrivateSubnetsAndMetadata() {
        listOf(
            "https://169.254.169.254/latest/meta-data/",
            "https://10.0.0.1/router",
            "https://192.168.1.1/gateway"
        ).forEach { url ->
            try {
                com.vachanam.reader.data.parser.WebArticleParser.validateUrl(url)
                fail("Expected SecurityException for private IP/metadata: $url")
            } catch (e: SecurityException) {
                // Expected
            }
        }
    }

    @Test
    fun testWebArticleParser_allowsValidHttpsUrl() {
        val validUrl = com.vachanam.reader.data.parser.WebArticleParser.validateUrl("https://en.wikipedia.org/wiki/Speech_synthesis")
        assertEquals("https", validUrl.protocol)
        assertEquals("en.wikipedia.org", validUrl.host)
    }
}

