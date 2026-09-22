package com.vachanam.reader.data.text

import java.util.Locale
import java.util.regex.Pattern

enum class MathSpeechStyle(val displayName: String) {
    CONVERSATIONAL("Conversational"),
    MATH_SPEAK_RIGOROUS("MathSpeak Rigorous")
}

class MathSpeechEngine {

    private val superscriptMap = mapOf(
        '⁰' to "0", '¹' to "1", '²' to "2", '³' to "3", '⁴' to "4",
        '⁵' to "5", '⁶' to "6", '⁷' to "7", '⁸' to "8", '⁹' to "9",
        '⁺' to "+", '⁻' to "-", 'ⁿ' to "n"
    )

    private val greekMap = mapOf(
        "α" to "alpha", "β" to "beta", "γ" to "gamma", "δ" to "delta", "ε" to "epsilon",
        "ζ" to "zeta", "η" to "eta", "θ" to "theta", "ι" to "iota", "κ" to "kappa",
        "λ" to "lambda", "μ" to "mu", "ν" to "nu", "ξ" to "xi", "ο" to "omicron",
        "π" to "pi", "ρ" to "rho", "σ" to "sigma", "τ" to "tau", "υ" to "upsilon",
        "φ" to "phi", "χ" to "chi", "ψ" to "psi", "ω" to "omega",
        "Γ" to "capital gamma", "Δ" to "capital delta", "Θ" to "capital theta",
        "Λ" to "capital lambda", "Ξ" to "capital xi", "Π" to "capital pi",
        "Σ" to "capital sigma", "Φ" to "capital phi", "Ψ" to "capital psi", "Ω" to "capital omega"
    )

    private val mathSymbols = mapOf(
        "≠" to "not equal to",
        "≈" to "approximately equal to",
        "≤" to "less than or equal to",
        "≥" to "greater than or equal to",
        "±" to "plus or minus",
        "∓" to "minus or plus",
        "×" to "times",
        "÷" to "divided by",
        "∈" to "is an element of",
        "∉" to "is not an element of",
        "⊂" to "is a subset of",
        "⊆" to "is a subset of or equal to",
        "∪" to "union",
        "∩" to "intersection",
        "∀" to "for all",
        "∃" to "there exists",
        "∄" to "there does not exist",
        "∇" to "del",
        "∂" to "partial derivative",
        "∞" to "infinity",
        "∝" to "is proportional to",
        "∫" to "integral",
        "∑" to "sum",
        "∏" to "product",
        "√" to "square root of",
        "→" to "approaches",
        "⇒" to "implies",
        "⇔" to "if and only if"
    )

