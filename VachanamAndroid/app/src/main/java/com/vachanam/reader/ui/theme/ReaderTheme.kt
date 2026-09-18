package com.vachanam.reader.ui.theme

import androidx.compose.ui.graphics.Color

enum class ReaderBackgroundTheme(
    val id: String,
    val displayName: String,
    val backgroundColor: Color,
    val textColor: Color,
    val secondaryTextColor: Color,
    val isDark: Boolean
) {
    ORIGINAL(
        id = "Original",
        displayName = "Original (White)",
        backgroundColor = Color(0xFFFFFFFF),
        textColor = Color(0xFF1A1A1A),
        secondaryTextColor = Color(0xFF1A1A1A).copy(alpha = 0.65f),
        isDark = false
    ),
    QUIET(
        id = "Quiet",
        displayName = "Quiet (Warm Cream)",
        backgroundColor = Color(0xFFFBF0D9),
        textColor = Color(0xFF3B2E2A),
        secondaryTextColor = Color(0xFF3B2E2A).copy(alpha = 0.65f),
        isDark = false
    ),
    PAPER(
        id = "Paper",
        displayName = "Paper (Sepia)",
        backgroundColor = Color(0xFFEFE6D5),
        textColor = Color(0xFF2C2621),
        secondaryTextColor = Color(0xFF2C2621).copy(alpha = 0.65f),
        isDark = false
    ),
    CHARCOAL(
        id = "Charcoal",
        displayName = "Charcoal (Dark Slate)",
        backgroundColor = Color(0xFF2C2C2E),
        textColor = Color(0xFFE5E5EA),
        secondaryTextColor = Color(0xFFE5E5EA).copy(alpha = 0.60f),
        isDark = true
    ),
    NIGHT(
        id = "Night",
        displayName = "Night (Pitch Black)",
        backgroundColor = Color(0xFF000000),
        textColor = Color(0xFFD1D1D6),
        secondaryTextColor = Color(0xFFD1D1D6).copy(alpha = 0.60f),
        isDark = true
    );

    companion object {
        // Aliases for backward compatibility
        val CREAM get() = QUIET
        val SEPIA get() = PAPER
        val DARK_SLATE get() = CHARCOAL
        val OLED_BLACK get() = NIGHT
        val PURE_WHITE get() = ORIGINAL

        fun fromId(id: String): ReaderBackgroundTheme {
            return when (id.lowercase()) {
                "cream", "quiet" -> QUIET
                "sepia", "paper" -> PAPER
                "dark slate", "darkslate", "charcoal" -> CHARCOAL
                "oled black", "oledblack", "night" -> NIGHT
                "pure white", "purewhite", "original" -> ORIGINAL
                else -> entries.firstOrNull { it.id.equals(id, ignoreCase = true) } ?: CHARCOAL
            }
        }
    }
}

enum class ReadingLayout(val id: String, val displayName: String) {
    PAGINATED("Paginated", "Paginated"),
    CONTINUOUS("Continuous Scroll", "Continuous Scroll");

    companion object {
        fun fromId(id: String): ReadingLayout {
            return entries.firstOrNull { it.id.equals(id, ignoreCase = true) } ?: PAGINATED
        }
    }
}
