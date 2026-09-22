package com.vachanam.reader.data.text

import java.util.regex.Pattern

class TextNormalizer(
    private val mathEngine: MathSpeechEngine = MathSpeechEngine.shared
) {
    private val abbreviations = listOf(
        Pair(Pattern.compile("\\be\\.g\\.,?\\s*", Pattern.CASE_INSENSITIVE), "for example, "),
        Pair(Pattern.compile("\\bi\\.e\\.,?\\s*", Pattern.CASE_INSENSITIVE), "that is, "),
        Pair(Pattern.compile("\\bet al\\.,?\\s*", Pattern.CASE_INSENSITIVE), "and colleagues, "),
        Pair(Pattern.compile("\\betc\\.,?\\s*", Pattern.CASE_INSENSITIVE), "etcetera, "),
        Pair(Pattern.compile("\\bvs\\.,?\\s*", Pattern.CASE_INSENSITIVE), "versus "),
        Pair(Pattern.compile("\\bFig\\.\\s*(\\d+)", Pattern.CASE_INSENSITIVE), "Figure $1"),
        Pair(Pattern.compile("\\bFigs\\.\\s*(\\d+)", Pattern.CASE_INSENSITIVE), "Figures $1"),
        Pair(Pattern.compile("\\bEq\\.\\s*(\\d+)", Pattern.CASE_INSENSITIVE), "Equation $1"),
        Pair(Pattern.compile("\\bEqs\\.\\s*(\\d+)", Pattern.CASE_INSENSITIVE), "Equations $1"),
        Pair(Pattern.compile("\\bpp?\\.\\s*(\\d+)", Pattern.CASE_INSENSITIVE), "page $1"),
        Pair(Pattern.compile("\\bSec\\.\\s*(\\d+)", Pattern.CASE_INSENSITIVE), "Section $1"),
        Pair(Pattern.compile("\\bCh\\.\\s*(\\d+)", Pattern.CASE_INSENSITIVE), "Chapter $1"),
        Pair(Pattern.compile("\\bRef\\.\\s*(\\d+)", Pattern.CASE_INSENSITIVE), "Reference $1")
    )

    private val urlPattern = Pattern.compile("https?://([a-zA-Z0-9.-]+)[^\\s]*", Pattern.CASE_INSENSITIVE)
    private val doiPattern = Pattern.compile("10\\.\\d{4,9}/[-._;()/:A-Z0-9]+", Pattern.CASE_INSENSITIVE)

    fun normalizeForTTS(text: String, mathStyle: MathSpeechStyle = MathSpeechStyle.CONVERSATIONAL): String {
        var processed = text

        // 1. URLs and DOIs
        processed = urlPattern.matcher(processed).replaceAll("link to $1")
        processed = doiPattern.matcher(processed).replaceAll("publication DOI reference")

        // 2. Expand Latin & Scholarly abbreviations
        for ((pattern, replacement) in abbreviations) {
            processed = pattern.matcher(processed).replaceAll(replacement)
        }

        // 3. Mathematical speech & units
        processed = mathEngine.vocalize(processed, mathStyle)

        // 4. Intra-word hyphens in common compound words (e.g. on-device -> on device)
        processed = processed.replace(Regex("\\b([a-zA-Z]{2,})-([a-zA-Z]{2,})\\b"), "$1 $2")

        // 5. Clean up redundant spaces
        return processed.replace(Regex("\\s+"), " ").trim()
    }

    companion object {
        val shared = TextNormalizer()
    }
}
