package com.vachanam.reader

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.lifecycleScope
import com.vachanam.reader.accessibility.AccessibilityManager
import com.vachanam.reader.accessibility.FontManager
import com.vachanam.reader.accessibility.ThemeManager
import com.vachanam.reader.app.AppState
import com.vachanam.reader.pdf.BookmarkManager
import com.vachanam.reader.tts.PronunciationManager
import com.vachanam.reader.ui.library.DocumentLibraryScreen
import com.vachanam.reader.ui.reader.ReaderContainerView
import com.vachanam.reader.ui.settings.SettingsScreen
import com.vachanam.reader.ui.theme.DeepNavy
import com.vachanam.reader.ui.theme.VachanamTheme
import com.vachanam.reader.ui.tts.SoundscapePickerSheet
import com.vachanam.reader.util.FileUtils
import kotlinx.coroutines.launch
import androidx.activity.result.contract.ActivityResultContracts
import com.vachanam.reader.util.PermissionHelper
import java.io.File
import java.io.FileOutputStream

class MainActivity : ComponentActivity() {

    private lateinit var appState: AppState
    private lateinit var themeManager: ThemeManager
    private lateinit var fontManager: FontManager
    private lateinit var accessibilityManager: AccessibilityManager
    private lateinit var bookmarkManager: BookmarkManager
    private lateinit var pronunciationManager: PronunciationManager

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ ->
        // Runtime permissions evaluated
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appState = AppState.getInstance(this)
        themeManager = ThemeManager.getInstance(this)
        fontManager = FontManager.getInstance(this)
        accessibilityManager = AccessibilityManager.getInstance(this)
        bookmarkManager = BookmarkManager.getInstance(this)
        pronunciationManager = PronunciationManager.getInstance(this)

        val missingPermissions = PermissionHelper.getMissingPermissions(this)
        if (missingPermissions.isNotEmpty()) {
            permissionLauncher.launch(missingPermissions)
        }

        handleIntent(intent)

        setContent {
            VachanamTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = DeepNavy
                ) {
                    var currentScreen by remember { mutableStateOf("library") }
                    var showSoundscapesSheet by remember { mutableStateOf(false) }

                    val activeDoc by appState.currentDocument.collectAsState()

                    LaunchedEffect(activeDoc) {
                        if (activeDoc != null) {
                            currentScreen = "reader"
                        }
                    }

                    when (currentScreen) {
                        "library" -> {
                            DocumentLibraryScreen(
                                appState = appState,
                                onOpenReader = { currentScreen = "reader" },
                                onOpenSettings = { currentScreen = "settings" }
                            )
                        }
                        "reader" -> {
                            ReaderContainerView(
                                appState = appState,
                                themeManager = themeManager,
                                fontManager = fontManager,
                                accessibilityManager = accessibilityManager,
                                bookmarkManager = bookmarkManager,
                                onBack = {
                                    appState.closeCurrentDocument()
                                    currentScreen = "library"
                                },
                                onOpenSoundscapes = { showSoundscapesSheet = true }
                            )
                        }
                        "settings" -> {
                            SettingsScreen(
                                themeManager = themeManager,
                                fontManager = fontManager,
                                accessibilityManager = accessibilityManager,
                                pronunciationManager = pronunciationManager,
                                ttsController = appState.ttsController,
                                onBack = { currentScreen = if (activeDoc != null) "reader" else "library" }
                            )
                        }
                    }

                    if (showSoundscapesSheet) {
                        SoundscapePickerSheet(
                            soundscapePlayer = appState.soundscapePlayer,
                            onDismiss = { showSoundscapesSheet = false }
                        )
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            intent.data?.let { uri ->
                lifecycleScope.launch {
                    try {
                        val destFile = FileUtils.copyUriToInternalStorage(this@MainActivity, uri)
                        if (destFile != null) {
                            appState.openDocument(destFile)
                        }
                    } catch (_: Exception) {}
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        appState.ttsController.stop()
    }
}
