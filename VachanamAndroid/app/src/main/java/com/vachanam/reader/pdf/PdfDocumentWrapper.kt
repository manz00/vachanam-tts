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

    val pageCount: Int
        get() = renderer?.pageCount ?: 0

    init {
        fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        renderer = PdfRenderer(fileDescriptor!!)
    }

    fun getPageDimensions(pageIndex: Int): Pair<Int, Int> {
        val r = renderer ?: return Pair(0, 0)
        if (pageIndex !in 0 until r.pageCount) return Pair(0, 0)
        val page = r.openPage(pageIndex)
        val w = page.width
        val h = page.height
        page.close()
        return Pair(w, h)
    }

    suspend fun renderPageBitmap(
        pageIndex: Int,
        scale: Float = 2.0f
    ): Bitmap? = withContext(Dispatchers.Default) {
        val r = renderer ?: return@withContext null
        if (pageIndex !in 0 until r.pageCount) return@withContext null

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
    }

    override fun close() {
        renderer?.close()
        fileDescriptor?.close()
        renderer = null
        fileDescriptor = null
    }
}
