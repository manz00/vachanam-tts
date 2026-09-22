package com.vachanam.reader.tts

import android.content.Context
import com.vachanam.reader.audio.AmbientSoundscapePlayer
import com.vachanam.reader.data.model.SemanticDocument
import com.vachanam.reader.data.text.TextNormalizer
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class TTSController(
    private val context: Context,
    private val coordinator: PlaybackCoordinator = PlaybackCoordinator.shared,
    private val pronunciationManager: PronunciationManager = PronunciationManager.getInstance(context),
    private val soundscapePlayer: AmbientSoundscapePlayer = AmbientSoundscapePlayer.getInstance(context),
    private val normalizer: TextNormalizer = TextNormalizer.shared
) {
    val systemAdapter = AndroidSystemAdapter(context)
    val kokoroAdapter = KokoroOnnxAdapter()

    private val _selectedModelId = MutableStateFlow("android_system")
    val selectedModelId: StateFlow<String> = _selectedModelId.asStateFlow()

    private val _selectedVoice = MutableStateFlow<String?>("default")
    val selectedVoice: StateFlow<String?> = _selectedVoice.asStateFlow()

    private val _speechRate = MutableStateFlow(1.0f)
    val speechRate: StateFlow<Float> = _speechRate.asStateFlow()

    private var playbackJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    init {
        systemAdapter.onWordSpokenRange = { start, end ->
            val chunk = coordinator.currentChunk.value
            val doc = coordinator.activeSemanticDocument.value
            if (chunk != null && doc != null && chunk.wordIDs.isNotEmpty()) {
                // Determine approximate word based on char offset
                val text = chunk.text
                val wordsBefore = text.substring(0, start.coerceAtMost(text.length))
                    .split("\\s+".toRegex())
                    .filter { it.isNotEmpty() }.size
                val targetWordIndex = wordsBefore.coerceIn(0, chunk.wordIDs.size - 1)
                val wordId = chunk.wordIDs[targetWordIndex]
                coordinator.updateWordHighlight(wordId)
            }
        }
    }

    fun setSpeechRate(rate: Float) {
        _speechRate.value = rate.coerceIn(0.5f, 2.5f)
    }

    fun selectModel(modelId: String) {
        _selectedModelId.value = modelId
        if (modelId == "kokoro_82m") {
            _selectedVoice.value = kokoroAdapter.metadata.supportedVoices.firstOrNull() ?: "af_heart"
        } else {
            _selectedVoice.value = systemAdapter.getAvailableVoices().firstOrNull() ?: "default"
            systemAdapter.setVoice(_selectedVoice.value)
        }
    }

    fun selectVoice(voice: String?) {
        _selectedVoice.value = voice
        systemAdapter.setVoice(voice)
    }

    fun previewVoice(voice: String) {
        val isMale = systemAdapter.detectGenderByName(voice) == AndroidSystemAdapter.Gender.MALE ||
                voice.startsWith("am_") || voice.startsWith("bm_")
        val sampleText = if (isMale) {
            "Hello! I am your male voice. How does this sound for reading?"
        } else {
            "Hello! I am your female voice. How does this sound for reading?"
        }
        systemAdapter.speak(sampleText, voice = voice, speed = _speechRate.value)
    }

    fun play(document: SemanticDocument? = null) {
        if (document != null) {
            coordinator.setDocument(document)
        }
        val doc = coordinator.activeSemanticDocument.value ?: return

        coordinator.startPlaying()
        soundscapePlayer.handleTTSPlayStarted()

        // If no active chunk, start from the current visible page or first page
        if (coordinator.currentChunk.value == null) {
            val page = coordinator.visiblePageIndex.value
            val pageChunks = doc.chunksForPage(page)
            val startChunk = pageChunks.firstOrNull() ?: doc.chunks.firstOrNull()
            if (startChunk != null) {
                coordinator.seekToWord(startChunk.wordIDs.firstOrNull() ?: 0)
            }
        }

        startChunkPlaybackLoop()
    }

    private fun startChunkPlaybackLoop() {
        playbackJob?.cancel()
        playbackJob = scope.launch {
            while (coordinator.isPlaying.value) {
                val chunk = coordinator.currentChunk.value ?: break
                val reqId = coordinator.currentRequestID

                // Apply custom pronunciations then speech normalization
                val withPronunciations = pronunciationManager.applyOverrides(chunk.text)
                val normalizedSpeech = normalizer.normalizeForTTS(withPronunciations)

                // Synthesize & Speak
                val rate = _speechRate.value
                val activeAdapter: TTSModelProtocol = if (_selectedModelId.value == "kokoro_82m" && kokoroAdapter.isLoaded) {
                    kokoroAdapter
                } else {
                    systemAdapter
                }
                val voice = _selectedVoice.value
                val result = activeAdapter.synthesize(normalizedSpeech, voice = voice, speed = rate, pauseDurationSec = chunk.pauseDurationAfter)

                if (reqId != coordinator.currentRequestID) break

                if (activeAdapter == systemAdapter) {
                    systemAdapter.speak(normalizedSpeech, voice = voice, speed = rate)
                }

                // Wait for chunk duration + boundary pause
                val durationMs = (result.duration * 1000).toLong()
                delay(durationMs)

                if (reqId != coordinator.currentRequestID) break

                coordinator.onChunkCompleted(chunk)
            }
        }
    }

    fun pause() {
        playbackJob?.cancel()
        playbackJob = null
        systemAdapter.stop()
        coordinator.pause()
        soundscapePlayer.handleTTSPaused()
    }

    fun stop() {
        playbackJob?.cancel()
        playbackJob = null
        systemAdapter.stop()
        coordinator.stop()
        soundscapePlayer.handleTTSStopped()
    }

    fun skipForwardSentence() {
        val doc = coordinator.activeSemanticDocument.value ?: return
        val currentSId = coordinator.currentSentenceID.value ?: 0
        val nextSentence = doc.sentence(currentSId + 1) ?: return
        val firstWordId = nextSentence.words.firstOrNull()?.globalWordID ?: return

        val wasPlaying = coordinator.isPlaying.value
        pause()
        coordinator.seekToWord(firstWordId)
        if (wasPlaying) play()
    }

    fun skipBackwardSentence() {
        val doc = coordinator.activeSemanticDocument.value ?: return
        val currentSId = coordinator.currentSentenceID.value ?: 0
        val prevSentence = doc.sentence((currentSId - 1).coerceAtLeast(0)) ?: return
        val firstWordId = prevSentence.words.firstOrNull()?.globalWordID ?: return

        val wasPlaying = coordinator.isPlaying.value
        pause()
        coordinator.seekToWord(firstWordId)
        if (wasPlaying) play()
    }

    companion object {
        @Volatile
        private var instance: TTSController? = null

        fun getInstance(context: Context): TTSController {
            return instance ?: synchronized(this) {
                instance ?: TTSController(context.applicationContext).also { instance = it }
            }
        }
    }
}
