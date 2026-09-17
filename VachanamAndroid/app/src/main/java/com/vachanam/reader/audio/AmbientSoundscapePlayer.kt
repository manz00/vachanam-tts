package com.vachanam.reader.audio

import android.content.Context
import android.media.MediaPlayer
import com.vachanam.reader.R
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class SoundscapePreset(
    val id: String,
    val title: String,
    val subtitle: String,
    val rawResId: Int
) {
    BROWN_NOISE(
        id = "brown_noise",
        title = "Brown Noise",
        subtitle = "Deep, soothing low-frequency rumble",
        rawResId = R.raw.brown_noise
    ),
    PINK_NOISE(
        id = "pink_noise",
        title = "Pink Noise",
        subtitle = "Balanced waterfall-like calming noise",
        rawResId = R.raw.pink_noise
    ),
    BINAURAL_FOCUS(
        id = "binaural_focus_40hz",
        title = "Binaural Focus",
        subtitle = "40 Hz gamma rhythm for deep focus",
        rawResId = R.raw.binaural_focus_40hz
    ),
    SOFT_RAIN(
        id = "soft_rain",
        title = "Soft Rain",
        subtitle = "Gentle rainfall with droplet ambience",
        rawResId = R.raw.soft_rain
    ),
    LIBRARY_AMBIENCE(
        id = "library_ambience",
        title = "Library & Café",
        subtitle = "Warm, quiet acoustic atmosphere",
        rawResId = R.raw.library_ambience
    );

    companion object {
        fun fromId(id: String): SoundscapePreset? {
            return entries.firstOrNull { it.id.equals(id, ignoreCase = true) }
        }
    }
}

class AmbientSoundscapePlayer(private val context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_soundscape", Context.MODE_PRIVATE)

    private val _currentPreset = MutableStateFlow<SoundscapePreset?>(null)
    val currentPreset: StateFlow<SoundscapePreset?> = _currentPreset.asStateFlow()

    private val _volume = MutableStateFlow(0.3f)
    val volume: StateFlow<Float> = _volume.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _isStudyModeEnabled = MutableStateFlow(false)
    val isStudyModeEnabled: StateFlow<Boolean> = _isStudyModeEnabled.asStateFlow()

    private var mediaPlayer: MediaPlayer? = null
    private var fadeJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var isTTSActive: Boolean = false

    init {
        loadPersisted()
    }

    private fun loadPersisted() {
        val savedId = prefs.getString("preset", null)
        if (savedId != null) {
            _currentPreset.value = SoundscapePreset.fromId(savedId)
        }
        _volume.value = prefs.getFloat("volume", 0.3f)
        _isStudyModeEnabled.value = prefs.getBoolean("studyMode", false)
    }

    fun selectPreset(preset: SoundscapePreset?) {
        if (_currentPreset.value == preset) return

        val wasPlaying = _isPlaying.value
        stopAmbient(fadeOut = false)

        _currentPreset.value = preset
        if (preset != null) {
            prefs.edit().putString("preset", preset.id).apply()
        } else {
            prefs.edit().remove("preset").apply()
        }

        if (preset != null && (wasPlaying || _isStudyModeEnabled.value || isTTSActive)) {
            startAmbient(fadeIn = true)
        }
    }

    fun setVolume(newVolume: Float) {
        val clamped = newVolume.coerceIn(0.0f, 1.0f)
        _volume.value = clamped
        prefs.edit().putFloat("volume", clamped).apply()
        if (_isPlaying.value) {
            mediaPlayer?.setVolume(clamped, clamped)
        }
    }

    fun setStudyMode(enabled: Boolean) {
        _isStudyModeEnabled.value = enabled
        prefs.edit().putBoolean("studyMode", enabled).apply()

        if (enabled && _currentPreset.value != null && !_isPlaying.value) {
            startAmbient(fadeIn = true)
        } else if (!enabled && !isTTSActive && _isPlaying.value) {
            stopAmbient(fadeOut = true)
        }
    }

    fun startAmbient(fadeIn: Boolean = true) {
        val preset = _currentPreset.value ?: return

        try {
            if (mediaPlayer == null) {
                mediaPlayer = MediaPlayer.create(context, preset.rawResId)?.apply {
                    isLooping = true
                }
            }

            fadeJob?.cancel()

            if (fadeIn) {
                mediaPlayer?.setVolume(0f, 0f)
                mediaPlayer?.start()
                _isPlaying.value = true

                fadeJob = scope.launch {
                    val targetVol = _volume.value
                    val steps = 15
                    for (i in 1..steps) {
                        val v = targetVol * (i.toFloat() / steps)
                        mediaPlayer?.setVolume(v, v)
                        delay(60)
                    }
                }
            } else {
                val v = _volume.value
                mediaPlayer?.setVolume(v, v)
                mediaPlayer?.start()
                _isPlaying.value = true
            }
        } catch (_: Exception) {
            _isPlaying.value = false
        }
    }

    fun pauseAmbient() {
        if (!_isPlaying.value) return
        mediaPlayer?.pause()
        _isPlaying.value = false
    }

    fun stopAmbient(fadeOut: Boolean = true) {
        val player = mediaPlayer ?: run {
            _isPlaying.value = false
            return
        }

        fadeJob?.cancel()

        if (fadeOut) {
            fadeJob = scope.launch {
                val currentVol = _volume.value
                val steps = 10
                for (i in (steps - 1) downTo 0) {
                    val v = currentVol * (i.toFloat() / steps)
                    player.setVolume(v, v)
                    delay(50)
                }
                player.stop()
                player.release()
                mediaPlayer = null
                _isPlaying.value = false
            }
        } else {
            player.stop()
            player.release()
            mediaPlayer = null
            _isPlaying.value = false
        }
    }

    // TTS Lifecycle Hooks
    fun handleTTSPlayStarted() {
        isTTSActive = true
        if (_currentPreset.value != null && !_isPlaying.value) {
            startAmbient(fadeIn = true)
        }
    }

    fun handleTTSPaused() {
        isTTSActive = false
        if (!_isStudyModeEnabled.value && _isPlaying.value) {
            pauseAmbient()
        }
    }

    fun handleTTSStopped() {
        isTTSActive = false
        if (!_isStudyModeEnabled.value && _isPlaying.value) {
            stopAmbient(fadeOut = true)
        }
    }

    companion object {
        @Volatile
        private var instance: AmbientSoundscapePlayer? = null

        fun getInstance(context: Context): AmbientSoundscapePlayer {
            return instance ?: synchronized(this) {
                instance ?: AmbientSoundscapePlayer(context.applicationContext).also { instance = it }
            }
        }
    }
}
