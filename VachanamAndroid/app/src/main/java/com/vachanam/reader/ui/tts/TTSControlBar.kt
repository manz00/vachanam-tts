package com.vachanam.reader.ui.tts

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.app.AppState
import com.vachanam.reader.ui.theme.SlateCharcoal
import com.vachanam.reader.ui.theme.VibrantTeal
import com.vachanam.reader.ui.theme.WarmAmber

@Composable
fun TTSControlBar(
    appState: AppState,
    onOpenSoundscapes: () -> Unit,
    modifier: Modifier = Modifier
) {
    val ttsController = appState.ttsController
    val coordinator = appState.coordinator

    val isPlaying by coordinator.isPlaying.collectAsState()
    val speechRate by ttsController.speechRate.collectAsState()
    val selectedModelId by ttsController.selectedModelId.collectAsState()
    var showVoicePicker by remember { mutableStateOf(false) }

    if (showVoicePicker) {
        VoicePickerBottomSheet(
            ttsController = ttsController,
            onDismiss = { showVoicePicker = false }
        )
    }

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(32.dp)),
        color = SlateCharcoal.copy(alpha = 0.95f),
        tonalElevation = 10.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            // Voice & Model Picker button
            IconButton(onClick = { showVoicePicker = true }) {
                Icon(
                    imageVector = Icons.Default.RecordVoiceOver,
                    contentDescription = "Voice Profiles & Engine",
                    tint = if (selectedModelId == "kokoro_82m") VibrantTeal else WarmAmber
                )
            }

            // Ambient Soundscapes button
            IconButton(onClick = onOpenSoundscapes) {
                Icon(
                    imageVector = Icons.Default.GraphicEq,
                    contentDescription = "Focus Soundscapes",
                    tint = VibrantTeal
                )
            }

            // Skip Back Sentence
            IconButton(onClick = { ttsController.skipBackwardSentence() }) {
                Icon(
                    imageVector = Icons.Default.Replay10,
                    contentDescription = "Previous Sentence",
                    tint = Color.White
                )
            }

            // Play / Pause Floating Action Button
            FilledIconButton(
                onClick = {
                    if (isPlaying) ttsController.pause() else ttsController.play()
                },
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = WarmAmber,
                    contentColor = Color.Black
                ),
                modifier = Modifier.size(52.dp)
            ) {
                Icon(
                    imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                    contentDescription = if (isPlaying) "Pause" else "Play",
                    modifier = Modifier.size(32.dp)
                )
            }

            // Skip Forward Sentence
            IconButton(onClick = { ttsController.skipForwardSentence() }) {
                Icon(
                    imageVector = Icons.Default.Forward10,
                    contentDescription = "Next Sentence",
                    tint = Color.White
                )
            }

            // Speech Rate Toggle (1.0x -> 1.25x -> 1.5x -> 1.75x -> 2.0x -> 1.0x)
            TextButton(
                onClick = {
                    val nextRate = when {
                        speechRate < 1.2f -> 1.25f
                        speechRate < 1.4f -> 1.5f
                        speechRate < 1.7f -> 1.75f
                        speechRate < 1.9f -> 2.0f
                        else -> 1.0f
                    }
                    ttsController.setSpeechRate(nextRate)
                }
            ) {
                Text(
                    text = "${speechRate}x",
                    fontSize = 14.sp,
                    color = WarmAmber
                )
            }
        }
    }
}
