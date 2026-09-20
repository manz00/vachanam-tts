package com.vachanam.reader.util

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileOutputStream

object FileUtils {

    fun copyUriToInternalStorage(context: Context, uri: Uri): File? {
        return try {
            val contentResolver = context.contentResolver
            var displayName: String? = null

            // 0. Take persistable URI read permission if content scheme
            if (uri.scheme == ContentResolver.SCHEME_CONTENT) {
                try {
                    context.contentResolver.takePersistableUriPermission(
                        uri,
                        android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                } catch (_: Exception) {}
            }

            // 0b. Direct file handling if scheme is file or null
            if (uri.scheme == ContentResolver.SCHEME_FILE || uri.scheme == null) {
                val path = uri.path
                if (path != null) {
                    val srcFile = File(path)
                    if (srcFile.exists() && srcFile.canRead()) {
                        val destFile = File(context.filesDir, srcFile.name)
                        destFile.parentFile?.mkdirs()
                        srcFile.copyTo(destFile, overwrite = true)
                        return destFile
                    }
                }
            }

            // 1. Resolve true display name via ContentResolver (SAF standard)
            if (uri.scheme == ContentResolver.SCHEME_CONTENT) {
                try {
                    contentResolver.query(
                        uri,
                        arrayOf(OpenableColumns.DISPLAY_NAME),
                        null,
                        null,
                        null
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (idx != -1) {
                                displayName = cursor.getString(idx)
                            }
                        }
                    }
                } catch (_: Exception) {}
            }

            // 2. Fallback to decoded lastPathSegment
            if (displayName.isNullOrBlank()) {
                val rawSegment = uri.lastPathSegment?.substringAfterLast('/') ?: "document"
                displayName = try {
                    java.net.URLDecoder.decode(rawSegment, "UTF-8")
                } catch (_: Exception) {
                    rawSegment
                }
            }

            // 3. Sanitize filename (clean out colons and slashes for filesystem safety)
            var cleanName = displayName.replace(":", "_").replace("/", "_")

            // 4. Ensure valid extension using MIME type detection if extension is missing
            val hasExtension = cleanName.contains(".") && cleanName.substringAfterLast('.').isNotBlank()
            if (!hasExtension) {
                val mime = contentResolver.getType(uri)
                val ext = when (mime) {
                    "application/pdf" -> "pdf"
                    "application/epub+zip", "application/x-epub" -> "epub"
                    "text/plain" -> "txt"
                    "text/markdown", "text/x-markdown" -> "md"
                    else -> MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "pdf"
                }
                cleanName = "$cleanName.$ext"
            }

            val destFile = File(context.filesDir, cleanName)
            destFile.parentFile?.mkdirs()
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            destFile
        } catch (_: Exception) {
            null
        }
    }
}
