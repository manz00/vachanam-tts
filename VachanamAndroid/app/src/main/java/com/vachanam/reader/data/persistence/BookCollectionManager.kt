package com.vachanam.reader.data.persistence

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

data class BookShelf(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val iconName: String = "books.vertical",
    val documentUris: Set<String> = emptySet()
)

class BookCollectionManager(private val context: Context) {
    private val prefs = context.getSharedPreferences("vachanam_collections", Context.MODE_PRIVATE)

    private val _customShelves = MutableStateFlow<List<BookShelf>>(emptyList())
    val customShelves: StateFlow<List<BookShelf>> = _customShelves.asStateFlow()

    private val _favoriteUris = MutableStateFlow<Set<String>>(emptySet())
    val favoriteUris: StateFlow<Set<String>> = _favoriteUris.asStateFlow()

    private val _finishedUris = MutableStateFlow<Set<String>>(emptySet())
    val finishedUris: StateFlow<Set<String>> = _finishedUris.asStateFlow()

    init {
        loadData()
    }

    fun isFavorite(uri: String): Boolean = _favoriteUris.value.contains(uri)

    fun toggleFavorite(uri: String) {
        val current = _favoriteUris.value.toMutableSet()
        if (current.contains(uri)) {
            current.remove(uri)
        } else {
            current.add(uri)
        }
        _favoriteUris.value = current
        saveData()
    }

    fun isFinished(uri: String): Boolean = _finishedUris.value.contains(uri)

    fun toggleFinished(uri: String) {
        val current = _finishedUris.value.toMutableSet()
        if (current.contains(uri)) {
            current.remove(uri)
        } else {
            current.add(uri)
        }
        _finishedUris.value = current
        saveData()
    }

    fun createShelf(name: String, iconName: String = "books.vertical"): BookShelf {
        val trimmed = name.trim()
        val finalName = if (trimmed.isEmpty()) "New Shelf" else trimmed
        val shelf = BookShelf(name = finalName, iconName = iconName)
        val current = _customShelves.value.toMutableList()
        current.add(shelf)
        _customShelves.value = current
        saveData()
        return shelf
    }

    fun deleteShelf(shelfId: String) {
        _customShelves.value = _customShelves.value.filter { it.id != shelfId }
        saveData()
    }

    fun addDocumentToShelf(uri: String, shelfId: String) {
        _customShelves.value = _customShelves.value.map { shelf ->
            if (shelf.id == shelfId) {
                shelf.copy(documentUris = shelf.documentUris + uri)
            } else {
                shelf
            }
        }
        saveData()
    }

    fun removeDocumentFromShelf(uri: String, shelfId: String) {
        _customShelves.value = _customShelves.value.map { shelf ->
            if (shelf.id == shelfId) {
                shelf.copy(documentUris = shelf.documentUris - uri)
            } else {
                shelf
            }
        }
        saveData()
    }

    fun deleteDocument(uriString: String) {
        // 1. Remove file from internal storage if local
        try {
            val file = if (uriString.startsWith("file://")) {
                File(Uri.parse(uriString).path ?: uriString)
            } else {
                File(uriString)
            }
            if (file.exists()) {
                file.delete()
            }
        } catch (_: Exception) {}

        // 2. Remove progress
        ReadingProgressTracker.getInstance(context).removeProgress(uriString)

        // 3. Remove from favorites & finished
        _favoriteUris.value = _favoriteUris.value - uriString
        _finishedUris.value = _finishedUris.value - uriString

        // 4. Remove from all shelves
        _customShelves.value = _customShelves.value.map { shelf ->
            shelf.copy(documentUris = shelf.documentUris - uriString)
        }

        saveData()
    }

    private fun saveData() {
        val shelvesArray = JSONArray()
        for (shelf in _customShelves.value) {
            val obj = JSONObject().apply {
                put("id", shelf.id)
                put("name", shelf.name)
                put("iconName", shelf.iconName)
                val uris = JSONArray()
                shelf.documentUris.forEach { uris.put(it) }
                put("documentUris", uris)
            }
            shelvesArray.put(obj)
        }

        val favs = JSONArray()
        _favoriteUris.value.forEach { favs.put(it) }

        val fins = JSONArray()
        _finishedUris.value.forEach { fins.put(it) }

        prefs.edit()
            .putString("shelves", shelvesArray.toString())
            .putString("favorites", favs.toString())
            .putString("finished", fins.toString())
            .apply()
    }

    private fun loadData() {
        prefs.getString("shelves", null)?.let { raw ->
            try {
                val array = JSONArray(raw)
                val list = mutableListOf<BookShelf>()
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val urisSet = mutableSetOf<String>()
                    val urisArray = obj.optJSONArray("documentUris")
                    if (urisArray != null) {
                        for (j in 0 until urisArray.length()) {
                            urisSet.add(urisArray.getString(j))
                        }
                    }
                    list.add(
                        BookShelf(
                            id = obj.getString("id"),
                            name = obj.getString("name"),
                            iconName = obj.optString("iconName", "books.vertical"),
                            documentUris = urisSet
                        )
                    )
                }
                _customShelves.value = list
            } catch (_: Exception) {}
        }

        prefs.getString("favorites", null)?.let { raw ->
            try {
                val array = JSONArray(raw)
                val set = mutableSetOf<String>()
                for (i in 0 until array.length()) {
                    set.add(array.getString(i))
                }
                _favoriteUris.value = set
            } catch (_: Exception) {}
        }

        prefs.getString("finished", null)?.let { raw ->
            try {
                val array = JSONArray(raw)
                val set = mutableSetOf<String>()
                for (i in 0 until array.length()) {
                    set.add(array.getString(i))
                }
                _finishedUris.value = set
            } catch (_: Exception) {}
        }
    }

    companion object {
        @Volatile
        private var instance: BookCollectionManager? = null

        fun getInstance(context: Context): BookCollectionManager {
            return instance ?: synchronized(this) {
                instance ?: BookCollectionManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
