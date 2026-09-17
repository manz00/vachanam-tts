package com.vachanam.reader.ui.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vachanam.reader.accessibility.AccessibilityManager
import com.vachanam.reader.accessibility.FontManager
import com.vachanam.reader.accessibility.ThemeManager
import com.vachanam.reader.app.AppState
import com.vachanam.reader.data.model.DocumentFormat
import com.vachanam.reader.pdf.BookmarkManager
import com.vachanam.reader.pdf.PdfDocumentWrapper
import com.vachanam.reader.ui.highlight.ReadingRulerOverlay
import com.vachanam.reader.ui.theme.DeepNavy
import com.vachanam.reader.ui.tts.TTSControlBar

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderContainerView(
    appState: AppState,
    themeManager: ThemeManager,
    fontManager: FontManager,
    accessibilityManager: AccessibilityManager,
    bookmarkManager: BookmarkManager,
    onBack: () -> Unit,
    onOpenSoundscapes: () -> Unit,
    modifier: Modifier = Modifier
) {
    val document by appState.currentDocument.collectAsState()
    val docFile by appState.currentDocumentFile.collectAsState()
    val coordinator = appState.coordinator

    val visiblePage by coordinator.visiblePageIndex.collectAsState()
    val isReadingRulerEnabled by accessibilityManager.isReadingRulerEnabled.collectAsState()
    val rulerHeight by accessibilityManager.rulerHeight.collectAsState()

    val currentDoc = document ?: return

    val isPdf = docFile != null && DocumentFormat.detect(docFile!!) == DocumentFormat.PDF
    var isPdfMode by remember(isPdf) { mutableStateOf(isPdf) }

    val pdfWrapper = remember(docFile) {
        if (isPdf && docFile != null) {
            try {
                PdfDocumentWrapper(docFile!!)
            } catch (_: Exception) {
                null
            }
        } else null
    }

    DisposableEffect(pdfWrapper) {
        onDispose {
            pdfWrapper?.close()
        }
    }

    val isBookmarked = remember(currentDoc.documentID, visiblePage) {
        bookmarkManager.isBookmarked(currentDoc.documentID, visiblePage)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = currentDoc.title,
                        maxLines = 1,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back to Library",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = DeepNavy
                )
            )
        },
        bottomBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.Transparent)
            ) {
                ReaderScrubberBar(
                    currentPage = visiblePage,
                    totalPages = currentDoc.pageCount,
                    isPdfMode = isPdfMode,
                    isBookmarked = isBookmarked,
                    onPageChange = { coordinator.setVisiblePage(it) },
                    onToggleMode = { if (isPdf) isPdfMode = !isPdfMode },
                    onToggleBookmark = { bookmarkManager.toggleBookmark(currentDoc.documentID, visiblePage) }
                )

                TTSControlBar(
                    appState = appState,
                    onOpenSoundscapes = onOpenSoundscapes,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
            }
        },
        containerColor = DeepNavy
    ) { paddingValues ->
        Box(
            modifier = modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (isPdfMode && pdfWrapper != null) {
                PdfPageView(
                    document = currentDoc,
                    pageIndex = visiblePage,
                    pdfWrapper = pdfWrapper,
                    coordinator = coordinator,
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                ReaderTextView(
                    document = currentDoc,
                    pageIndex = visiblePage,
                    coordinator = coordinator,
                    themeManager = themeManager,
                    fontManager = fontManager,
                    accessibilityManager = accessibilityManager,
                    modifier = Modifier.fillMaxSize()
                )
            }

            ReadingRulerOverlay(
                isEnabled = isReadingRulerEnabled,
                rulerHeightDp = rulerHeight
            )
        }
    }
}
