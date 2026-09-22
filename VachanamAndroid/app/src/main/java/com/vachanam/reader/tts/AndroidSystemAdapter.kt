package com.vachanam.reader.tts

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.vachanam.reader.data.model.TTSAudioResult
import com.vachanam.reader.data.model.WordTimestamp
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
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

    enum class Gender { MALE, FEMALE, NEUTRAL }

    data class VoiceItem(
        val id: String,
        val displayName: String,
        val description: String,
        val gender: Gender,
        val locale: Locale,
        val isNetwork: Boolean
    )

    private val _installedVoiceItems = kotlinx.coroutines.flow.MutableStateFlow<List<VoiceItem>>(emptyList())
    val installedVoiceItems: kotlinx.coroutines.flow.StateFlow<List<VoiceItem>> = _installedVoiceItems.asStateFlow()

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
            refreshInstalledVoices()
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

    fun refreshInstalledVoices() {
        try {
            val allVoices = tts?.voices ?: emptySet()
            android.util.Log.i("VachanamTTS", "TTS initialized. Default Engine: ${tts?.defaultEngine}, total voices=${allVoices.size}")
            val localVoiceNames = allVoices.filter { !it.isNetworkConnectionRequired }.map { it.name }.toSet()
            val enVoices = allVoices.filter {
                (it.locale.language == "en" || it.locale.language == Locale.getDefault().language) &&
                !it.name.endsWith("-language")
            }.filter { voice ->
                // If it's a network voice, skip if a local offline version exists
                if (voice.isNetworkConnectionRequired) {
                    val localEquivalent = voice.name.replace("-network", "-local")
                    !localVoiceNames.contains(localEquivalent)
                } else {
                    true
                }
            }.sortedWith(compareBy({ it.isNetworkConnectionRequired }, { it.name }))

            val items = mutableListOf<VoiceItem>()
            items.add(
                VoiceItem(
                    id = "default",
                    displayName = "System Default Voice",
                    description = "Default device synthesizer profile",
                    gender = Gender.NEUTRAL,
                    locale = Locale.getDefault(),
                    isNetwork = false
                )
            )

            enVoices.forEach { voice ->
                val gender = detectGender(voice)
                val langTag = voice.locale.toLanguageTag()
                val friendlyName = when {
                    voice.name.contains("-sfg") -> "Natural Female 1 (Warm)"
                    voice.name.contains("-iob") -> "Natural Female 2 (Clear)"
                    voice.name.contains("-tpc") -> "Natural Female 3 (Bright)"
                    voice.name.contains("-tpf") -> "Natural Female 4 (Gentle)"
                    voice.name.contains("-iog") -> "Natural Female 5 (Casual)"
                    voice.name.contains("-tpd") -> "Natural Male 1 (Deep Baritone)"
                    voice.name.contains("-iol") -> "Natural Male 2 (Warm & Steady)"
                    voice.name.contains("-iom") -> "Natural Male 3 (Conversational)"
                    voice.name.contains("-rjs") -> "British Male (Narrator)"
                    voice.name.contains("-gbb") -> "British Male (Refined)"
                    voice.name.contains("-gbd") -> "British Male (Deep)"
                    voice.name.contains("-gba") -> "British Female (Articulate)"
                    voice.name.contains("-gbc") -> "British Female (Warm)"
                    voice.name.contains("-gbg") -> "British Female (Soft)"
                    voice.name.contains("-fis") -> "British Female (Classic)"
                    voice.name.contains("-aub") -> "Australian Male"
                    voice.name.contains("-aud") -> "Australian Male (Deep)"
                    voice.name.contains("-aua") -> "Australian Female"
                    voice.name.contains("-auc") -> "Australian Female (Soft)"
                    voice.name.contains("-ena") -> "Indian English 1 (Female)"
                    voice.name.contains("-enc") -> "Indian English 2 (Male)"
                    voice.name.contains("-end") -> "Indian English 3 (Male)"
                    voice.name.contains("-ene") -> "Indian English 4 (Female)"
                    voice.name.contains("-tfn") -> "Nigerian English"
                    voice.name.contains("_m0") -> "Samsung Male"
                    voice.name.contains("_f0") -> "Samsung Female"
                    else -> {
                        val simple = voice.name.substringAfterLast("-").substringAfterLast("_")
                        val gStr = when (gender) {
                            Gender.MALE -> "Male"
                            Gender.FEMALE -> "Female"
                            Gender.NEUTRAL -> "Voice"
                        }
                        "$gStr ($simple)"
                    }
                }
                val offlineLabel = if (voice.isNetworkConnectionRequired) "Cloud Network" else "High Definition Offline"
                items.add(
                    VoiceItem(
                        id = voice.name,
                        displayName = friendlyName,
                        description = "$langTag · $offlineLabel",
                        gender = gender,
                        locale = voice.locale,
                        isNetwork = voice.isNetworkConnectionRequired
                    )
                )
                android.util.Log.i("VachanamTTS", "  -> Voice: ${voice.name}, gender=$gender, network=${voice.isNetworkConnectionRequired}")
            }
            _installedVoiceItems.value = items
        } catch (e: Exception) {
            android.util.Log.e("VachanamTTS", "Error refreshing voices", e)
        }
    }

    fun detectGenderByName(rawName: String): Gender {
        val name = rawName.lowercase()
        if (name.startsWith("am_") || name.startsWith("bm_")) return Gender.MALE
        if (name.startsWith("af_") || name.startsWith("bf_")) return Gender.FEMALE

        if (name.contains("-sfg") || name.contains("-iob") || name.contains("-tpc") ||
            name.contains("-tpf") || name.contains("-iog") ||
            name.contains("-fis") || name.contains("-gba") || name.contains("-gbc") || name.contains("-gbg") ||
            name.contains("-aua") || name.contains("-auc") || name.contains("-afh") ||
            name.contains("_f0") || name.contains("_f1") || name.contains("-f-") ||
            name.contains("female") || name.contains("fem")) {
            return Gender.FEMALE
        }

        if (name.contains("-tpd") || name.contains("-iol") || name.contains("-iom") ||
            name.contains("-rjs") || name.contains("-gbb") || name.contains("-gbd") ||
            name.contains("-aub") || name.contains("-aud") ||
            name.contains("_m0") || name.contains("_m1") || name.contains("-m-") ||
            (name.contains("male") && !name.contains("female"))) {
            return Gender.MALE
        }

        return Gender.NEUTRAL
    }

    fun detectGender(voice: android.speech.tts.Voice): Gender {
        val features = voice.features ?: emptySet()
        if (features.any { it.contains("female", ignoreCase = true) }) return Gender.FEMALE
        if (features.any { it.contains("male", ignoreCase = true) && !it.contains("female", ignoreCase = true) }) return Gender.MALE
        return detectGenderByName(voice.name)
    }

    fun getAvailableVoices(): List<String> {
        return try {
            val vList = tts?.voices
                ?.filter { it.locale.language == "en" || it.locale.language == Locale.getDefault().language }
                ?.map { it.name }
                ?.sorted()
            if (!vList.isNullOrEmpty()) vList else metadata.supportedVoices
        } catch (_: Exception) {
            metadata.supportedVoices
        }
    }

    fun setVoiceAndStyle(voiceName: String?): Pair<Float, Float> {
        var pitchMul = 1.0f
        var speedMul = 1.0f

        if (voiceName == null || voiceName == "default") {
            try {
                tts?.language = Locale.US
            } catch (_: Exception) {}
            return Pair(speedMul, pitchMul)
        }

        when (voiceName) {
            "af_heart" -> {
                pitchMul = 1.02f
                speedMul = 1.0f
                findInstalledVoice(gender = "female", locale = Locale.US, variantIndex = 0)?.let { applyVoice(it) }
            }
            "af_bella" -> {
                pitchMul = 1.03f
                speedMul = 1.02f
                findInstalledVoice(gender = "female", locale = Locale.US, variantIndex = 1)?.let { applyVoice(it) }
            }
            "am_adam" -> {
                pitchMul = 0.98f
                speedMul = 1.0f
                findInstalledVoice(gender = "male", locale = Locale.US, variantIndex = 0)?.let { applyVoice(it) }
            }
            "am_michael" -> {
                pitchMul = 0.95f
                speedMul = 0.98f
                findInstalledVoice(gender = "male", locale = Locale.US, variantIndex = 1)?.let { applyVoice(it) }
            }
            "bf_emma" -> {
                pitchMul = 1.02f
                speedMul = 1.0f
                val ukVoice = findInstalledVoice(gender = "female", locale = Locale.UK)
                    ?: findInstalledVoice(gender = "female", locale = Locale.US, variantIndex = 2)
                ukVoice?.let { applyVoice(it) }
            }
            "bm_george" -> {
                pitchMul = 0.96f
                speedMul = 0.97f
                val ukVoice = findInstalledVoice(gender = "male", locale = Locale.UK)
                    ?: findInstalledVoice(gender = "male", locale = Locale.US, variantIndex = 2)
                ukVoice?.let { applyVoice(it) }
            }
            else -> {
                // Direct installed voice name match
                try {
                    val match = tts?.voices?.firstOrNull { it.name == voiceName }
                    if (match != null) {
                        applyVoice(match)
                    }
                } catch (_: Exception) {}
            }
        }
        return Pair(speedMul, pitchMul)
    }

    private fun applyVoice(voice: android.speech.tts.Voice) {
        try {
            val res = tts?.setVoice(voice)
            android.util.Log.i("VachanamTTS", "applyVoice: ${voice.name} (gender=${detectGender(voice)}) -> result=$res, activeVoice=${tts?.voice?.name}")
        } catch (e: Exception) {
            android.util.Log.e("VachanamTTS", "applyVoice failed for ${voice.name}", e)
        }
    }

    private fun findInstalledVoice(gender: String, locale: Locale, variantIndex: Int = 0): android.speech.tts.Voice? {
        val all = tts?.voices ?: return null
        val targetGender = if (gender.equals("female", ignoreCase = true)) Gender.FEMALE else Gender.MALE

        // 1. In country matches, preferring local offline voices
        val inCountry = all.filter {
            it.locale.language == locale.language &&
            it.locale.country.equals(locale.country, ignoreCase = true) &&
            detectGender(it) == targetGender
        }.sortedWith(compareBy({ it.isNetworkConnectionRequired }, { it.name }))

        if (inCountry.isNotEmpty()) {
            return inCountry.getOrNull(variantIndex) ?: inCountry.first()
        }

        // 2. In language matches
        val inLang = all.filter {
            it.locale.language == locale.language &&
            detectGender(it) == targetGender
        }.sortedWith(compareBy({ it.isNetworkConnectionRequired }, { it.name }))

        if (inLang.isNotEmpty()) {
            return inLang.getOrNull(variantIndex) ?: inLang.first()
        }

        // 3. Fallback: pick distinct voices in pool so male and female never play the exact same voice
        val pool = all.filter { it.locale.language == locale.language }
            .sortedWith(compareBy({ it.isNetworkConnectionRequired }, { it.name }))

        return if (targetGender == Gender.MALE && pool.size > 1) {
            pool.getOrNull(1) ?: pool.firstOrNull()
        } else {
            pool.firstOrNull()
        }
    }

    fun setVoice(voiceName: String?) {
        setVoiceAndStyle(voiceName)
    }

    fun speak(text: String, voice: String? = null, speed: Float = 1.0f, pitch: Float = 1.0f) {
        val (speedMul, pitchMul) = setVoiceAndStyle(voice)
        tts?.setSpeechRate((speed * speedMul).coerceIn(0.5f, 2.5f))
        tts?.setPitch((pitch * pitchMul).coerceIn(0.5f, 2.0f))
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
