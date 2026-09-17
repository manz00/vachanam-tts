package com.vachanam.reader.accessibility

import android.content.Context
import com.vachanam.reader.ui.theme.ReaderBackgroundTheme
import com.vachanam.reader.ui.theme.ReaderFontFamily
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class ThemeManager(context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_theme", Context.MODE_PRIVATE)

    private val _currentReaderTheme = MutableStateFlow(ReaderBackgroundTheme.DARK_SLATE)
    val currentReaderTheme: StateFlow<ReaderBackgroundTheme> = _currentReaderTheme.asStateFlow()

    init {
        val saved = prefs.getString("reader_theme", null)
        if (saved != null) {
            _currentReaderTheme.value = ReaderBackgroundTheme.fromId(saved)
        }
    }

    fun setTheme(theme: ReaderBackgroundTheme) {
        _currentReaderTheme.value = theme
        prefs.edit().putString("reader_theme", theme.id).apply()
    }

    companion object {
        @Volatile
        private var instance: ThemeManager? = null

        fun getInstance(context: Context): ThemeManager {
            return instance ?: synchronized(this) {
                instance ?: ThemeManager(context.applicationContext).also { instance = it }
            }
        }
    }
}

class FontManager(context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_font", Context.MODE_PRIVATE)

    private val _selectedFont = MutableStateFlow(ReaderFontFamily.SYSTEM)
    val selectedFont: StateFlow<ReaderFontFamily> = _selectedFont.asStateFlow()

    private val _fontSize = MutableStateFlow(19.0f)
    val fontSize: StateFlow<Float> = _fontSize.asStateFlow()

    private val _lineSpacingMultiplier = MutableStateFlow(1.6f)
    val lineSpacingMultiplier: StateFlow<Float> = _lineSpacingMultiplier.asStateFlow()

    private val _characterSpacing = MutableStateFlow(0.5f)
    val characterSpacing: StateFlow<Float> = _characterSpacing.asStateFlow()

    private val _isBoldTextEnabled = MutableStateFlow(false)
    val isBoldTextEnabled: StateFlow<Boolean> = _isBoldTextEnabled.asStateFlow()

    init {
        val savedFont = prefs.getString("font_family", null)
        if (savedFont != null) {
            _selectedFont.value = ReaderFontFamily.fromId(savedFont)
        }
        _fontSize.value = prefs.getFloat("font_size", 19.0f)
        _lineSpacingMultiplier.value = prefs.getFloat("line_spacing", 1.6f)
        _characterSpacing.value = prefs.getFloat("character_spacing", 0.5f)
        _isBoldTextEnabled.value = prefs.getBoolean("bold_text", false)
    }

    fun setFontFamily(font: ReaderFontFamily) {
        _selectedFont.value = font
        prefs.edit().putString("font_family", font.id).apply()
    }

    fun setFontSize(size: Float) {
        _fontSize.value = size.coerceIn(12f, 40f)
        prefs.edit().putFloat("font_size", _fontSize.value).apply()
    }

    fun setLineSpacing(spacing: Float) {
        _lineSpacingMultiplier.value = spacing.coerceIn(1.2f, 2.5f)
        prefs.edit().putFloat("line_spacing", _lineSpacingMultiplier.value).apply()
    }

    fun setCharacterSpacing(spacing: Float) {
        _characterSpacing.value = spacing.coerceIn(0f, 3f)
        prefs.edit().putFloat("character_spacing", _characterSpacing.value).apply()
    }

    fun setBoldText(enabled: Boolean) {
        _isBoldTextEnabled.value = enabled
        prefs.edit().putBoolean("bold_text", enabled).apply()
    }

    companion object {
        @Volatile
        private var instance: FontManager? = null

        fun getInstance(context: Context): FontManager {
            return instance ?: synchronized(this) {
                instance ?: FontManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
