package com.vachanam.reader.ui.reader

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.ViewCarousel
import androidx.compose.material.icons.filled.ViewHeadline
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.accessibility.AccessibilityManager
import com.vachanam.reader.accessibility.FontManager
import com.vachanam.reader.accessibility.ThemeManager
import com.vachanam.reader.app.AppState
import com.vachanam.reader.data.model.DocumentFormat
import com.vachanam.reader.data.persistence.BookPreparationService
import com.vachanam.reader.pdf.BookmarkManager
import com.vachanam.reader.pdf.PdfDocumentWrapper
import com.vachanam.reader.ui.highlight.ReadingRulerOverlay
import com.vachanam.reader.ui.theme.DeepNavy
import com.vachanam.reader.ui.theme.ReadingLayout
import com.vachanam.reader.ui.theme.WarmAmber
import com.vachanam.reader.ui.tts.TTSControlBar
import kotlinx.coroutines.delay

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
    val context = LocalContext.current
    val document by appState.currentDocument.collectAsState()
    val docFile by appState.currentDocumentFile.collectAsState()
    val coordinator = appState.coordinator

    val visiblePage by coordinator.visiblePageIndex.collectAsState()
    val isReadingRulerEnabled by accessibilityManager.isReadingRulerEnabled.collectAsState()
    val rulerHeight by accessibilityManager.rulerHeight.collectAsState()
    val readingLayout by themeManager.currentReadingLayout.collectAsState()
    val theme by themeManager.currentReaderTheme.collectAsState()

    val currentDoc = document
    if (currentDoc == null) {
        Box(
            modifier = modifier
                .fillMaxSize()
                .background(DeepNavy),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "No document loaded",
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 16.sp
                )
                Spacer(modifier = Modifier.height(16.dp))
                Button(
                    onClick = onBack,
                    colors = ButtonDefaults.buttonColors(containerColor = WarmAmber)
                ) {
                    Text("Back to Library", color = Color.Black)
                }
            }
        }
        return
    }

    val isPdf = docFile != null && DocumentFormat.detect(docFile!!) == DocumentFormat.PDF
    var isPdfMode by remember(isPdf) { mutableStateOf(isPdf) }
    var isChromeVisible by remember { mutableStateOf(true) }
    var isStructureDialogVisible by remember { mutableStateOf(false) }
    var showResumeToast by remember { mutableStateOf(visiblePage > 0) }

    val preparationService = remember { BookPreparationService.getInstance(context) }

    LaunchedEffect(showResumeToast) {
        if (showResumeToast) {
            delay(4500)
            showResumeToast = false
        }
    }

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
            AnimatedVisibility(
                visible = isChromeVisible,
                enter = slideInVertically() + fadeIn(),
                exit = slideOutVertically() + fadeOut()
            ) {
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
                    actions = {
                        // PDF Mode Toggle (Original PDF vs Clean Text)
                        if (isPdf) {
                            IconButton(onClick = { isPdfMode = !isPdfMode }) {
                                Icon(
                                    imageVector = if (isPdfMode) Icons.Default.MenuBook else Icons.Default.PictureAsPdf,
                                    contentDescription = if (isPdfMode) "Switch to Clean Text" else "Switch to Original PDF",
                                    tint = Color.White
                                )
                            }
                        }

                        // Universal Reading Layout Toggle (Single Page -> Two Pages -> Continuous Scroll)
                        IconButton(
                            onClick = {
                                val nextLayout = when (readingLayout) {
                                    ReadingLayout.PAGINATED -> ReadingLayout.TWO_PAGE
                                    ReadingLayout.TWO_PAGE -> ReadingLayout.CONTINUOUS
                                    ReadingLayout.CONTINUOUS -> ReadingLayout.PAGINATED
                                }
                                themeManager.setLayout(nextLayout)
                            }
                        ) {
                            Icon(
                                imageVector = when (readingLayout) {
                                    ReadingLayout.PAGINATED -> Icons.Default.ViewCarousel
                                    ReadingLayout.TWO_PAGE -> Icons.Default.MenuBook
                                    ReadingLayout.CONTINUOUS -> Icons.Default.ViewHeadline
                                },
                                contentDescription = "Reading Layout: ${readingLayout.displayName}",
                                tint = WarmAmber
                            )
                        }

                        // Book Intelligence & Structure
                        IconButton(onClick = { isStructureDialogVisible = true }) {
                            Icon(
                                imageVector = Icons.Default.Info,
                                contentDescription = "Book Structure & Durations",
                                tint = Color.White
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = DeepNavy
                    )
                )
            }
        },
        bottomBar = {
            AnimatedVisibility(
                visible = isChromeVisible,
                enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
                exit = slideOutVertically(targetOffsetY = { it }) + fadeOut()
            ) {
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
            }
        },
        containerColor = theme.backgroundColor
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
                    themeManager = themeManager,
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                if (readingLayout.isPaginated) {
                    PaginatedReaderView(
                        document = currentDoc,
                        currentPageIndex = visiblePage,
                        onPageChange = { coordinator.setVisiblePage(it) },
                        coordinator = coordinator,
                        themeManager = themeManager,
                        fontManager = fontManager,
                        accessibilityManager = accessibilityManager,
                        onToggleChrome = { isChromeVisible = !isChromeVisible },
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
            }

            // Dyslexia Reading Ruler Guide
            ReadingRulerOverlay(
                isEnabled = isReadingRulerEnabled,
                rulerHeightDp = rulerHeight
            )

            // Precision Resume Banner
            AnimatedVisibility(
                visible = showResumeToast,
                enter = slideInVertically() + fadeIn(),
                exit = slideOutVertically() + fadeOut(),
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 16.dp)
            ) {
                Surface(
                    shape = CircleShape,
                    color = Color(0xFF151D2A).copy(alpha = 0.95f),
                    shadowElevation = 8.dp,
                    modifier = Modifier.padding(horizontal = 24.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Bookmark,
                            contentDescription = null,
                            tint = WarmAmber,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = "Resumed at Page ${visiblePage + 1}",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color.White
                        )
                        Button(
                            onClick = {
                                appState.play()
                                showResumeToast = false
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = WarmAmber),
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 2.dp),
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.height(28.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = null,
                                tint = Color.Black,
                                modifier = Modifier.size(12.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Play", color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                        IconButton(
                            onClick = { showResumeToast = false },
                            modifier = Modifier.size(20.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Dismiss",
                                tint = Color.White.copy(alpha = 0.6f),
                                modifier = Modifier.size(14.dp)
                            )
                        }
                    }
                }
            }
        }
    }

    if (isStructureDialogVisible) {
        BookStructureDialog(
            document = currentDoc,
            docFile = docFile,
            preparationService = preparationService,
            onDismiss = { isStructureDialogVisible = false }
        )
    }
}
