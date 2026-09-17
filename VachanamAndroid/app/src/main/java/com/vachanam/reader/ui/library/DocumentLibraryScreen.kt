package com.vachanam.reader.ui.library

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.app.AppState
import com.vachanam.reader.data.model.DocumentFormat
import com.vachanam.reader.data.persistence.ReadingProgress
import com.vachanam.reader.ui.theme.*
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DocumentLibraryScreen(
    appState: AppState,
    onOpenReader: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val progressTracker = appState.progressTracker
    var recentDocs by remember { mutableStateOf(progressTracker.allRecentDocuments()) }
    var showWebImportDialog by remember { mutableStateOf(false) }

    val filePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                val copiedFile = copyUriToInternalStorage(context, uri)
                if (copiedFile != null) {
                    appState.openDocument(copiedFile)
                    recentDocs = progressTracker.allRecentDocuments()
                    onOpenReader()
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "Vachanam (వచనం)",
                            fontSize = 20.sp,
                            color = WarmAmber
                        )
                        Text(
                            text = "Accessible Neural Reader",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(
                            imageVector = Icons.Default.Settings,
                            contentDescription = "Settings",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DeepNavy)
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = {
                    filePickerLauncher.launch(
                        arrayOf(
                            "application/pdf",
                            "application/epub+zip",
                            "text/plain",
                            "text/markdown"
                        )
                    )
                },
                containerColor = WarmAmber,
                contentColor = Color.Black
            ) {
                Icon(imageVector = Icons.Default.Add, contentDescription = "Import Document")
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "Import Document")
            }
        },
        containerColor = DeepNavy
    ) { paddingValues ->
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            // Web Article Quick Import Button
            OutlinedButton(
                onClick = { showWebImportDialog = true },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = VibrantTeal),
                border = ButtonDefaults.outlinedButtonBorder.copy(brush = androidx.compose.ui.graphics.SolidColor(VibrantTeal))
            ) {
                Icon(imageVector = Icons.Default.Language, contentDescription = "Import Web Article")
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "Import Web Article by URL")
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "Recent Documents",
                fontSize = 18.sp,
                color = Color.White,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            if (recentDocs.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No documents imported yet.\nTap 'Import Document' to read PDFs, EPUBs, or text.",
                        color = Color.White.copy(alpha = 0.5f),
                        fontSize = 14.sp
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(recentDocs) { record ->
                        DocumentCard(
                            record = record,
                            onClick = {
                                val file = File(record.documentUri)
                                if (file.exists()) {
                                    scope.launch {
                                        appState.openDocument(file)
                                        onOpenReader()
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    if (showWebImportDialog) {
        WebArticleImportDialog(
            onDismiss = { showWebImportDialog = false },
            onImport = { url ->
                showWebImportDialog = false
                scope.launch {
                    try {
                        val parsed = com.vachanam.reader.data.parser.WebArticleParser().parse(
                            com.vachanam.reader.data.parser.DocumentSource.WebUrl(url)
                        )
                        val outFile = File(context.filesDir, "${parsed.title.take(30)}.txt")
                        val fullText = parsed.allBlocks.joinToString("\n\n") { it.text }
                        outFile.writeText(fullText)
                        appState.openDocument(outFile)
                        recentDocs = progressTracker.allRecentDocuments()
                        onOpenReader()
                    } catch (_: Exception) {}
                }
            }
        )
    }
}

@Composable
private fun DocumentCard(
    record: ReadingProgress,
    onClick: () -> Unit
) {
    val progress = if (record.totalPages > 0) (record.currentPage + 1).toFloat() / record.totalPages else 0f
    val format = DocumentFormat.detect(File(record.documentUri))

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick),
        color = SlateCharcoal,
        tonalElevation = 4.dp
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = record.title,
                    fontSize = 16.sp,
                    color = Color.White,
                    maxLines = 1,
                    modifier = Modifier.weight(1f)
                )
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = SurfaceElevated
                ) {
                    Text(
                        text = format.displayName,
                        fontSize = 11.sp,
                        color = VibrantTeal,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)),
                color = WarmAmber,
                trackColor = SurfaceElevated
            )

            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = "Page ${record.currentPage + 1} of ${record.totalPages} (${(progress * 100).toInt()}%)",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
private fun WebArticleImportDialog(
    onDismiss: () -> Unit,
    onImport: (String) -> Unit
) {
    var urlText by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(text = "Import Web Article") },
        text = {
            Column {
                Text(text = "Enter the URL of the article you want to read:")
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = urlText,
                    onValueChange = { urlText = it },
                    placeholder = { Text("https://example.com/article") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onImport(urlText.trim()) },
                enabled = urlText.startsWith("http://") || urlText.startsWith("https://")
            ) {
                Text("Import")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

private fun copyUriToInternalStorage(context: android.content.Context, uri: Uri): File? {
    return try {
        val fileName = uri.lastPathSegment?.substringAfterLast('/') ?: "document.pdf"
        val cleanName = if (fileName.contains(".")) fileName else "$fileName.pdf"
        val destFile = File(context.filesDir, cleanName)

        context.contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(destFile).use { output ->
                input.copyTo(output)
            }
        }
        destFile
    } catch (_: Exception) {
        null
    }
}
