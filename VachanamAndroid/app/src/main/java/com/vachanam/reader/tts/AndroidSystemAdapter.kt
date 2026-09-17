package com.vachanam.reader.tts

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.vachanam.reader.data.model.TTSAudioResult
import com.vachanam.reader.data.model.WordTimestamp
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Locale
import java.util.UUID

class AndroidSystemAdapter(
    private val context: Context
) : TTSModelProtocol, TextToSpeech.OnInitListener {

    override val metadata: TTSModelMetadata = TTSModelMetadata(
        id = "android_system",
        name = "Android System TTS",
        description = "Built-in offline Android speech synthesis engine (zero download).",
        sizeBytes = 0L,
        minRamGB = 2,
        isBundled = true,
        supportedVoices = listOf("default", "en-us-x-sfg", "en-us-x-tpd")
    )

    override var isLoaded: Boolean = false
        private set

    override val hasNeuralWeights: Boolean = false

    private var tts: TextToSpeech? = null
    private var initDeferred = CompletableDeferred<Boolean>()

    // Callback for real-time word boundary notifications during live speech
    var onWordSpokenRange: ((start: Int, end: Int) -> Unit)? = null

    init {
        tts = TextToSpeech(context.applicationContext, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.US
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {}
                override fun onError(utteranceId: String?) {}

                override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
                    onWordSpokenRange?.invoke(start, end)
                }
            })
            isLoaded = true
            initDeferred.complete(true)
        } else {
            isLoaded = false
            initDeferred.complete(false)
        }
    }

    override suspend fun loadModel(weightsDirectory: File?) {
        initDeferred.await()
    }

    override fun unloadModel() {
        // System TTS remains initialized
    }

    fun speak(text: String, speed: Float = 1.0f, pitch: Float = 1.0f) {
        tts?.setSpeechRate(speed)
        tts?.setPitch(pitch)
        val utteranceId = UUID.randomUUID().toString()
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    fun stop() {
        tts?.stop()
    }

    override suspend fun synthesize(
        text: String,
        voice: String?,
        speed: Float,
        pauseDurationSec: Double,
        targetWords: List<String>?
    ): TTSAudioResult = withContext(Dispatchers.Default) {
        initDeferred.await()

        // Generate synthetic word timestamps based on speech rate (~160 WPM / 2.6 words per second at 1.0x)
        val words = targetWords ?: text.split("\\s+".toRegex()).filter { it.isNotEmpty() }
        val effectiveRate = (2.6f * speed).coerceAtLeast(0.5f)
        val wordDuration = 1.0 / effectiveRate

        var currentTime = 0.0
        val timestamps = mutableListOf<WordTimestamp>()

        for (w in words) {
            val start = currentTime
            val end = start + wordDuration
            timestamps.add(WordTimestamp(word = w, startTime = start, endTime = end))
            currentTime = end
        }

        val totalDuration = currentTime + pauseDurationSec
        // For system adapter, return lightweight result representing duration & timings
        TTSAudioResult(
            audioData = ByteArray(0),
            sampleRate = 24000.0,
            duration = totalDuration,
            wordTimestamps = timestamps
        )
    }

    override fun streamSynthesize(
        text: String,
        voice: String?,
        speed: Float
    ): Flow<TTSAudioResult> = flow {
        emit(synthesize(text, voice, speed))
    }

    fun release() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        isLoaded = false
    }
}
