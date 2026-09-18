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
fun EPUBPaginatedReader(
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
    val pageCount = document.pageCount.coerceAtLeast(1)

    val pagerState = rememberPagerState(
        initialPage = currentPageIndex.coerceIn(0, pageCount - 1),
        pageCount = { pageCount }
    )

    // Sync pager when external page changes (e.g. TTS speech auto-advancing or scrubber)
    LaunchedEffect(currentPageIndex) {
        if (pagerState.currentPage != currentPageIndex && currentPageIndex in 0 until pageCount) {
            pagerState.animateScrollToPage(currentPageIndex)
        }
    }

    // Notify coordinator when user swipes pages
    LaunchedEffect(pagerState.currentPage) {
        if (pagerState.currentPage != currentPageIndex) {
            onPageChange(pagerState.currentPage)
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
        ) { page ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Apple Books Running Top Header
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

                // Page Body
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
                        pageIndex = page,
                        coordinator = coordinator,
                        themeManager = themeManager,
                        fontManager = fontManager,
                        accessibilityManager = accessibilityManager,
                        modifier = Modifier.fillMaxSize()
                    )
                }

                // Apple Books Running Bottom Footer
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(32.dp)
                        .padding(bottom = 6.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "${page + 1} of $pageCount",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Normal,
                        color = theme.secondaryTextColor
                    )
                }
            }
        }
    }
}
