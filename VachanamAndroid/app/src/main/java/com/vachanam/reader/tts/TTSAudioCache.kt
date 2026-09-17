package com.vachanam.reader.tts

import android.content.Context
import android.util.LruCache
import com.vachanam.reader.data.model.TTSAudioResult
import java.io.File
import java.security.MessageDigest

class TTSAudioCache(context: Context) {
    private val diskDir = File(context.cacheDir, "vachanam_tts_cache").apply { mkdirs() }
    private val memoryCache = LruCache<String, TTSAudioResult>(50)

    private fun cacheKey(text: String, voice: String?, speed: Float): String {
        val input = "$text|$voice|$speed"
        val md = MessageDigest.getInstance("MD5")
        val bytes = md.digest(input.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }

    fun get(text: String, voice: String?, speed: Float): TTSAudioResult? {
        val key = cacheKey(text, voice, speed)
        return memoryCache.get(key)
    }

    fun put(text: String, voice: String?, speed: Float, result: TTSAudioResult) {
        val key = cacheKey(text, voice, speed)
        memoryCache.put(key, result)
    }

    fun clear() {
        memoryCache.evictAll()
        diskDir.deleteRecursively()
        diskDir.mkdirs()
    }
}
