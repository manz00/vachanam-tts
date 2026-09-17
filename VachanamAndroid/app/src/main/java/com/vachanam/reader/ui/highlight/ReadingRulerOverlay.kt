package com.vachanam.reader.ui.highlight

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput

@Composable
fun ReadingRulerOverlay(
    isEnabled: Boolean,
    rulerHeightDp: Float = 48f,
    modifier: Modifier = Modifier
) {
    if (!isEnabled) return

    var rulerY by remember { mutableFloatStateOf(240f) }

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .pointerInput(Unit) {
                detectVerticalDragGestures { change, dragAmount ->
                    change.consume()
                    rulerY = (rulerY + dragAmount).coerceIn(0f, size.height.toFloat() - rulerHeightDp)
                }
            }
    ) {
        val h = rulerHeightDp * density

        // Semi-transparent shading above and below the reading window
        drawRect(
            color = Color.Black.copy(alpha = 0.45f),
            topLeft = Offset(0f, 0f),
            size = Size(size.width, rulerY)
        )
        drawRect(
            color = Color.Black.copy(alpha = 0.45f),
            topLeft = Offset(0f, rulerY + h),
            size = Size(size.width, size.height - (rulerY + h))
        )

        // Reading guide borders
        drawLine(
            color = Color(0xFFF59E0B).copy(alpha = 0.85f),
            start = Offset(0f, rulerY),
            end = Offset(size.width, rulerY),
            strokeWidth = 2.5f
        )
        drawLine(
            color = Color(0xFFF59E0B).copy(alpha = 0.85f),
            start = Offset(0f, rulerY + h),
            end = Offset(size.width, rulerY + h),
            strokeWidth = 2.5f
        )
    }
}
