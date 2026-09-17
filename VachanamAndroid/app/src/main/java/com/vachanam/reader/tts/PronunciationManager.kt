package com.vachanam.reader.tts

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject

data class PronunciationOverride(
    val originalWord: String,
    val spokenReplacement: String,
    val isCaseSensitive: Boolean = false
)

class PronunciationManager(context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_pronunciations", Context.MODE_PRIVATE)

    private val _overrides = MutableStateFlow<Map<String, PronunciationOverride>>(emptyMap())
    val overrides: StateFlow<Map<String, PronunciationOverride>> = _overrides.asStateFlow()

    init {
        loadAll()
    }

    private fun loadAll() {
        val map = mutableMapOf<String, PronunciationOverride>()
        for ((key, value) in prefs.all) {
            if (value is String) {
                try {
                    val json = JSONObject(value)
                    map[key] = PronunciationOverride(
                        originalWord = json.getString("originalWord"),
                        spokenReplacement = json.getString("spokenReplacement"),
                        isCaseSensitive = json.optBoolean("isCaseSensitive", false)
                    )
                } catch (_: Exception) {}
            }
        }
        _overrides.value = map
    }

    fun setOverride(originalWord: String, replacement: String, caseSensitive: Boolean = false) {
        val key = if (caseSensitive) originalWord else originalWord.lowercase()
        val override = PronunciationOverride(originalWord, replacement, caseSensitive)

        val json = JSONObject().apply {
            put("originalWord", originalWord)
            put("spokenReplacement", replacement)
            put("isCaseSensitive", caseSensitive)
        }
        prefs.edit().putString(key, json.toString()).apply()

        val updated = _overrides.value.toMutableMap()
        updated[key] = override
        _overrides.value = updated
    }

    fun removeOverride(originalWord: String) {
        val key = originalWord.lowercase()
        prefs.edit().remove(key).remove(originalWord).apply()

        val updated = _overrides.value.toMutableMap()
        updated.remove(key)
        updated.remove(originalWord)
        _overrides.value = updated
    }

    fun applyOverrides(text: String): String {
        var result = text
        for ((_, override) in _overrides.value) {
            val regex = if (override.isCaseSensitive) {
                Regex("\\b${Regex.escape(override.originalWord)}\\b")
            } else {
                Regex("\\b${Regex.escape(override.originalWord)}\\b", RegexOption.IGNORE_CASE)
            }
            result = result.replace(regex, override.spokenReplacement)
        }
        return result
    }

    companion object {
        @Volatile
        private var instance: PronunciationManager? = null

        fun getInstance(context: Context): PronunciationManager {
            return instance ?: synchronized(this) {
                instance ?: PronunciationManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
