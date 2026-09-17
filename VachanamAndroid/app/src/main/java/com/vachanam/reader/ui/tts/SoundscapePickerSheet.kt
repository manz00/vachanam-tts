package com.vachanam.reader.ui.tts

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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vachanam.reader.audio.AmbientSoundscapePlayer
import com.vachanam.reader.audio.SoundscapePreset
import com.vachanam.reader.ui.theme.SlateCharcoal
import com.vachanam.reader.ui.theme.SurfaceElevated
import com.vachanam.reader.ui.theme.VibrantTeal
import com.vachanam.reader.ui.theme.WarmAmber

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SoundscapePickerSheet(
    soundscapePlayer: AmbientSoundscapePlayer,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val currentPreset by soundscapePlayer.currentPreset.collectAsState()
    val volume by soundscapePlayer.volume.collectAsState()
    val isPlaying by soundscapePlayer.isPlaying.collectAsState()
    val isStudyMode by soundscapePlayer.isStudyModeEnabled.collectAsState()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = SlateCharcoal,
        modifier = modifier
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Ambient Focus Soundscapes",
                    fontSize = 20.sp,
                    color = Color.White
                )
                if (currentPreset != null) {
                    TextButton(onClick = { soundscapePlayer.selectPreset(null) }) {
                        Text(text = "Turn Off", color = Color.Red.copy(alpha = 0.8f))
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Presets List
            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(SoundscapePreset.entries) { preset ->
                    val isSelected = currentPreset == preset

                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .clickable {
                                if (isSelected) {
                                    if (isPlaying) soundscapePlayer.pauseAmbient() else soundscapePlayer.startAmbient()
                                } else {
                                    soundscapePlayer.selectPreset(preset)
                                }
                            },
                        color = if (isSelected) SurfaceElevated else Color.Transparent,
                        tonalElevation = if (isSelected) 4.dp else 0.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            val icon: ImageVector = when (preset) {
                                SoundscapePreset.BROWN_NOISE -> Icons.Default.GraphicEq
                                SoundscapePreset.PINK_NOISE -> Icons.Default.Waveform
                                SoundscapePreset.BINAURAL_FOCUS -> Icons.Default.Psychology
                                SoundscapePreset.SOFT_RAIN -> Icons.Default.WaterDrop
                                SoundscapePreset.LIBRARY_AMBIENCE -> Icons.Default.LocalLibrary
                            }

                            Icon(
                                imageVector = icon,
                                contentDescription = preset.title,
                                tint = if (isSelected) VibrantTeal else Color.Gray,
                                modifier = Modifier.size(32.dp)
                            )

                            Spacer(modifier = Modifier.width(16.dp))

                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = preset.title,
                                    fontSize = 16.sp,
                                    color = if (isSelected) WarmAmber else Color.White
                                )
                                Text(
                                    text = preset.subtitle,
                                    fontSize = 12.sp,
                                    color = Color.White.copy(alpha = 0.6f)
                                )
                            }

                            if (isSelected) {
                                Icon(
                                    imageVector = if (isPlaying) Icons.Default.VolumeUp else Icons.Default.VolumeMute,
                                    contentDescription = "Active Status",
                                    tint = VibrantTeal
                                )
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Volume Slider
            if (currentPreset != null) {
                Text(
                    text = "Acoustic Volume: ${(volume * 100).toInt()}%",
                    fontSize = 14.sp,
                    color = Color.White.copy(alpha = 0.8f)
                )
                Slider(
                    value = volume,
                    onValueChange = { soundscapePlayer.setVolume(it) },
                    valueRange = 0.0f..1.0f,
                    colors = SliderDefaults.colors(
                        thumbColor = VibrantTeal,
                        activeTrackColor = VibrantTeal
                    )
                )
            }

            // Study Mode Toggle
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Study Mode",
                        fontSize = 16.sp,
                        color = Color.White
                    )
                    Text(
                        text = "Keep soundscape playing when reading without speech",
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = 0.6f)
                    )
                }
                Switch(
                    checked = isStudyMode,
                    onCheckedChange = { soundscapePlayer.setStudyMode(it) },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = WarmAmber,
                        checkedTrackColor = SurfaceElevated
                    )
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}
