package com.vachanam.reader.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.accessibility.AccessibilityManager
import com.vachanam.reader.accessibility.FontManager
import com.vachanam.reader.accessibility.ThemeManager
import com.vachanam.reader.tts.PronunciationManager
import com.vachanam.reader.ui.theme.*

import com.vachanam.reader.tts.TTSController

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    themeManager: ThemeManager,
    fontManager: FontManager,
    accessibilityManager: AccessibilityManager,
    pronunciationManager: PronunciationManager,
    ttsController: TTSController? = null,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val currentTheme by themeManager.currentReaderTheme.collectAsState()
    val currentLayout by themeManager.currentReadingLayout.collectAsState()
    val selectedFont by fontManager.selectedFont.collectAsState()
    val fontSize by fontManager.fontSize.collectAsState()
    val lineSpacing by fontManager.lineSpacingMultiplier.collectAsState()
    val isBold by fontManager.isBoldTextEnabled.collectAsState()

    val isBionic by accessibilityManager.isBionicReadingEnabled.collectAsState()
    val isRuler by accessibilityManager.isReadingRulerEnabled.collectAsState()
    val rulerHeight by accessibilityManager.rulerHeight.collectAsState()
    val isHighContrast by accessibilityManager.isHighContrastEnabled.collectAsState()
    val selectedModelId by (ttsController?.selectedModelId ?: remember { kotlinx.coroutines.flow.MutableStateFlow("android_system") }).collectAsState()
    val selectedVoice by (ttsController?.selectedVoice ?: remember { kotlinx.coroutines.flow.MutableStateFlow<String?>("default") }).collectAsState()

    val pronunciations by pronunciationManager.overrides.collectAsState()
    var showAddPronunciationDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Reading & Accessibility Settings", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DeepNavy)
            )
        },
        containerColor = DeepNavy
    ) { paddingValues ->
        LazyColumn(
            modifier = modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // 1. Reading Themes
            item {
                Text(text = "Reading Theme", fontSize = 18.sp, color = WarmAmber)
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    for (theme in ReaderBackgroundTheme.entries) {
                        val isSelected = currentTheme == theme
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.clickable { themeManager.setTheme(theme) }
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(44.dp)
                                    .clip(CircleShape)
                                    .background(theme.backgroundColor)
                                    .border(
                                        width = if (isSelected) 3.dp else 1.dp,
                                        color = if (isSelected) WarmAmber else Color.Gray,
                                        shape = CircleShape
                                    )
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = theme.displayName.split(" ").first(),
                                fontSize = 11.sp,
                                color = Color.White.copy(alpha = 0.8f)
                            )
                        }
                    }
                }
            }

            // 2. Reading Layout
            item {
                Text(text = "Reading Layout", fontSize = 18.sp, color = WarmAmber)
                Spacer(modifier = Modifier.height(10.dp))
                for (layout in ReadingLayout.entries) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { themeManager.setLayout(layout) }
                            .padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = currentLayout == layout,
                            onClick = { themeManager.setLayout(layout) },
                            colors = RadioButtonDefaults.colors(selectedColor = WarmAmber)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = layout.displayName,
                            fontSize = 14.sp,
                            color = Color.White
                        )
                    }
                }
            }

            // 3. Typography & Fonts
            item {
                Text(text = "Typography", fontSize = 18.sp, color = WarmAmber)
                Spacer(modifier = Modifier.height(10.dp))

                Text(text = "Font Family", fontSize = 14.sp, color = Color.White.copy(alpha = 0.8f))
                Spacer(modifier = Modifier.height(6.dp))
                for (font in ReaderFontFamily.entries) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { fontManager.setFontFamily(font) }
                            .padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = selectedFont == font,
                            onClick = { fontManager.setFontFamily(font) },
                            colors = RadioButtonDefaults.colors(selectedColor = WarmAmber)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = font.displayName,
                            color = Color.White,
                            fontFamily = font.toFontFamily(),
                            fontSize = 16.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))
                Text(text = "Font Size: ${fontSize.toInt()} sp", fontSize = 14.sp, color = Color.White.copy(alpha = 0.8f))
                Slider(
                    value = fontSize,
                    onValueChange = { fontManager.setFontSize(it) },
                    valueRange = 14f..32f,
                    colors = SliderDefaults.colors(thumbColor = WarmAmber, activeTrackColor = WarmAmber)
                )

                Text(text = "Line Spacing: ${"%.1f".format(lineSpacing)}x", fontSize = 14.sp, color = Color.White.copy(alpha = 0.8f))
                Slider(
                    value = lineSpacing,
                    onValueChange = { fontManager.setLineSpacing(it) },
                    valueRange = 1.2f..2.2f,
                    colors = SliderDefaults.colors(thumbColor = WarmAmber, activeTrackColor = WarmAmber)
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "Bold Text", fontSize = 15.sp, color = Color.White)
                    Switch(
                        checked = isBold,
                        onCheckedChange = { fontManager.setBoldText(it) },
                        colors = SwitchDefaults.colors(checkedThumbColor = WarmAmber)
                    )
                }
            }

            // 3. Accessibility Tools
            item {
                Text(text = "Accessibility Suite", fontSize = 18.sp, color = WarmAmber)
                Spacer(modifier = Modifier.height(10.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = "Bionic Reading", fontSize = 15.sp, color = Color.White)
                        Text(
                            text = "Bolds initial characters of words to guide eye fixation",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.6f)
                        )
                    }
                    Switch(
                        checked = isBionic,
                        onCheckedChange = { accessibilityManager.setBionicReading(it) },
                        colors = SwitchDefaults.colors(checkedThumbColor = WarmAmber)
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = "Dyslexia Reading Ruler", fontSize = 15.sp, color = Color.White)
                        Text(
                            text = "Horizontal draggable window focusing on active line",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.6f)
                        )
                    }
                    Switch(
                        checked = isRuler,
                        onCheckedChange = { accessibilityManager.setReadingRuler(it) },
                        colors = SwitchDefaults.colors(checkedThumbColor = WarmAmber)
                    )
                }

                if (isRuler) {
                    Text(text = "Ruler Height: ${rulerHeight.toInt()} dp", fontSize = 13.sp, color = Color.White.copy(alpha = 0.8f))
                    Slider(
                        value = rulerHeight,
                        onValueChange = { accessibilityManager.setRulerHeight(it) },
                        valueRange = 32f..80f,
                        colors = SliderDefaults.colors(thumbColor = VibrantTeal, activeTrackColor = VibrantTeal)
                    )
                }
            }

            // 4. Speech Engine & Voice Profiles
            if (ttsController != null) {
                item {
                    Text(text = "Speech Engine & Voice Profiles", fontSize = 18.sp, color = WarmAmber)
                    Spacer(modifier = Modifier.height(10.dp))

                    Text(text = "TTS Engine", fontSize = 14.sp, color = Color.White.copy(alpha = 0.8f))
                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { ttsController.selectModel("android_system") }
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = selectedModelId == "android_system",
                            onClick = { ttsController.selectModel("android_system") },
                            colors = RadioButtonDefaults.colors(selectedColor = WarmAmber)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(text = "Android System TTS (Built-in)", color = Color.White, fontSize = 15.sp)
                            Text(text = "Offline native voice synthesis with word karaoke", color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
                        }
                    }

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { ttsController.selectModel("kokoro_82m") }
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = selectedModelId == "kokoro_82m",
                            onClick = { ttsController.selectModel("kokoro_82m") },
                            colors = RadioButtonDefaults.colors(selectedColor = WarmAmber)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(text = "Kokoro 82M Neural Model", color = Color.White, fontSize = 15.sp)
                            Text(text = "Frontier expressive neural TTS with human-like prosody (~86 MB)", color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = if (selectedModelId == "kokoro_82m") "Kokoro Voice Profiles" else "System Voice Profiles",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                    Spacer(modifier = Modifier.height(6.dp))

                    val voiceList = if (selectedModelId == "kokoro_82m") {
                        listOf(
                            "af_heart" to "Heart (Female, American)",
                            "af_bella" to "Bella (Female, American)",
                            "am_adam" to "Adam (Male, American)",
                            "am_michael" to "Michael (Male, American)",
                            "bf_emma" to "Emma (Female, British)",
                            "bm_george" to "George (Male, British)"
                        )
                    } else {
                        val available = ttsController.systemAdapter.getAvailableVoices()
                        if (available.isEmpty()) {
                            listOf("default" to "System Default Voice")
                        } else {
                            available.map { v ->
                                val label = if (v == "default") "System Default Voice" else v.replace("en-us-", "").replace("en-", "").replace("-", " ")
                                v to label
                            }
                        }
                    }

                    for ((vId, vLabel) in voiceList) {
                        val isChosen = selectedVoice == vId || (selectedVoice == null && vId == voiceList.first().first)
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { ttsController.selectVoice(vId) }
                                .padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                                RadioButton(
                                    selected = isChosen,
                                    onClick = { ttsController.selectVoice(vId) },
                                    colors = RadioButtonDefaults.colors(selectedColor = VibrantTeal)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(text = vLabel, color = Color.White, fontSize = 14.sp)
                            }
                            IconButton(
                                onClick = { ttsController.previewVoice(vId) },
                                modifier = Modifier.size(32.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.VolumeUp,
                                    contentDescription = "Preview voice",
                                    tint = WarmAmber,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    }
                }
            }

            // 5. Custom Pronunciation Dictionary
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(text = "Pronunciation Dictionary", fontSize = 18.sp, color = WarmAmber)
                    IconButton(onClick = { showAddPronunciationDialog = true }) {
                        Icon(imageVector = Icons.Default.Add, contentDescription = "Add Override", tint = VibrantTeal)
                    }
                }

                if (pronunciations.isEmpty()) {
                    Text(
                        text = "No pronunciation overrides configured.",
                        fontSize = 13.sp,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                } else {
                    for ((_, override) in pronunciations) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "${override.originalWord} → ${override.spokenReplacement}",
                                fontSize = 14.sp,
                                color = Color.White
                            )
                            IconButton(onClick = { pronunciationManager.removeOverride(override.originalWord) }) {
                                Icon(imageVector = Icons.Default.Delete, contentDescription = "Delete", tint = Color.Red.copy(alpha = 0.7f))
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }

    if (showAddPronunciationDialog) {
        var word by remember { mutableStateOf("") }
        var spoken by remember { mutableStateOf("") }

        AlertDialog(
            onDismissRequest = { showAddPronunciationDialog = false },
            title = { Text("Add Pronunciation Override") },
            text = {
                Column {
                    TextField(
                        value = word,
                        onValueChange = { word = it },
                        label = { Text("Original Word") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    TextField(
                        value = spoken,
                        onValueChange = { spoken = it },
                        label = { Text("Spoken Replacement") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (word.isNotBlank() && spoken.isNotBlank()) {
                            pronunciationManager.setOverride(word.trim(), spoken.trim())
                            showAddPronunciationDialog = false
                        }
                    }
                ) {
                    Text("Save")
                }
            },
            dismissButton = {
                TextButton(onClick = { showAddPronunciationDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
