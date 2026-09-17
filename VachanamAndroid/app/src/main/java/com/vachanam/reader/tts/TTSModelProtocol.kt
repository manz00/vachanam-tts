package com.vachanam.reader.tts

import com.vachanam.reader.data.model.TTSAudioResult
import kotlinx.coroutines.flow.Flow
import java.io.File

data class TTSModelMetadata(
    val id: String,
    val name: String,
    val description: String,
    val sizeBytes: Long,
    val minRamGB: Int,
    val isBundled: Boolean,
    val supportedVoices: List<String>
)

interface TTSModelProtocol {
    val metadata: TTSModelMetadata
    val isLoaded: Boolean
    val hasNeuralWeights: Boolean

    suspend fun loadModel(weightsDirectory: File?)
    fun unloadModel()
    suspend fun synthesize(
        text: String,
        voice: String? = null,
        speed: Float = 1.0f,
        pauseDurationSec: Double = 0.0,
        targetWords: List<String>? = null
    ): TTSAudioResult

    fun streamSynthesize(
        text: String,
        voice: String? = null,
        speed: Float = 1.0f
    ): Flow<TTSAudioResult>
}
