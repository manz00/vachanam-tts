package com.vachanam.reader.ui.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.ui.theme.SlateCharcoal
import com.vachanam.reader.ui.theme.WarmAmber

@Composable
fun ReaderScrubberBar(
    currentPage: Int,
    totalPages: Int,
    isPdfMode: Boolean,
    isBookmarked: Boolean,
    onPageChange: (Int) -> Unit,
    onToggleMode: () -> Unit,
    onToggleBookmark: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(24.dp)),
        color = SlateCharcoal.copy(alpha = 0.92f),
        tonalElevation = 8.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // Previous Page
            IconButton(
                onClick = { if (currentPage > 0) onPageChange(currentPage - 1) },
                enabled = currentPage > 0
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Previous Page",
                    tint = if (currentPage > 0) Color.White else Color.Gray
                )
            }

            // Slider & Page Indicator
            Column(
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "Page ${currentPage + 1} of $totalPages",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.8f)
                )
                if (totalPages > 1) {
                    Slider(
                        value = currentPage.toFloat(),
                        onValueChange = { onPageChange(it.toInt()) },
                        valueRange = 0f..(totalPages - 1).toFloat(),
                        colors = SliderDefaults.colors(
                            thumbColor = WarmAmber,
                            activeTrackColor = WarmAmber
                        ),
                        modifier = Modifier.height(24.dp)
                    )
                }
            }

            // Next Page
            IconButton(
                onClick = { if (currentPage < totalPages - 1) onPageChange(currentPage + 1) },
                enabled = currentPage < totalPages - 1
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = "Next Page",
                    tint = if (currentPage < totalPages - 1) Color.White else Color.Gray
                )
            }

            // Bookmark Toggle
            IconButton(onClick = onToggleBookmark) {
                Icon(
                    imageVector = if (isBookmarked) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                    contentDescription = "Toggle Bookmark",
                    tint = if (isBookmarked) WarmAmber else Color.White
                )
            }

            // Mode Toggle (PDF vs Reader View)
            IconButton(onClick = onToggleMode) {
                Icon(
                    imageVector = if (isPdfMode) Icons.Default.MenuBook else Icons.Default.PictureAsPdf,
                    contentDescription = if (isPdfMode) "Switch to Reader View" else "Switch to PDF View",
                    tint = WarmAmber
                )
            }
        }
    }
}
