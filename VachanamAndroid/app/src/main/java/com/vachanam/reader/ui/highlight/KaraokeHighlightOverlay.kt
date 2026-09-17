package com.vachanam.reader.ui.highlight

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import com.vachanam.reader.data.model.BoundingBox
import com.vachanam.reader.ui.theme.HighlightYellow
import com.vachanam.reader.ui.theme.SpokenWordRed

@Composable
fun KaraokeHighlightOverlay(
    wordBox: BoundingBox?,
    sentenceBoxes: List<BoundingBox>,
    scaleX: Float = 1.0f,
    scaleY: Float = 1.0f,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier.fillMaxSize()) {
        // 1. Draw sentence-level highlight band
        for (box in sentenceBoxes) {
            val left = box.left * scaleX
            val top = box.top * scaleY
            val width = box.width * scaleX
            val height = box.height * scaleY

            if (width > 0 && height > 0) {
                drawRect(
                    color = HighlightYellow,
                    topLeft = Offset(left, top),
                    size = Size(width, height)
                )
            }
        }

        // 2. Draw active spoken word highlight box (Red accent border/fill)
        if (wordBox != null && !wordBox.isEmpty) {
            val wLeft = wordBox.left * scaleX
            val wTop = wordBox.top * scaleY
            val wWidth = wordBox.width * scaleX
            val wHeight = wordBox.height * scaleY

            drawRect(
                color = SpokenWordRed.copy(alpha = 0.25f),
                topLeft = Offset(wLeft - 2f, wTop - 2f),
                size = Size(wWidth + 4f, wHeight + 4f)
            )
            drawRect(
                color = SpokenWordRed,
                topLeft = Offset(wLeft - 2f, wTop - 2f),
                size = Size(wWidth + 4f, wHeight + 4f),
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.5f)
            )
        }
    }
}
