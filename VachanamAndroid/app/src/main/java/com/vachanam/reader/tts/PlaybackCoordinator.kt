package com.vachanam.reader.tts

import com.vachanam.reader.data.model.SemanticDocument
import com.vachanam.reader.data.model.TTSChunk
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

sealed class PlaybackScope {
    object Document : PlaybackScope()
    data class Page(val pageIndex: Int) : PlaybackScope()
    data class Selection(val wordIDs: List<Int>) : PlaybackScope()
}

data class PlaybackCursor(
    val documentID: String,
    val pageIndex: Int,
    val sentenceIndex: Int,
    val wordIndex: Int,
    val globalWordID: Int
)

class PlaybackCoordinator {

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _cursor = MutableStateFlow<PlaybackCursor?>(null)
    val cursor: StateFlow<PlaybackCursor?> = _cursor.asStateFlow()

    private val _activeSemanticDocument = MutableStateFlow<SemanticDocument?>(null)
    val activeSemanticDocument: StateFlow<SemanticDocument?> = _activeSemanticDocument.asStateFlow()

    private val _currentChunk = MutableStateFlow<TTSChunk?>(null)
    val currentChunk: StateFlow<TTSChunk?> = _currentChunk.asStateFlow()

    private val _currentWordID = MutableStateFlow<Int?>(null)
    val currentWordID: StateFlow<Int?> = _currentWordID.asStateFlow()

    private val _currentSentenceID = MutableStateFlow<Int?>(null)
    val currentSentenceID: StateFlow<Int?> = _currentSentenceID.asStateFlow()

    private val _visiblePageIndex = MutableStateFlow(0)
    val visiblePageIndex: StateFlow<Int> = _visiblePageIndex.asStateFlow()

    var playbackScope: PlaybackScope = PlaybackScope.Document
    var currentRequestID: String = UUID.randomUUID().toString()
        private set

    fun setDocument(document: SemanticDocument?) {
        _activeSemanticDocument.value = document
        if (document == null) {
            stop()
            _cursor.value = null
        }
    }

    fun setVisiblePage(pageIndex: Int) {
        _visiblePageIndex.value = pageIndex
    }

    fun seekToWord(wordID: Int) {
        currentRequestID = UUID.randomUUID().toString()
        val doc = _activeSemanticDocument.value ?: return
        val word = doc.word(wordID) ?: return

        _currentWordID.value = word.globalWordID
        _currentSentenceID.value = word.sentenceID
        _cursor.value = PlaybackCursor(
            documentID = doc.documentID,
            pageIndex = word.pageIndex,
            sentenceIndex = word.sentenceID,
            wordIndex = word.wordIndexInSentence,
            globalWordID = word.globalWordID
        )

        val chunk = doc.chunkForWord(word.globalWordID)
        _currentChunk.value = chunk
    }

    fun updateWordHighlight(wordID: Int) {
        val doc = _activeSemanticDocument.value ?: return
        val word = doc.word(wordID) ?: return

        _currentWordID.value = word.globalWordID
        _currentSentenceID.value = word.sentenceID
        _cursor.value = PlaybackCursor(
            documentID = doc.documentID,
            pageIndex = word.pageIndex,
            sentenceIndex = word.sentenceID,
            wordIndex = word.wordIndexInSentence,
            globalWordID = word.globalWordID
        )
    }

    fun onChunkCompleted(chunk: TTSChunk) {
        val doc = _activeSemanticDocument.value ?: return

        when (val scope = playbackScope) {
            is PlaybackScope.Page -> {
                // If page scope, check if this was the last chunk of this page
                val pageChunks = doc.chunksForPage(scope.pageIndex)
                if (chunk.chunkID == pageChunks.lastOrNull()?.chunkID) {
                    stop()
                    return
                }
            }
            is PlaybackScope.Selection -> {
                stop()
                return
            }
            is PlaybackScope.Document -> {
                // If document scope, check if this was the final chunk of the entire document
                if (chunk.chunkID == doc.chunks.lastOrNull()?.chunkID) {
                    stop()
                    return
                }
            }
        }

        // Advance to next chunk
        val nextChunkID = chunk.chunkID + 1
        val nextChunk = doc.chunk(nextChunkID)
        if (nextChunk != null) {
            _currentChunk.value = nextChunk
            val firstWordID = nextChunk.wordIDs.firstOrNull()
            if (firstWordID != null) {
                updateWordHighlight(firstWordID)
            }
        } else {
            stop()
        }
    }

    fun startPlaying() {
        _isPlaying.value = true
    }

    fun pause() {
        _isPlaying.value = false
    }

    fun stop() {
        _isPlaying.value = false
        _currentWordID.value = null
        _currentSentenceID.value = null
        _currentChunk.value = null
    }

    companion object {
        val shared = PlaybackCoordinator()
    }
}
