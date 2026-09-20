package com.vachanam.reader.data.persistence

import android.content.Context
import android.net.Uri
import com.vachanam.reader.data.model.DocumentFormat
import com.vachanam.reader.data.parser.DocumentParserResolver
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlin.math.ceil
import kotlin.math.max

data class ChapterPreparationSummary(
    val chapterIndex: Int,
    val title: String,
    val wordCount: Int,
    val estimatedAudioMinutes: Int
)

data class BookPreparationRecord(
    val documentUri: String,
    val wordCount: Int,
    val chapterCount: Int,
    val estimatedReadingMinutes: Int,
    val estimatedAudioMinutes: Int,
    val chapterSummaries: List<ChapterPreparationSummary>,
    val preparedDate: Long = System.currentTimeMillis()
)

class BookPreparationService(private val context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_prepared_books", Context.MODE_PRIVATE)

    private val _preparedRecords = MutableStateFlow<Map<String, BookPreparationRecord>>(emptyMap())
    val preparedRecords: StateFlow<Map<String, BookPreparationRecord>> = _preparedRecords.asStateFlow()

    private val _activelyPreparingUris = MutableStateFlow<Set<String>>(emptySet())
    val activelyPreparingUris: StateFlow<Set<String>> = _activelyPreparingUris.asStateFlow()

    init {
        loadData()
    }

    fun isPrepared(uri: String): Boolean = _preparedRecords.value.containsKey(uri)
    fun isPreparing(uri: String): Boolean = _activelyPreparingUris.value.contains(uri)
    fun record(uri: String): BookPreparationRecord? = _preparedRecords.value[uri]

    suspend fun prepareBook(uriString: String, file: File? = null): BookPreparationRecord = withContext(Dispatchers.IO) {
        _activelyPreparingUris.value = _activelyPreparingUris.value + uriString
        try {
            val targetFile = file ?: if (uriString.startsWith("file://") || uriString.startsWith("/")) {
                File(Uri.parse(uriString).path ?: uriString)
            } else null

            var totalWords = 0
            val chapterSummaries = mutableListOf<ChapterPreparationSummary>()

            if (targetFile != null && targetFile.exists()) {
                val format = DocumentFormat.detect(targetFile)
                if (format == DocumentFormat.PDF) {
                    totalWords = max((targetFile.length() / 12).toInt(), 300)
                    val audioMin = max(ceil(totalWords.toDouble() / 150.0).toInt(), 1)
                    chapterSummaries.add(
                        ChapterPreparationSummary(
                            chapterIndex = 0,
                            title = targetFile.nameWithoutExtension,
                            wordCount = totalWords,
                            estimatedAudioMinutes = audioMin
                        )
                    )
                } else {
                    val parsed = DocumentParserResolver.shared.parseFile(targetFile)
                    parsed.chapters.forEachIndexed { idx, ch ->
                        var chWords = 0
                        ch.blocks.forEach { b ->
                            val words = b.text.split("\\s+".toRegex()).filter { it.isNotEmpty() }
                            chWords += words.size
                        }
                        totalWords += chWords
                        val chAudioMin = max(ceil(chWords.toDouble() / 150.0).toInt(), 1)
                        chapterSummaries.add(
                            ChapterPreparationSummary(
                                chapterIndex = idx,
                                title = ch.title?.takeIf { it.isNotBlank() } ?: "Chapter ${idx + 1}",
                                wordCount = chWords,
                                estimatedAudioMinutes = chAudioMin
                            )
                        )
                    }
                }
            } else {
                totalWords = 500
                chapterSummaries.add(
                    ChapterPreparationSummary(0, "Introduction", 500, 3)
                )
            }

            val readMin = max(ceil(totalWords.toDouble() / 225.0).toInt(), 1)
            val audioMin = max(ceil(totalWords.toDouble() / 150.0).toInt(), 1)

            val record = BookPreparationRecord(
                documentUri = uriString,
                wordCount = totalWords,
                chapterCount = chapterSummaries.size,
                estimatedReadingMinutes = readMin,
                estimatedAudioMinutes = audioMin,
                chapterSummaries = chapterSummaries
            )

            val current = _preparedRecords.value.toMutableMap()
            current[uriString] = record
            _preparedRecords.value = current
            saveData()

            record
        } finally {
            _activelyPreparingUris.value = _activelyPreparingUris.value - uriString
        }
    }

    fun deletePreparation(uriString: String) {
        val current = _preparedRecords.value.toMutableMap()
        current.remove(uriString)
        _preparedRecords.value = current
        saveData()
    }

    private fun saveData() {
        val root = JSONObject()
        for ((uri, record) in _preparedRecords.value) {
            val recObj = JSONObject().apply {
                put("documentUri", record.documentUri)
                put("wordCount", record.wordCount)
                put("chapterCount", record.chapterCount)
                put("estimatedReadingMinutes", record.estimatedReadingMinutes)
                put("estimatedAudioMinutes", record.estimatedAudioMinutes)
                put("preparedDate", record.preparedDate)

                val chArr = JSONArray()
                record.chapterSummaries.forEach { ch ->
                    val chObj = JSONObject().apply {
                        put("chapterIndex", ch.chapterIndex)
                        put("title", ch.title)
                        put("wordCount", ch.wordCount)
                        put("estimatedAudioMinutes", ch.estimatedAudioMinutes)
                    }
                    chArr.put(chObj)
                }
                put("chapterSummaries", chArr)
            }
            root.put(uri, recObj)
        }
        prefs.edit().putString("records", root.toString()).apply()
    }

    private fun loadData() {
        prefs.getString("records", null)?.let { raw ->
            try {
                val root = JSONObject(raw)
                val map = mutableMapOf<String, BookPreparationRecord>()
                val keys = root.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val obj = root.getJSONObject(key)
                    val chList = mutableListOf<ChapterPreparationSummary>()
                    val chArr = obj.optJSONArray("chapterSummaries")
                    if (chArr != null) {
                        for (i in 0 until chArr.length()) {
                            val cObj = chArr.getJSONObject(i)
                            chList.add(
                                ChapterPreparationSummary(
                                    chapterIndex = cObj.getInt("chapterIndex"),
                                    title = cObj.getString("title"),
                                    wordCount = cObj.getInt("wordCount"),
                                    estimatedAudioMinutes = cObj.getInt("estimatedAudioMinutes")
                                )
                            )
                        }
                    }
                    map[key] = BookPreparationRecord(
                        documentUri = obj.getString("documentUri"),
                        wordCount = obj.getInt("wordCount"),
                        chapterCount = obj.getInt("chapterCount"),
                        estimatedReadingMinutes = obj.getInt("estimatedReadingMinutes"),
                        estimatedAudioMinutes = obj.getInt("estimatedAudioMinutes"),
                        chapterSummaries = chList,
                        preparedDate = obj.optLong("preparedDate", 0L)
                    )
                }
                _preparedRecords.value = map
            } catch (_: Exception) {}
        }
    }

    companion object {
        @Volatile
        private var instance: BookPreparationService? = null

        fun getInstance(context: Context): BookPreparationService {
            return instance ?: synchronized(this) {
                instance ?: BookPreparationService(context.applicationContext).also { instance = it }
            }
        }
    }
}
