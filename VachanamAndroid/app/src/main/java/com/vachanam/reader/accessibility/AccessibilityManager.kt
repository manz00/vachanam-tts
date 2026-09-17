package com.vachanam.reader.accessibility

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class AccessibilityManager(context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_accessibility", Context.MODE_PRIVATE)

    private val _isBionicReadingEnabled = MutableStateFlow(false)
    val isBionicReadingEnabled: StateFlow<Boolean> = _isBionicReadingEnabled.asStateFlow()

    private val _isReadingRulerEnabled = MutableStateFlow(false)
    val isReadingRulerEnabled: StateFlow<Boolean> = _isReadingRulerEnabled.asStateFlow()

    private val _rulerHeight = MutableStateFlow(48f)
    val rulerHeight: StateFlow<Float> = _rulerHeight.asStateFlow()

    private val _isHighContrastEnabled = MutableStateFlow(false)
    val isHighContrastEnabled: StateFlow<Boolean> = _isHighContrastEnabled.asStateFlow()

    init {
        _isBionicReadingEnabled.value = prefs.getBoolean("bionic_reading", false)
        _isReadingRulerEnabled.value = prefs.getBoolean("reading_ruler", false)
        _rulerHeight.value = prefs.getFloat("ruler_height", 48f)
        _isHighContrastEnabled.value = prefs.getBoolean("high_contrast", false)
    }

    fun setBionicReading(enabled: Boolean) {
        _isBionicReadingEnabled.value = enabled
        prefs.edit().putBoolean("bionic_reading", enabled).apply()
    }

    fun setReadingRuler(enabled: Boolean) {
        _isReadingRulerEnabled.value = enabled
        prefs.edit().putBoolean("reading_ruler", enabled).apply()
    }

    fun setRulerHeight(height: Float) {
        _rulerHeight.value = height.coerceIn(24f, 96f)
        prefs.edit().putFloat("ruler_height", _rulerHeight.value).apply()
    }

    fun setHighContrast(enabled: Boolean) {
        _isHighContrastEnabled.value = enabled
        prefs.edit().putBoolean("high_contrast", enabled).apply()
    }

    companion object {
        @Volatile
        private var instance: AccessibilityManager? = null

        fun getInstance(context: Context): AccessibilityManager {
            return instance ?: synchronized(this) {
                instance ?: AccessibilityManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
