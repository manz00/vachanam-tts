package com.vachanam.reader.ui.reader

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.vachanam.reader.accessibility.ThemeManager
import com.vachanam.reader.data.model.BoundingBox
import com.vachanam.reader.data.model.SemanticDocument
import com.vachanam.reader.pdf.PdfDocumentWrapper
import com.vachanam.reader.tts.PlaybackCoordinator
import com.vachanam.reader.ui.highlight.KaraokeHighlightOverlay

@Composable
fun PdfPageView(
    document: SemanticDocument,
    pageIndex: Int,
    pdfWrapper: PdfDocumentWrapper?,
    coordinator: PlaybackCoordinator,
    themeManager: ThemeManager,
    modifier: Modifier = Modifier
) {
    val theme by themeManager.currentReaderTheme.collectAsState()
    val readingLayout by themeManager.currentReadingLayout.collectAsState()

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(theme.backgroundColor)
    ) {
        if (readingLayout.isTwoPage) {
            val leftPageIndex = (pageIndex / 2) * 2
            val rightPageIndex = leftPageIndex + 1

            Row(
                modifier = Modifier.fillMaxSize()
            ) {
                // Left Page
                SinglePdfPageBox(
                    document = document,
                    pageIndex = leftPageIndex,
                    pdfWrapper = pdfWrapper,
                    coordinator = coordinator,
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                )

                // Spine Divider
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .fillMaxHeight()
                        .padding(vertical = 16.dp)
                        .background(theme.textColor.copy(alpha = 0.12f))
                )

                // Right Page
                if (rightPageIndex < document.pageCount) {
                    SinglePdfPageBox(
                        document = document,
                        pageIndex = rightPageIndex,
                        pdfWrapper = pdfWrapper,
                        coordinator = coordinator,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                    )
                } else {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        } else {
            SinglePdfPageBox(
                document = document,
                pageIndex = pageIndex,
                pdfWrapper = pdfWrapper,
                coordinator = coordinator,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}

@Composable
private fun SinglePdfPageBox(
    document: SemanticDocument,
    pageIndex: Int,
    pdfWrapper: PdfDocumentWrapper?,
    coordinator: PlaybackCoordinator,
    modifier: Modifier = Modifier
) {
    var pageBitmap by remember(pageIndex, pdfWrapper) { mutableStateOf<Bitmap?>(null) }
    var viewSize by remember { mutableStateOf(IntSize.Zero) }

    val currentWordID by coordinator.currentWordID.collectAsState()
    val currentSentenceID by coordinator.currentSentenceID.collectAsState()

    LaunchedEffect(pageIndex, pdfWrapper) {
        if (pdfWrapper != null) {
            pageBitmap = pdfWrapper.renderPageBitmap(pageIndex, scale = 2.0f)
        }
    }

    val (pageWidth, pageHeight) = remember(pageIndex, pdfWrapper) {
        pdfWrapper?.getPageDimensions(pageIndex) ?: Pair(612, 792)
    }

    val scaleX = if (pageWidth > 0 && viewSize.width > 0) viewSize.width.toFloat() / pageWidth else 1.0f
    val scaleY = if (pageHeight > 0 && viewSize.height > 0) viewSize.height.toFloat() / pageHeight else 1.0f

    val currentWordBox = remember(currentWordID, document, pageIndex) {
        val word = document.word(currentWordID ?: -1)
        if (word != null && word.pageIndex == pageIndex) word.bounds else null
    }

    val currentSentenceBoxes = remember(currentSentenceID, document, pageIndex) {
        val sent = document.sentence(currentSentenceID ?: -1)
        if (sent != null && sent.pageSpans.contains(pageIndex)) {
            sent.lineBounds(pageIndex)
        } else {
            emptyList()
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .onSizeChanged { viewSize = it }
            .pointerInput(pageIndex, document) {
                detectTapGestures { offset ->
                    val docX = offset.x / scaleX
                    val docY = offset.y / scaleY
                    val tappedWord = document.findWord(docX, docY, pageIndex)
                    if (tappedWord != null) {
                        coordinator.seekToWord(tappedWord.globalWordID)
                    }
                }
            }
    ) {
        val bmp = pageBitmap
        if (bmp != null) {
            Image(
                bitmap = bmp.asImageBitmap(),
                contentDescription = "PDF Page ${pageIndex + 1}",
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxSize()
            )
        }

        KaraokeHighlightOverlay(
            wordBox = currentWordBox,
            sentenceBoxes = currentSentenceBoxes,
            scaleX = scaleX,
            scaleY = scaleY,
            modifier = Modifier.fillMaxSize()
        )
    }
}
