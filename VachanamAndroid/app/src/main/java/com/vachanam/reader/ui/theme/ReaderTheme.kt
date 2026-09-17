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
    CREAM(
        id = "Cream",
        displayName = "Warm Cream",
        backgroundColor = Color(0xFFFAF0D9),
        textColor = Color(0xFF2A241F),
        secondaryTextColor = Color(0xFF2A241F).copy(alpha = 0.7f),
        isDark = false
    ),
    SEPIA(
        id = "Sepia",
        displayName = "Sepia Parchment",
        backgroundColor = Color(0xFFF4ECE7),
        textColor = Color(0xFF3A2E1D),
        secondaryTextColor = Color(0xFF3A2E1D).copy(alpha = 0.7f),
        isDark = false
    ),
    DARK_SLATE(
        id = "Dark Slate",
        displayName = "Slate Dark (Default)",
        backgroundColor = Color(0xFF151D2A),
        textColor = Color(0xFFE6EDF3),
        secondaryTextColor = Color(0xFF9DA7B3),
        isDark = true
    ),
    OLED_BLACK(
        id = "OLED Black",
        displayName = "Pure OLED Black",
        backgroundColor = Color(0xFF000000),
        textColor = Color(0xFFF8FAFC),
        secondaryTextColor = Color(0xFF94A3B8),
        isDark = true
    ),
    PURE_WHITE(
        id = "Pure White",
        displayName = "Paper White",
        backgroundColor = Color(0xFFFFFFFF),
        textColor = Color(0xFF0F172A),
        secondaryTextColor = Color(0xFF64748B),
        isDark = false
    );

    companion object {
        fun fromId(id: String): ReaderBackgroundTheme {
            return entries.firstOrNull { it.id.equals(id, ignoreCase = true) } ?: DARK_SLATE
        }
    }
}
