package com.vachanam.reader.data.model

data class WordTimestamp(
    val word: String,
    val startTime: Double,
    val endTime: Double
) {
    val id: String get() = "${word}_$startTime"
}

data class TTSAudioResult(
    val audioData: ByteArray,
    val sampleRate: Double = 24000.0,
    val duration: Double,
    val wordTimestamps: List<WordTimestamp> = emptyList()
) {
    fun withAppendedSilence(durationSec: Double): TTSAudioResult {
        if (durationSec <= 0.0) return this
        val silentSampleCount = (sampleRate * durationSec).toInt()
        if (silentSampleCount <= 0) return this
        val zeroBytes = ByteArray(silentSampleCount * 2) // 16-bit PCM silence
        val newAudio = audioData + zeroBytes
        return copy(
            audioData = newAudio,
            duration = this.duration + durationSec
        )
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as TTSAudioResult
        return audioData.contentEquals(other.audioData) &&
                sampleRate == other.sampleRate &&
                duration == other.duration &&
                wordTimestamps == other.wordTimestamps
    }

    override fun hashCode(): Int {
        var result = audioData.contentHashCode()
        result = 31 * result + sampleRate.hashCode()
        result = 31 * result + duration.hashCode()
        result = 31 * result + wordTimestamps.hashCode()
        return result
    }
}
