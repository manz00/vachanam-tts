package com.vachanam.reader.data.text

data class WordReconstructionResult(
    val reconstructedWord: String,
    val wasHyphenJoined: Boolean,
    val preservedHyphen: Boolean
)

class WordReconstructor {
    private val commonSuffixes: Set<String> = setOf(
        "ity", "tion", "sion", "ment", "ing", "ed", "able", "ible",
        "ize", "ise", "ness", "ical", "ous", "ence", "ance", "istic",
        "ally", "ive", "ful", "less", "est", "er", "or", "ly", "ism",
        "ist", "ary", "ery", "ory", "al", "ial", "ian", "ic", "logy",
        "graphy", "meter", "scopic", "phobia", "philic", "genesis"
    )

    fun resolveHyphenation(firstPart: String, secondPart: String): WordReconstructionResult {
        val trimmedFirst = firstPart.trim()
        val trimmedSecond = secondPart.trim()

        if (!trimmedFirst.endsWith("-") && !trimmedFirst.endsWith("\u2010") && !trimmedFirst.endsWith("\u2011")) {
            return WordReconstructionResult(
                reconstructedWord = "$trimmedFirst $trimmedSecond",
                wasHyphenJoined = false,
                preservedHyphen = false
            )
        }

        val prefix = trimmedFirst.dropLast(1).trim()
        val suffix = trimmedSecond

        if (prefix.isEmpty() || suffix.isEmpty()) {
            return WordReconstructionResult(
                reconstructedWord = trimmedFirst + trimmedSecond,
                wasHyphenJoined = false,
                preservedHyphen = true
            )
        }

        val merged = prefix + suffix
        val hyphenated = "$prefix-$suffix"

        val lowerSuffix = suffix.lowercase()
        if (commonSuffixes.contains(lowerSuffix)) {
            return WordReconstructionResult(
                reconstructedWord = merged,
                wasHyphenJoined = true,
                preservedHyphen = false
            )
        }

        // If second part starts with lowercase, it was almost certainly broken mid-word
        val firstChar = suffix.firstOrNull()
        if (firstChar != null && firstChar.isLowerCase()) {
            return WordReconstructionResult(
                reconstructedWord = merged,
                wasHyphenJoined = true,
                preservedHyphen = false
            )
        }

        // Fallback: preserve hyphen
        return WordReconstructionResult(
            reconstructedWord = hyphenated,
            wasHyphenJoined = true,
            preservedHyphen = true
        )
    }

    companion object {
        val shared = WordReconstructor()
    }
}