    private val siUnits = listOf(
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*nm\\b"), "$1 nanometers"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*μm\\b"), "$1 micrometers"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*mm\\b"), "$1 millimeters"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*cm\\b"), "$1 centimeters"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*km\\b"), "$1 kilometers"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*ms\\b"), "$1 milliseconds"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*ns\\b"), "$1 nanoseconds"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*kHz\\b", Pattern.CASE_INSENSITIVE), "$1 kilohertz"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*MHz\\b", Pattern.CASE_INSENSITIVE), "$1 megahertz"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*GHz\\b", Pattern.CASE_INSENSITIVE), "$1 gigahertz"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*THz\\b", Pattern.CASE_INSENSITIVE), "$1 terahertz"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*mV\\b"), "$1 millivolts"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*kV\\b"), "$1 kilovolts"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*mA\\b"), "$1 milliamperes"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*pF\\b"), "$1 picofarads"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*nF\\b"), "$1 nanofarads"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*μF\\b"), "$1 microfarads"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*mol\\b"), "$1 moles"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*kcal\\b"), "$1 kilocalories"),
        Pair(Pattern.compile("(\\b\\d+(?:\\.\\d+)?)\\s*kJ\\b"), "$1 kilojoules")
    )

    fun vocalize(text: String, style: MathSpeechStyle = MathSpeechStyle.CONVERSATIONAL): String {
        var processed = text

        // 1. Expand SI Units
        for ((pattern, replacement) in siUnits) {
            processed = pattern.matcher(processed).replaceAll(replacement)
        }

        // 2. Scientific notation: 6.022e23 or 3.0 x 10^8
        val sciMatcher = sciPattern.matcher(processed)
        val sb = StringBuffer()
        while (sciMatcher.find()) {
            val base = sciMatcher.group(1) ?: ""
            val exp = sciMatcher.group(2) ?: ""
            val expClean = exp.replace("+", "")
            val spokenExp = if (expClean.startsWith("-")) {
                "minus " + expClean.removePrefix("-")
            } else {
                expClean
            }
            sciMatcher.appendReplacement(sb, "$base times ten to the power of $spokenExp")
        }
        sciMatcher.appendTail(sb)
        processed = sb.toString()

        // 3. Superscripts: x² -> x squared, x³ -> x cubed, 10⁻¹² -> 10 to the power of minus 12
        val superMatcher = superPattern.matcher(processed)
        val superSb = StringBuffer()
        while (superMatcher.find()) {
            val base = superMatcher.group(1) ?: ""
            val rawSupers = superMatcher.group(2) ?: ""
            val decoded = buildString {
                for (ch in rawSupers) {
                    append(superscriptMap[ch] ?: ch)
                }
            }
            val replacement = when (decoded) {
                "2" -> "$base squared"
                "3" -> "$base cubed"
                "n" -> "$base to the nth power"
                else -> {
                    if (decoded.startsWith("-")) {
                        "$base to the minus ${decoded.removePrefix("-")}"
                    } else {
                        "$base to the power of $decoded"
                    }
                }
            }
            superMatcher.appendReplacement(superSb, replacement)
        }
        superMatcher.appendTail(superSb)
        processed = superSb.toString()

        // 4. LaTeX fractions: \frac{a}{b} -> a over b
        val fracMatcher = fracPattern.matcher(processed)
        val fracSb = StringBuffer()
        while (fracMatcher.find()) {
            val num = fracMatcher.group(1) ?: ""
            val den = fracMatcher.group(2) ?: ""
            val rep = if (style == MathSpeechStyle.MATH_SPEAK_RIGOROUS) {
                "start fraction, $num, divided by, $den, end fraction"
            } else {
                "$num over $den"
            }
            fracMatcher.appendReplacement(fracSb, rep)
        }
        fracMatcher.appendTail(fracSb)
        processed = fracSb.toString()

        // 5. LaTeX square roots: \sqrt{x}
        val sqrtMatcher = sqrtPattern.matcher(processed)
        val sqrtSb = StringBuffer()
        while (sqrtMatcher.find()) {
            val arg = sqrtMatcher.group(1) ?: ""
            val rep = if (style == MathSpeechStyle.MATH_SPEAK_RIGOROUS) {
                "start root, $arg, end root"
            } else {
                "square root of $arg"
            }
            sqrtMatcher.appendReplacement(sqrtSb, rep)
        }
        sqrtMatcher.appendTail(sqrtSb)
        processed = sqrtSb.toString()

        // 6. Greek letters
        for ((greek, spoken) in greekMap) {
            if (processed.contains(greek)) {
                processed = processed.replace(greek, " $spoken ")
            }
        }

        // 7. Math symbols
        for ((sym, spoken) in mathSymbols) {
            if (processed.contains(sym)) {
                processed = processed.replace(sym, " $spoken ")
            }
        }

        // Collapse duplicate whitespace
        return processed.replace(Regex("\\s+"), " ").trim()
    }

    companion object {
        val shared = MathSpeechEngine()

        private val sciPattern = Pattern.compile("(\\b\\d+(?:\\.\\d+)?)[eE]([+-]?\\d+)\\b")
        private val superPattern = Pattern.compile("([a-zA-Z0-9])([⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻ⁿ]+)")
        private val fracPattern = Pattern.compile("\\\\frac\\{([^}]+)\\}\\{([^}]+)\\}")
        private val sqrtPattern = Pattern.compile("\\\\sqrt\\{([^}]+)\\}")
    }
}
