package com.vachanam.reader.data.model

data class BoundingBox(
    val left: Float = 0f,
    val top: Float = 0f,
    val right: Float = 0f,
    val bottom: Float = 0f
) {
    val width: Float get() = (right - left).coerceAtLeast(0f)
    val height: Float get() = (bottom - top).coerceAtLeast(0f)
    val midX: Float get() = left + width / 2f
    val midY: Float get() = top + height / 2f
    val isEmpty: Boolean get() = width <= 0f || height <= 0f

    fun contains(x: Float, y: Float): Boolean {
        return x in left..right && y in top..bottom
    }

    fun inset(dx: Float, dy: Float): BoundingBox {
        return BoundingBox(
            left = left + dx,
            top = top + dy,
            right = right - dx,
            bottom = bottom - dy
        )
    }

    companion object {
        val ZERO = BoundingBox(0f, 0f, 0f, 0f)
    }
}
