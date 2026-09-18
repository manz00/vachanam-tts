package com.vachanam.reader.ui.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.vachanam.reader.data.model.SemanticDocument
import com.vachanam.reader.data.persistence.BookPreparationRecord
import com.vachanam.reader.data.persistence.BookPreparationService
import com.vachanam.reader.ui.theme.DeepNavy
import com.vachanam.reader.ui.theme.SlateCharcoal
import com.vachanam.reader.ui.theme.SurfaceElevated
import com.vachanam.reader.ui.theme.VibrantTeal
import com.vachanam.reader.ui.theme.WarmAmber
import kotlinx.coroutines.launch
import java.io.File

@Composable
fun BookStructureDialog(
    document: SemanticDocument,
    docFile: File?,
    preparationService: BookPreparationService,
    onDismiss: () -> Unit
) {
    val coroutineScope = rememberCoroutineScope()
    val records by preparationService.preparedRecords.collectAsState()
    val preparingUris by preparationService.activelyPreparingUris.collectAsState()

    val uriString = docFile?.toURI()?.toString() ?: document.title
    val record = records[uriString]
    val isPreparing = preparingUris.contains(uriString)

    LaunchedEffect(uriString) {
        if (record == null && docFile != null && docFile.exists()) {
            coroutineScope.launch {
                preparationService.prepareBook(uriString, docFile)
            }
        }
    }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = SlateCharcoal)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp)
            ) {
                // Dialog Title Bar
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Book Intelligence",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
                            tint = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Stats Header Card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = SurfaceElevated)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "Words",
                                fontSize = 11.sp,
                                color = Color.White.copy(alpha = 0.6f)
                            )
                            Text(
                                text = if (record != null) "${record.wordCount}" else "—",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                        }

                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "Reading",
                                fontSize = 11.sp,
                                color = Color.White.copy(alpha = 0.6f)
                            )
                            Text(
                                text = if (record != null) "~${record.estimatedReadingMinutes}m" else "—",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = WarmAmber
                            )
                        }

                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "Spoken Audio",
                                fontSize = 11.sp,
                                color = Color.White.copy(alpha = 0.6f)
                            )
                            Text(
                                text = if (record != null) "~${record.estimatedAudioMinutes}m" else "—",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = VibrantTeal
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                if (isPreparing) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 24.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            color = WarmAmber
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = "Analyzing chapters & durations...",
                            color = Color.White.copy(alpha = 0.8f),
                            fontSize = 13.sp
                        )
                    }
                } else if (record != null) {
                    Text(
                        text = "Chapters (${record.chapterCount})",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.padding(bottom = 8.dp)
                    )

                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 280.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(record.chapterSummaries) { ch ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(DeepNavy, RoundedCornerShape(8.dp))
                                    .padding(horizontal = 12.dp, vertical = 10.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = ch.title,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = Color.White,
                                        maxLines = 1
                                    )
                                    Text(
                                        text = "${ch.wordCount} words",
                                        fontSize = 11.sp,
                                        color = Color.White.copy(alpha = 0.5f)
                                    )
                                }

                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .background(
                                            VibrantTeal.copy(alpha = 0.18f),
                                            RoundedCornerShape(6.dp)
                                        )
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Headphones,
                                        contentDescription = null,
                                        tint = VibrantTeal,
                                        modifier = Modifier.size(12.dp)
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = "~${ch.estimatedAudioMinutes}m",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = VibrantTeal
                                    )
                                }
                            }
                        }
                    }
                } else {
                    Button(
                        onClick = {
                            if (docFile != null) {
                                coroutineScope.launch {
                                    preparationService.prepareBook(uriString, docFile)
                                }
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = WarmAmber),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Prepare Book for Voice", color = Color.Black, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
