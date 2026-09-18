package com.vachanam.reader.ui.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.accessibility.AccessibilityManager
import com.vachanam.reader.accessibility.FontManager
import com.vachanam.reader.accessibility.ThemeManager
import com.vachanam.reader.data.model.SemanticDocument
import com.vachanam.reader.tts.PlaybackCoordinator

@Composable
fun PaginatedReaderView(
    document: SemanticDocument,
    currentPageIndex: Int,
    onPageChange: (Int) -> Unit,
    coordinator: PlaybackCoordinator,
    themeManager: ThemeManager,
    fontManager: FontManager,
    accessibilityManager: AccessibilityManager,
    onToggleChrome: () -> Unit,
    modifier: Modifier = Modifier
) {
    val theme by themeManager.currentReaderTheme.collectAsState()
    val readingLayout by themeManager.currentReadingLayout.collectAsState()
    val pageCount = document.pageCount.coerceAtLeast(1)

    val isTwoPage = readingLayout.isTwoPage
    val spreadCount = if (isTwoPage) (pageCount + 1) / 2 else pageCount

    val initialPage = if (isTwoPage) {
        (currentPageIndex / 2).coerceIn(0, spreadCount - 1)
    } else {
        currentPageIndex.coerceIn(0, pageCount - 1)
    }

    val pagerState = rememberPagerState(
        initialPage = initialPage,
        pageCount = { spreadCount }
    )

    // Synchronize pager when speech or external scrubber changes the current page
    LaunchedEffect(currentPageIndex, isTwoPage) {
        val targetPage = if (isTwoPage) (currentPageIndex / 2) else currentPageIndex
        if (pagerState.currentPage != targetPage && targetPage in 0 until spreadCount) {
            pagerState.animateScrollToPage(targetPage)
        }
    }

    // Notify coordinator when user swipes pages
    LaunchedEffect(pagerState.currentPage, isTwoPage) {
        val targetIndex = if (isTwoPage) pagerState.currentPage * 2 else pagerState.currentPage
        if (targetIndex != currentPageIndex && targetIndex in 0 until pageCount) {
            onPageChange(targetIndex)
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(theme.backgroundColor)
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { spreadIndex ->
            if (isTwoPage) {
                val leftPageIndex = spreadIndex * 2
                val rightPageIndex = leftPageIndex + 1

                Row(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp)
                ) {
                    // Left Page
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                    ) {
                        SinglePageColumn(
                            document = document,
                            pageIndex = leftPageIndex,
                            pageCount = pageCount,
                            coordinator = coordinator,
                            themeManager = themeManager,
                            fontManager = fontManager,
                            accessibilityManager = accessibilityManager,
                            onToggleChrome = onToggleChrome,
                            modifier = Modifier.fillMaxSize()
                        )
                    }

                    // Book Spine Divider
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .fillMaxHeight()
                            .padding(vertical = 24.dp)
                            .background(theme.textColor.copy(alpha = 0.12f))
                    )

                    // Right Page
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                    ) {
                        if (rightPageIndex < pageCount) {
                            SinglePageColumn(
                                document = document,
                                pageIndex = rightPageIndex,
                                pageCount = pageCount,
                                coordinator = coordinator,
                                themeManager = themeManager,
                                fontManager = fontManager,
                                accessibilityManager = accessibilityManager,
                                onToggleChrome = onToggleChrome,
                                modifier = Modifier.fillMaxSize()
                            )
                        } else {
                            Spacer(modifier = Modifier.fillMaxSize())
                        }
                    }
                }
            } else {
                SinglePageColumn(
                    document = document,
                    pageIndex = spreadIndex,
                    pageCount = pageCount,
                    coordinator = coordinator,
                    themeManager = themeManager,
                    fontManager = fontManager,
                    accessibilityManager = accessibilityManager,
                    onToggleChrome = onToggleChrome,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 24.dp)
                )
            }
        }
    }
}

@Composable
private fun SinglePageColumn(
    document: SemanticDocument,
    pageIndex: Int,
    pageCount: Int,
    coordinator: PlaybackCoordinator,
    themeManager: ThemeManager,
    fontManager: FontManager,
    accessibilityManager: AccessibilityManager,
    onToggleChrome: () -> Unit,
    modifier: Modifier = Modifier
) {
    val theme by themeManager.currentReaderTheme.collectAsState()

    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Running Top Header
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(36.dp)
                .padding(top = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = document.title,
                fontSize = 11.sp,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Medium,
                color = theme.secondaryTextColor,
                maxLines = 1
            )
        }

        // Page Text Body
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) {
                    onToggleChrome()
                }
        ) {
            ReaderTextView(
                document = document,
                pageIndex = pageIndex,
                coordinator = coordinator,
                themeManager = themeManager,
                fontManager = fontManager,
                accessibilityManager = accessibilityManager,
                modifier = Modifier.fillMaxSize()
            )
        }

        // Running Bottom Footer (Page Indicator)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(32.dp)
                .padding(bottom = 6.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "${pageIndex + 1} of $pageCount",
                fontSize = 11.sp,
                fontWeight = FontWeight.Normal,
                color = theme.secondaryTextColor
            )
        }
    }
}
