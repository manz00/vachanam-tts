package com.vachanam.reader.pdf

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

class PdfDocumentWrapper(
    val file: File
) : AutoCloseable {

    private var fileDescriptor: ParcelFileDescriptor? = null
    private var renderer: PdfRenderer? = null
    private val lock = Any()

    val pageCount: Int
        get() = synchronized(lock) { renderer?.pageCount ?: 0 }

    init {
        fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        renderer = PdfRenderer(fileDescriptor!!)
    }

    fun getPageDimensions(pageIndex: Int): Pair<Int, Int> = synchronized(lock) {
        val r = renderer ?: return Pair(0, 0)
        if (pageIndex !in 0 until r.pageCount) return Pair(0, 0)
        try {
            val page = r.openPage(pageIndex)
            val w = page.width
            val h = page.height
            page.close()
            Pair(w, h)
        } catch (_: Exception) {
            Pair(612, 792)
        }
    }

    suspend fun renderPageBitmap(
        pageIndex: Int,
        scale: Float = 2.0f
    ): Bitmap? = withContext(Dispatchers.Default) {
        synchronized(lock) {
            val r = renderer ?: return@synchronized null
            if (pageIndex !in 0 until r.pageCount) return@synchronized null

            try {
                val page = r.openPage(pageIndex)
                val targetWidth = (page.width * scale).toInt().coerceAtLeast(1)
                val targetHeight = (page.height * scale).toInt().coerceAtLeast(1)

                val bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
                bitmap.eraseColor(Color.WHITE)

                val matrix = Matrix().apply {
                    postScale(scale, scale)
                }

                page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                page.close()

                bitmap
            } catch (_: Exception) {
                null
            }
        }
    }

    override fun close() = synchronized(lock) {
        try {
            renderer?.close()
            fileDescriptor?.close()
        } catch (_: Exception) {}
        renderer = null
        fileDescriptor = null
    }
}
