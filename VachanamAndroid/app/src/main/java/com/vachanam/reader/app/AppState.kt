package com.vachanam.reader.app

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.vachanam.reader.audio.AmbientSoundscapePlayer
import com.vachanam.reader.data.model.DocumentFormat
import com.vachanam.reader.data.model.SemanticDocument
import com.vachanam.reader.data.parser.DocumentParserResolver
import com.vachanam.reader.data.parser.SemanticDocumentBuilder
import com.vachanam.reader.data.persistence.ReadingProgressTracker
import com.vachanam.reader.pdf.PdfTextExtractor
import com.vachanam.reader.tts.PlaybackCoordinator
import com.vachanam.reader.tts.TTSController
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream

class AppState(
    private val context: Context,
    val coordinator: PlaybackCoordinator = PlaybackCoordinator.shared,
    val ttsController: TTSController = TTSController.getInstance(context),
    val soundscapePlayer: AmbientSoundscapePlayer = AmbientSoundscapePlayer.getInstance(context),
    val progressTracker: ReadingProgressTracker = ReadingProgressTracker.getInstance(context)
) : ViewModel() {

    private val prefs = context.getSharedPreferences("vachanam_app_state", Context.MODE_PRIVATE)
    private val lastOpenedDocKey = "last_opened_document_path"
    private val hasLaunchedBeforeKey = "has_launched_before"

    private val _currentDocument = MutableStateFlow<SemanticDocument?>(null)
    val currentDocument: StateFlow<SemanticDocument?> = _currentDocument.asStateFlow()

    private val _currentDocumentFile = MutableStateFlow<File?>(null)
    val currentDocumentFile: StateFlow<File?> = _currentDocumentFile.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _selectedTab = MutableStateFlow("library")
    val selectedTab: StateFlow<String> = _selectedTab.asStateFlow()

    init {
        val hasLaunchedBefore = prefs.getBoolean(hasLaunchedBeforeKey, false)
        val savedPath = prefs.getString(lastOpenedDocKey, null)

        if (!hasLaunchedBefore) {
            prefs.edit().putBoolean(hasLaunchedBeforeKey, true).apply()
            // Auto-load benchmark PDF on first app launch
            viewModelScope.launch {
                val benchmarkFile = copyBenchmarkAssetToInternal()
                if (benchmarkFile != null) {
                    openDocument(benchmarkFile)
                }
            }
        } else if (savedPath != null) {
            val file = File(savedPath)
            if (file.exists()) {
                viewModelScope.launch {
                    openDocument(file)
                }
            }
        }
    }

    fun setSelectedTab(tab: String) {
        _selectedTab.value = tab
    }

    suspend fun openDocument(file: File) {
        _isLoading.value = true
        try {
            val format = DocumentFormat.detect(file)
            val doc = if (format == DocumentFormat.PDF) {
                PdfTextExtractor.shared.extractSemanticDocument(file)
            } else {
                val parsed = DocumentParserResolver.shared.parseFile(file)
                SemanticDocumentBuilder.shared.build(parsed)
            }

            _currentDocument.value = doc
            _currentDocumentFile.value = file
            coordinator.setDocument(doc)

            // Restore last reading page
            val savedPage = progressTracker.lastPage(file.absolutePath)
            val initialPage = savedPage.coerceIn(0, (doc.pageCount - 1).coerceAtLeast(0))
            coordinator.setVisiblePage(initialPage)

            // If last word was tracked, seek to it
            val lastWordID = progressTracker.progress(file.absolutePath)?.lastWordID
            if (lastWordID != null) {
                coordinator.seekToWord(lastWordID)
            }

            prefs.edit().putString(lastOpenedDocKey, file.absolutePath).apply()
            _selectedTab.value = "reader"
        } catch (_: Exception) {
            // Document open fallback
        } finally {
            _isLoading.value = false
        }
    }

    fun closeCurrentDocument() {
        val doc = _currentDocument.value
        val file = _currentDocumentFile.value
        if (doc != null && file != null) {
            val page = coordinator.visiblePageIndex.value
            val wordID = coordinator.currentWordID.value
            val sentenceID = coordinator.currentSentenceID.value

            progressTracker.recordProgress(
                documentUri = file.absolutePath,
                title = doc.title,
                currentPage = page,
                totalPages = doc.pageCount,
                lastWordID = wordID,
                lastSentenceID = sentenceID
            )
        }

        ttsController.stop()
        coordinator.setDocument(null)
        _currentDocument.value = null
        _currentDocumentFile.value = null
        prefs.edit().remove(lastOpenedDocKey).apply()
        _selectedTab.value = "library"
    }

    fun play() {
        ttsController.play()
    }

    fun pause() {
        ttsController.pause()
    }

    private fun copyBenchmarkAssetToInternal(): File? {
        return try {
            val outFile = File(context.filesDir, "The_Ultimate_Multi_Discipline_TTS_Benchmark.pdf")
            if (!outFile.exists()) {
                context.assets.open("Benchmark/The_Ultimate_Multi_Discipline_TTS_Benchmark.pdf").use { input ->
                    FileOutputStream(outFile).use { output ->
                        input.copyTo(output)
                    }
                }
            }
            outFile
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        @Volatile
        private var instance: AppState? = null

        fun getInstance(context: Context): AppState {
            return instance ?: synchronized(this) {
                instance ?: AppState(context.applicationContext).also { instance = it }
            }
        }
    }
}
