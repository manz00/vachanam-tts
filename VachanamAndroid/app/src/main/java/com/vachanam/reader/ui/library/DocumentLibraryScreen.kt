package com.vachanam.reader.ui.library

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.app.AppState
import com.vachanam.reader.data.model.DocumentFormat
import com.vachanam.reader.data.persistence.BookCollectionManager
import com.vachanam.reader.data.persistence.BookPreparationService
import com.vachanam.reader.data.persistence.BookShelf
import com.vachanam.reader.data.persistence.ReadingProgress
import com.vachanam.reader.ui.theme.*
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream

enum class LibrarySortOption(val displayName: String) {
    RECENT("Recently Read"),
    TITLE("Title (A-Z)"),
    PROGRESS("Progress")
}

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
    val collectionManager = remember { BookCollectionManager.getInstance(context) }
    val prepService = remember { BookPreparationService.getInstance(context) }

    var recentDocs by remember { mutableStateOf(progressTracker.allRecentDocuments()) }
    val customShelves by collectionManager.customShelves.collectAsState()
    val favoriteUris by collectionManager.favoriteUris.collectAsState()
    val finishedUris by collectionManager.finishedUris.collectAsState()
    val preparedRecords by prepService.preparedRecords.collectAsState()
    val activelyPreparing by prepService.activelyPreparingUris.collectAsState()

    var showWebImportDialog by remember { mutableStateOf(false) }
    var showCreateShelfDialog by remember { mutableStateOf(false) }
    var documentToDelete by remember { mutableStateOf<ReadingProgress?>(null) }
    var documentForShelfSheet by remember { mutableStateOf<ReadingProgress?>(null) }

    var selectedShelfId by remember { mutableStateOf("all") }
    var selectedFormatFilter by remember { mutableStateOf<DocumentFormat?>(null) }
    var currentSortOption by remember { mutableStateOf(LibrarySortOption.RECENT) }
    var showSortMenu by remember { mutableStateOf(false) }

    fun refreshDocuments() {
        recentDocs = progressTracker.allRecentDocuments()
    }

    val filePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                val copiedFile = copyUriToInternalStorage(context, uri)
                if (copiedFile != null) {
                    appState.openDocument(copiedFile)
                    refreshDocuments()
                    onOpenReader()
                }
            }
        }
    }

    // Filter documents
    val filteredDocs = remember(recentDocs, selectedShelfId, selectedFormatFilter, currentSortOption, favoriteUris, finishedUris, customShelves) {
        var list = recentDocs.filter { doc ->
            // Shelf filter
            when (selectedShelfId) {
                "all" -> true
                "reading" -> doc.currentPage > 0 && doc.currentPage < (doc.totalPages - 1).coerceAtLeast(1)
                "favorites" -> favoriteUris.contains(doc.documentUri)
                "finished" -> finishedUris.contains(doc.documentUri)
                else -> {
                    val shelf = customShelves.find { it.id == selectedShelfId }
                    shelf?.documentUris?.contains(doc.documentUri) == true
                }
            }
        }

        // Format filter
        if (selectedFormatFilter != null) {
            list = list.filter { doc ->
                DocumentFormat.detect(File(doc.documentUri)) == selectedFormatFilter
            }
        }

        // Sorting
        when (currentSortOption) {
            LibrarySortOption.RECENT -> list.sortedByDescending { it.lastReadTimestamp }
            LibrarySortOption.TITLE -> list.sortedBy { it.title.lowercase() }
            LibrarySortOption.PROGRESS -> list.sortedByDescending {
                if (it.totalPages > 0) (it.currentPage + 1).toFloat() / it.totalPages else 0f
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
                            color = WarmAmber,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = "Apple Books Reading Experience",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                },
                actions = {
                    Box {
                        IconButton(onClick = { showSortMenu = true }) {
                            Icon(
                                imageVector = Icons.Default.Sort,
                                contentDescription = "Sort Books",
                                tint = Color.White
                            )
                        }
                        DropdownMenu(
                            expanded = showSortMenu,
                            onDismissRequest = { showSortMenu = false }
                        ) {
                            LibrarySortOption.values().forEach { option ->
                                DropdownMenuItem(
                                    text = { Text(option.displayName) },
                                    leadingIcon = {
                                        if (currentSortOption == option) {
                                            Icon(Icons.Default.Check, contentDescription = null, tint = WarmAmber)
                                        }
                                    },
                                    onClick = {
                                        currentSortOption = option
                                        showSortMenu = false
                                    }
                                )
                            }
                        }
                    }
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
                Text(text = "Import Book", fontWeight = FontWeight.Medium)
            }
        },
        containerColor = DeepNavy
    ) { paddingValues ->
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Web Article Quick Import Button
            PaddingValues(horizontal = 16.dp, vertical = 8.dp).let {
                Column(modifier = Modifier.padding(it)) {
                    OutlinedButton(
                        onClick = { showWebImportDialog = true },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = VibrantTeal),
                        border = ButtonDefaults.outlinedButtonBorder.copy(
                            brush = androidx.compose.ui.graphics.SolidColor(VibrantTeal)
                        ),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(imageVector = Icons.Default.Language, contentDescription = "Import Web Article")
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(text = "Import Web Article by URL")
                    }
                }
            }

            // Shelf Selector Pills Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                ShelfPill(
                    title = "All Books",
                    count = recentDocs.size,
                    isSelected = selectedShelfId == "all",
                    onClick = { selectedShelfId = "all" }
                )
                val readingCount = recentDocs.count { it.currentPage > 0 && it.currentPage < (it.totalPages - 1).coerceAtLeast(1) }
                ShelfPill(
                    title = "Reading",
                    count = readingCount,
                    isSelected = selectedShelfId == "reading",
                    onClick = { selectedShelfId = "reading" }
                )
                ShelfPill(
                    title = "Favorites",
                    count = favoriteUris.size,
                    isSelected = selectedShelfId == "favorites",
                    onClick = { selectedShelfId = "favorites" }
                )
                ShelfPill(
                    title = "Finished",
                    count = finishedUris.size,
                    isSelected = selectedShelfId == "finished",
                    onClick = { selectedShelfId = "finished" }
                )

                // Custom Shelves
                customShelves.forEach { shelf ->
                    ShelfPill(
                        title = shelf.name,
                        count = shelf.documentUris.size,
                        isSelected = selectedShelfId == shelf.id,
                        onClick = { selectedShelfId = shelf.id }
                    )
                }

                // Add Shelf Button
                AssistChip(
                    onClick = { showCreateShelfDialog = true },
                    label = { Text("+ New Shelf", fontSize = 12.sp) },
                    colors = AssistChipDefaults.assistChipColors(
                        containerColor = SurfaceElevated,
                        labelColor = VibrantTeal
                    ),
                    border = null,
                    shape = RoundedCornerShape(16.dp)
                )
            }

            // Format Filter Chips
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                FilterChip(
                    selected = selectedFormatFilter == null,
                    onClick = { selectedFormatFilter = null },
                    label = { Text("All Formats", fontSize = 11.sp) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = VibrantTeal.copy(alpha = 0.25f),
                        selectedLabelColor = VibrantTeal,
                        containerColor = SurfaceElevated,
                        labelColor = Color.White.copy(alpha = 0.7f)
                    ),
                    border = null,
                    shape = RoundedCornerShape(12.dp)
                )

                listOf(
                    DocumentFormat.EPUB to "EPUB",
                    DocumentFormat.PDF to "PDF",
                    DocumentFormat.PLAINTEXT to "Articles / Text"
                ).forEach { (fmt, label) ->
                    FilterChip(
                        selected = selectedFormatFilter == fmt,
                        onClick = { selectedFormatFilter = if (selectedFormatFilter == fmt) null else fmt },
                        label = { Text(label, fontSize = 11.sp) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = VibrantTeal.copy(alpha = 0.25f),
                            selectedLabelColor = VibrantTeal,
                            containerColor = SurfaceElevated,
                            labelColor = Color.White.copy(alpha = 0.7f)
                        ),
                        border = null,
                        shape = RoundedCornerShape(12.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Document Count Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = when (selectedShelfId) {
                        "all" -> "All Books"
                        "reading" -> "Reading Now"
                        "favorites" -> "Favorite Books"
                        "finished" -> "Finished Books"
                        else -> customShelves.find { it.id == selectedShelfId }?.name ?: "Custom Shelf"
                    },
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )

                Text(
                    text = "${filteredDocs.size} item${if (filteredDocs.size == 1) "" else "s"}",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.5f)
                )
            }

            // Documents List
            if (filteredDocs.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = Icons.Default.Book,
                            contentDescription = null,
                            tint = Color.White.copy(alpha = 0.2f),
                            modifier = Modifier.size(64.dp)
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            text = if (recentDocs.isEmpty())
                                "No documents imported yet.\nTap 'Import Book' to read EPUBs, PDFs, or text."
                            else
                                "No books in this shelf or filter.",
                            color = Color.White.copy(alpha = 0.5f),
                            fontSize = 14.sp,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(filteredDocs, key = { it.documentUri }) { record ->
                        val isFav = favoriteUris.contains(record.documentUri)
                        val isFin = finishedUris.contains(record.documentUri)
                        val isPrep = prepService.isPrepared(record.documentUri)
                        val isPreparing = prepService.isPreparing(record.documentUri)
                        val prepRecord = prepService.record(record.documentUri)

                        DocumentCard(
                            record = record,
                            isFavorite = isFav,
                            isFinished = isFin,
                            isPrepared = isPrep,
                            isPreparing = isPreparing,
                            prepRecord = prepRecord,
                            onClick = {
                                val file = File(record.documentUri)
                                if (file.exists()) {
                                    scope.launch {
                                        appState.openDocument(file)
                                        onOpenReader()
                                    }
                                }
                            },
                            onToggleFavorite = {
                                collectionManager.toggleFavorite(record.documentUri)
                            },
                            onToggleFinished = {
                                collectionManager.toggleFinished(record.documentUri)
                            },
                            onPrepareBook = {
                                scope.launch {
                                    val file = File(record.documentUri)
                                    prepService.prepareBook(record.documentUri, if (file.exists()) file else null)
                                }
                            },
                            onManageShelves = {
                                documentForShelfSheet = record
                            },
                            onDelete = {
                                documentToDelete = record
                            }
                        )
                    }
                }
            }
        }
    }

    // Delete Confirmation Dialog
    documentToDelete?.let { doc ->
        AlertDialog(
            onDismissRequest = { documentToDelete = null },
            icon = {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = null,
                    tint = CoralRed,
                    modifier = Modifier.size(32.dp)
                )
            },
            title = { Text(text = "Delete Book?", fontWeight = FontWeight.Bold) },
            text = {
                Text(
                    text = "Are you sure you want to delete \"${doc.title}\"? This will permanently remove the file from internal storage, reset reading progress, and remove it from all shelves."
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        collectionManager.deleteDocument(doc.documentUri)
                        refreshDocuments()
                        documentToDelete = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = CoralRed)
                ) {
                    Text("Delete Permanently", color = Color.White)
                }
            },
            dismissButton = {
                TextButton(onClick = { documentToDelete = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Create Shelf Dialog
    if (showCreateShelfDialog) {
        var shelfName by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showCreateShelfDialog = false },
            title = { Text("New Shelf") },
            text = {
                Column {
                    Text("Enter a name for your new collection shelf:")
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = shelfName,
                        onValueChange = { shelfName = it },
                        placeholder = { Text("e.g., Sci-Fi, Work, Studies") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (shelfName.isNotBlank()) {
                            collectionManager.createShelf(shelfName)
                            showCreateShelfDialog = false
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = WarmAmber, contentColor = Color.Black)
                ) {
                    Text("Create")
                }
            },
            dismissButton = {
                TextButton(onClick = { showCreateShelfDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Manage Shelves Dialog for a Document
    documentForShelfSheet?.let { doc ->
        AlertDialog(
            onDismissRequest = { documentForShelfSheet = null },
            title = {
                Text(
                    text = "Organize \"${doc.title}\"",
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                if (customShelves.isEmpty()) {
                    Text("No custom shelves created yet. Create a shelf from the main library toolbar first.")
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Add or remove from shelves:", fontSize = 13.sp, color = Color.Gray)
                        customShelves.forEach { shelf ->
                            val isInShelf = shelf.documentUris.contains(doc.documentUri)
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(8.dp))
                                    .clickable {
                                        if (isInShelf) {
                                            collectionManager.removeDocumentFromShelf(doc.documentUri, shelf.id)
                                        } else {
                                            collectionManager.addDocumentToShelf(doc.documentUri, shelf.id)
                                        }
                                    }
                                    .padding(vertical = 8.dp, horizontal = 4.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(shelf.name, fontSize = 15.sp)
                                Checkbox(
                                    checked = isInShelf,
                                    onCheckedChange = { checked ->
                                        if (checked) {
                                            collectionManager.addDocumentToShelf(doc.documentUri, shelf.id)
                                        } else {
                                            collectionManager.removeDocumentFromShelf(doc.documentUri, shelf.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { documentForShelfSheet = null }) {
                    Text("Done")
                }
            }
        )
    }

    // Web Article Import Dialog
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
                        refreshDocuments()
                        onOpenReader()
                    } catch (_: Exception) {}
                }
            }
        )
    }
}

@Composable
private fun ShelfPill(
    title: String,
    count: Int,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        color = if (isSelected) WarmAmber else SurfaceElevated,
        contentColor = if (isSelected) Color.Black else Color.White
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = title,
                fontSize = 12.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
            )
            Surface(
                shape = CircleShape,
                color = if (isSelected) Color.Black.copy(alpha = 0.15f) else Color.White.copy(alpha = 0.12f)
            ) {
                Text(
                    text = count.toString(),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                )
            }
        }
    }
}

@Composable
private fun DocumentCard(
    record: ReadingProgress,
    isFavorite: Boolean,
    isFinished: Boolean,
    isPrepared: Boolean,
    isPreparing: Boolean,
    prepRecord: com.vachanam.reader.data.persistence.BookPreparationRecord?,
    onClick: () -> Unit,
    onToggleFavorite: () -> Unit,
    onToggleFinished: () -> Unit,
    onPrepareBook: () -> Unit,
    onManageShelves: () -> Unit,
    onDelete: () -> Unit
) {
    val progress = if (record.totalPages > 0) (record.currentPage + 1).toFloat() / record.totalPages else 0f
    val format = DocumentFormat.detect(File(record.documentUri))
    var showMenu by remember { mutableStateOf(false) }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick),
        color = SlateCharcoal,
        tonalElevation = 4.dp
    ) {
        Column(
            modifier = Modifier.padding(14.dp)
        ) {
            // Header Row: Title + Format Badge + Menu
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = record.title,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false)
                    )

                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = SurfaceElevated
                    ) {
                        Text(
                            text = format.displayName,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = VibrantTeal,
                            modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                        )
                    }
                }

                // 3-dots Menu Button
                Box {
                    IconButton(
                        onClick = { showMenu = true },
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.MoreVert,
                            contentDescription = "Book Actions",
                            tint = Color.White.copy(alpha = 0.7f),
                            modifier = Modifier.size(18.dp)
                        )
                    }

                    DropdownMenu(
                        expanded = showMenu,
                        onDismissRequest = { showMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text(if (isFavorite) "Remove from Favorites" else "Add to Favorites") },
                            leadingIcon = {
                                Icon(
                                    imageVector = if (isFavorite) Icons.Default.Star else Icons.Outlined.StarBorder,
                                    contentDescription = null,
                                    tint = if (isFavorite) WarmAmber else Color.Gray
                                )
                            },
                            onClick = {
                                onToggleFavorite()
                                showMenu = false
                            }
                        )
                        DropdownMenuItem(
                            text = { Text(if (isFinished) "Mark as Unread" else "Mark as Finished") },
                            leadingIcon = {
                                Icon(
                                    imageVector = if (isFinished) Icons.Default.CheckCircle else Icons.Outlined.CheckCircle,
                                    contentDescription = null,
                                    tint = if (isFinished) VibrantTeal else Color.Gray
                                )
                            },
                            onClick = {
                                onToggleFinished()
                                showMenu = false
                            }
                        )
                        if (!isPrepared) {
                            DropdownMenuItem(
                                text = { Text("Prepare Book for Voice") },
                                leadingIcon = {
                                    Icon(
                                        imageVector = Icons.Default.Bolt,
                                        contentDescription = null,
                                        tint = WarmAmber
                                    )
                                },
                                onClick = {
                                    onPrepareBook()
                                    showMenu = false
                                }
                            )
                        }
                        DropdownMenuItem(
                            text = { Text("Organize into Shelves...") },
                            leadingIcon = {
                                Icon(
                                    imageVector = Icons.Default.Folder,
                                    contentDescription = null,
                                    tint = Color.Gray
                                )
                            },
                            onClick = {
                                onManageShelves()
                                showMenu = false
                            }
                        )
                        Divider()
                        DropdownMenuItem(
                            text = { Text("Delete Book", color = CoralRed) },
                            leadingIcon = {
                                Icon(
                                    imageVector = Icons.Default.Delete,
                                    contentDescription = null,
                                    tint = CoralRed
                                )
                            },
                            onClick = {
                                onDelete()
                                showMenu = false
                            }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Progress Bar
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = WarmAmber,
                trackColor = SurfaceElevated
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Footer Row: Page stats & Status Badges
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Page ${record.currentPage + 1} of ${record.totalPages} (${(progress * 100).toInt()}%)",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.6f)
                )

                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (isFavorite) {
                        Icon(
                            imageVector = Icons.Default.Star,
                            contentDescription = "Favorite",
                            tint = WarmAmber,
                            modifier = Modifier.size(14.dp)
                        )
                    }

                    if (isFinished) {
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = VibrantTeal.copy(alpha = 0.2f)
                        ) {
                            Text(
                                text = "Finished",
                                fontSize = 10.sp,
                                color = VibrantTeal,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                            )
                        }
                    }

                    if (isPreparing) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(12.dp),
                            strokeWidth = 2.dp,
                            color = WarmAmber
                        )
                        Text(
                            text = "Preparing...",
                            fontSize = 10.sp,
                            color = WarmAmber
                        )
                    } else if (isPrepared && prepRecord != null) {
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = WarmAmber.copy(alpha = 0.2f)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(3.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.VolumeUp,
                                    contentDescription = null,
                                    tint = WarmAmber,
                                    modifier = Modifier.size(11.dp)
                                )
                                Text(
                                    text = "${prepRecord.estimatedAudioMinutes}m audio",
                                    fontSize = 10.sp,
                                    color = WarmAmber,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }
            }
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
                enabled = urlText.startsWith("http://") || urlText.startsWith("https://"),
                colors = ButtonDefaults.buttonColors(containerColor = WarmAmber, contentColor = Color.Black)
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
