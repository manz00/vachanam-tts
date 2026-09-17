package com.vachanam.reader.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.vachanam.reader.R

val OpenDyslexicFontFamily = FontFamily(
    Font(R.font.opendyslexic_regular, FontWeight.Normal),
    Font(R.font.opendyslexic_bold, FontWeight.Bold)
)

enum class ReaderFontFamily(
    val id: String,
    val displayName: String
) {
    SYSTEM("System", "Modern Sans"),
    ROUNDED("Rounded", "Friendly Rounded"),
    SERIF("Serif", "Classic Serif"),
    OPEN_DYSLEXIC("OpenDyslexic", "OpenDyslexic (Dyslexia Friendly)"),
    MONO("Mono", "Monospaced");

    fun toFontFamily(): FontFamily {
        return when (this) {
            SYSTEM -> FontFamily.Default
            ROUNDED -> FontFamily.SansSerif
            SERIF -> FontFamily.Serif
            OPEN_DYSLEXIC -> OpenDyslexicFontFamily
            MONO -> FontFamily.Monospace
        }
    }

    companion object {
        fun fromId(id: String): ReaderFontFamily {
            return entries.firstOrNull { it.id.equals(id, ignoreCase = true) } ?: SYSTEM
        }
    }
}

val Typography = Typography(
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    )
)
