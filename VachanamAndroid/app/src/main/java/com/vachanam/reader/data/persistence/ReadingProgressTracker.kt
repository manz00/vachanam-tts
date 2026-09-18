package com.vachanam.reader.data.persistence

import android.content.Context
import org.json.JSONObject

data class ReadingProgress(
    val documentUri: String,
    val title: String,
    val currentPage: Int,
    val totalPages: Int,
    val lastWordID: Int? = null,
    val lastSentenceID: Int? = null,
    val lastReadTimestamp: Long = System.currentTimeMillis()
)

class ReadingProgressTracker(context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_reading_progress", Context.MODE_PRIVATE)

    fun recordProgress(
        documentUri: String,
        title: String,
        currentPage: Int,
        totalPages: Int,
        lastWordID: Int? = null,
        lastSentenceID: Int? = null
    ) {
        val json = JSONObject().apply {
            put("documentUri", documentUri)
            put("title", title)
            put("currentPage", currentPage)
            put("totalPages", totalPages)
            if (lastWordID != null) put("lastWordID", lastWordID)
            if (lastSentenceID != null) put("lastSentenceID", lastSentenceID)
            put("lastReadTimestamp", System.currentTimeMillis())
        }
        prefs.edit().putString(documentUri, json.toString()).apply()
    }

    fun progress(documentUri: String): ReadingProgress? {
        val raw = prefs.getString(documentUri, null) ?: return null
        return try {
            val json = JSONObject(raw)
            ReadingProgress(
                documentUri = json.getString("documentUri"),
                title = json.getString("title"),
                currentPage = json.getInt("currentPage"),
                totalPages = json.getInt("totalPages"),
                lastWordID = if (json.has("lastWordID")) json.getInt("lastWordID") else null,
                lastSentenceID = if (json.has("lastSentenceID")) json.getInt("lastSentenceID") else null,
                lastReadTimestamp = json.optLong("lastReadTimestamp", 0L)
            )
        } catch (_: Exception) {
            null
        }
    }

    fun lastPage(documentUri: String): Int {
        return progress(documentUri)?.currentPage ?: 0
    }

    fun allRecentDocuments(): List<ReadingProgress> {
        val list = mutableListOf<ReadingProgress>()
        for ((_, value) in prefs.all) {
            if (value is String) {
                try {
                    val json = JSONObject(value)
                    list.add(
                        ReadingProgress(
                            documentUri = json.getString("documentUri"),
                            title = json.getString("title"),
                            currentPage = json.getInt("currentPage"),
                            totalPages = json.getInt("totalPages"),
                            lastWordID = if (json.has("lastWordID")) json.getInt("lastWordID") else null,
                            lastSentenceID = if (json.has("lastSentenceID")) json.getInt("lastSentenceID") else null,
                            lastReadTimestamp = json.optLong("lastReadTimestamp", 0L)
                        )
                    )
                } catch (_: Exception) {}
            }
        }
        return list.sortedByDescending { it.lastReadTimestamp }
    }

    fun removeProgress(documentUri: String) {
        prefs.edit().remove(documentUri).apply()
    }

    companion object {
        @Volatile
        private var instance: ReadingProgressTracker? = null

        fun getInstance(context: Context): ReadingProgressTracker {
            return instance ?: synchronized(this) {
                instance ?: ReadingProgressTracker(context.applicationContext).also { instance = it }
            }
        }
    }
}
