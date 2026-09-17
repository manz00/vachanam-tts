package com.vachanam.reader.pdf

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class BookmarkManager(private val context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_bookmarks", Context.MODE_PRIVATE)

    private val _bookmarksByDoc = MutableStateFlow<Map<String, Set<Int>>>(emptyMap())
    val bookmarksByDoc: StateFlow<Map<String, Set<Int>>> = _bookmarksByDoc.asStateFlow()

    init {
        loadAll()
    }

    private fun loadAll() {
        val result = mutableMapOf<String, Set<Int>>()
        for ((key, value) in prefs.all) {
            if (value is String) {
                val pages = value.split(",")
                    .mapNotNull { it.trim().toIntOrNull() }
                    .toSet()
                result[key] = pages
            }
        }
        _bookmarksByDoc.value = result
    }

    fun isBookmarked(documentId: String, pageIndex: Int): Boolean {
        return _bookmarksByDoc.value[documentId]?.contains(pageIndex) == true
    }

    fun toggleBookmark(documentId: String, pageIndex: Int) {
        val current = _bookmarksByDoc.value[documentId]?.toMutableSet() ?: mutableSetOf()
        if (current.contains(pageIndex)) {
            current.remove(pageIndex)
        } else {
            current.add(pageIndex)
        }

        prefs.edit().putString(documentId, current.joinToString(",")).apply()

        val updated = _bookmarksByDoc.value.toMutableMap()
        updated[documentId] = current
        _bookmarksByDoc.value = updated
    }

    fun bookmarksForDocument(documentId: String): List<Int> {
        return _bookmarksByDoc.value[documentId]?.sorted() ?: emptyList()
    }

    companion object {
        @Volatile
        private var instance: BookmarkManager? = null

        fun getInstance(context: Context): BookmarkManager {
            return instance ?: synchronized(this) {
                instance ?: BookmarkManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
